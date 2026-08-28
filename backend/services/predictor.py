import json
import logging
from pathlib import Path

import joblib
import pandas as pd

from backend.schemas import PredictRequest, PredictResponse

logger = logging.getLogger("risk-api")

ML_MODEL_DIR = Path(__file__).parent.parent.parent / "ml" / "model"

RISK_LABELS = {
    "No_Accident": "SAFE",
    "Minor": "MINOR RISK",
    "Major": "HIGH RISK",
}

LIVE_TO_COLUMN = {
    "speed_kmh": "speed_kmh",
    "seatbelt_worn": "seatbelt_worn",
    "weather_condition": "weather_condition",
    "road_surface": "road_surface",
    "light_condition": "light_condition",
    "time_of_day": "time_of_day",
}


class ValidationError(Exception):
    pass


class Predictor:
    def __init__(self):
        self.pipeline = None
        self.categories: dict[str, list[str]] = {}
        self.numeric_ranges: dict[str, dict[str, float]] = {}
        self.fixed_context: dict = {}

    def load(self):
        pipeline_path = ML_MODEL_DIR / "risk_pipeline.joblib"
        if not pipeline_path.exists():
            raise RuntimeError(
                f"Model file not found at {pipeline_path}. Run `ml/.venv/bin/python ml/train_model.py` first."
            )
        self.pipeline = joblib.load(pipeline_path)
        self.categories = json.loads((ML_MODEL_DIR / "categories.json").read_text())
        self.numeric_ranges = json.loads((ML_MODEL_DIR / "numeric_ranges.json").read_text())
        self.fixed_context = json.loads((ML_MODEL_DIR / "fixed_context.json").read_text())
        logger.info("Model pipeline loaded from %s", pipeline_path)

    def _validate(self, req: PredictRequest):
        for field_name, column_name in LIVE_TO_COLUMN.items():
            value = getattr(req, field_name)
            if column_name in self.categories:
                valid_values = self.categories[column_name]
                if value not in valid_values:
                    raise ValidationError(
                        f"Invalid value '{value}' for '{field_name}'. Must be one of: {valid_values}"
                    )
            elif column_name in self.numeric_ranges:
                rng = self.numeric_ranges[column_name]
                if not (rng["min"] <= value <= rng["max"] * 1.1):
                    raise ValidationError(
                        f"'{field_name}'={value} is outside the sensible range "
                        f"[{rng['min']}, {rng['max']}] the model was trained on."
                    )

    def predict(self, req: PredictRequest) -> PredictResponse:
        if self.pipeline is None:
            raise RuntimeError("Model not loaded")

        self._validate(req)

        row = dict(self.fixed_context)
        for field_name, column_name in LIVE_TO_COLUMN.items():
            row[column_name] = getattr(req, field_name)

        X = pd.DataFrame([row])
        proba = self.pipeline.predict_proba(X)[0]
        classes = list(self.pipeline.classes_)
        probabilities = {cls: round(float(p), 4) for cls, p in zip(classes, proba)}

        predicted_idx = int(proba.argmax())
        predicted_class = classes[predicted_idx]
        predicted_proba = float(proba[predicted_idx])

        return PredictResponse(
            prediction=predicted_class,
            risk_label=RISK_LABELS[predicted_class],
            probability=round(predicted_proba, 4),
            probability_percent=round(predicted_proba * 100),
            probabilities=probabilities,
        )


predictor = Predictor()
