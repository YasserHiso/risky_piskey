import json
import warnings
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import ExtraTreesClassifier, RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    make_scorer,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import StratifiedKFold, cross_validate, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

warnings.filterwarnings("ignore")

ROOT = Path(__file__).parent
RAW_CSV = ROOT / "dataset_bdroadrisk" / "bdroadrisk_sample_500k.csv"
MODEL_DIR = ROOT / "model"
MODEL_DIR.mkdir(exist_ok=True)

RANDOM_STATE = 42
TARGET_COL = "accident_severity"

LIVE_CONTROLS = ["speed_kmh", "seatbelt_worn"]
AUTO_ENVIRONMENT = ["weather_condition", "road_surface", "light_condition", "time_of_day"]
FIXED_CONTEXT = [
    "road_class", "road_quality", "speed_limit_zone", "vehicle_type",
    "vehicle_age_years", "driver_age", "driver_experience_level",
    "alcohol_influence", "month", "latitude", "longitude", "traffic_density",
]
ALL_FEATURES = LIVE_CONTROLS + AUTO_ENVIRONMENT + FIXED_CONTEXT

NUMERIC_FEATURES = [
    "speed_kmh", "speed_limit_zone", "vehicle_age_years", "driver_age",
    "month", "latitude", "longitude", "traffic_density",
]
CATEGORICAL_FEATURES = [c for c in ALL_FEATURES if c not in NUMERIC_FEATURES]

EXCLUDED_FEATURES = {
    "junction_type": "Severity-driven generation (50% of its distribution sampled from the target label) — confirmed leakage.",
    "visibility_km": "Severity-driven generation ('driven by weather condition and severity class') — confirmed leakage.",
    "acceleration_ms2": "Describes the mechanics of a specific incident (braking at that moment), not a pre-existing condition; not settable by a real-time simulator.",
    "reaction_time_sec": "Same as above — only meaningful in hindsight of a specific event.",
    "temperature_celsius": "Dataset's own documentation labels it 'non-predictive... Intentional noise feature'.",
}

FIXED_CONTEXT_DEFAULTS = {
    "road_class": "primary",
    "road_quality": "Good",
    "speed_limit_zone": 80,
    "vehicle_type": "Car",
    "vehicle_age_years": 3,
    "driver_age": 35,
    "driver_experience_level": "Experienced",
    "alcohol_influence": "None",
    "month": 6,
    "latitude": 23.7999,
    "longitude": 90.4149,
    "traffic_density": 55,
}


def load_and_clean() -> pd.DataFrame:
    df = pd.read_csv(RAW_CSV)
    before = len(df)
    df = df.drop_duplicates()
    print(f"Loaded {before:,} rows, {len(df):,} after dropping {before - len(df)} duplicates")

    df["alcohol_influence"] = df["alcohol_influence"].fillna("None")

    print(f"\nExcluded features (see docstring for full reasoning):")
    for col, reason in EXCLUDED_FEATURES.items():
        print(f"  - {col}: {reason}")

    return df


def build_pipeline(model) -> Pipeline:
    preprocessor = ColumnTransformer(
        transformers=[
            (
                "cat",
                Pipeline(
                    steps=[
                        ("impute", SimpleImputer(strategy="constant", fill_value="Unknown")),
                        ("onehot", OneHotEncoder(handle_unknown="ignore")),
                    ]
                ),
                CATEGORICAL_FEATURES,
            ),
            (
                "num",
                Pipeline(
                    steps=[
                        ("impute", SimpleImputer(strategy="median")),
                        ("scale", StandardScaler()),
                    ]
                ),
                NUMERIC_FEATURES,
            ),
        ]
    )
    return Pipeline(steps=[("preprocessor", preprocessor), ("classifier", model)])


def evaluate(pipe: Pipeline, X_test, y_test, classes) -> dict:
    y_pred = pipe.predict(X_test)
    y_proba = pipe.predict_proba(X_test)
    return {
        "accuracy": float(accuracy_score(y_test, y_pred)),
        "precision_macro": float(precision_score(y_test, y_pred, average="macro")),
        "recall_macro": float(recall_score(y_test, y_pred, average="macro")),
        "f1_macro": float(f1_score(y_test, y_pred, average="macro")),
        "roc_auc_ovr_macro": float(
            roc_auc_score(y_test, y_proba, multi_class="ovr", average="macro", labels=classes)
        ),
        "confusion_matrix": confusion_matrix(y_test, y_pred, labels=classes).tolist(),
        "confusion_matrix_labels": list(classes),
    }


def main():
    print("=" * 70)
    print("STEP 1-2: Load dataset + clean")
    print("=" * 70)
    df = load_and_clean()
    X = df[ALL_FEATURES]
    y = df[TARGET_COL]
    print(f"\nFeatures used ({len(ALL_FEATURES)}): {ALL_FEATURES}")
    print("Target distribution:")
    print(y.value_counts(normalize=True).round(4).to_dict())

    print()
    print("=" * 70)
    print("STEP 3: Train/test split (stratified, 80/20)")
    print("=" * 70)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=RANDOM_STATE
    )
    print(f"Train: {len(X_train):,}  Test: {len(X_test):,}")

    print()
    print("=" * 70)
    print("STEP 4: Train + compare candidate models (5-fold CV on train)")
    print("=" * 70)
    candidates = {
        "LogisticRegression": LogisticRegression(max_iter=300, class_weight="balanced"),
        "RandomForest": RandomForestClassifier(
            n_estimators=300, max_depth=14, class_weight="balanced", n_jobs=-1, random_state=RANDOM_STATE
        ),
        "ExtraTrees": ExtraTreesClassifier(
            n_estimators=300, max_depth=14, class_weight="balanced", n_jobs=-1, random_state=RANDOM_STATE
        ),
    }

    def auc_ovr_macro(y_true, y_proba, **kwargs):
        return roc_auc_score(y_true, y_proba, multi_class="ovr", average="macro")

    scoring = {
        "accuracy": "accuracy",
        "f1_macro": "f1_macro",
        "precision_macro": "precision_macro",
        "recall_macro": "recall_macro",
        "roc_auc_ovr_macro": make_scorer(auc_ovr_macro, response_method="predict_proba"),
    }

    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=RANDOM_STATE)
    cv_results = {}
    for name, model in candidates.items():
        pipe = build_pipeline(model)
        cvres = cross_validate(pipe, X_train, y_train, cv=cv, scoring=scoring, n_jobs=1)
        summary = {k: float(np.mean(v)) for k, v in cvres.items() if k.startswith("test_")}
        cv_results[name] = summary
        print(
            f"  {name:20s} acc={summary['test_accuracy']:.3f}  f1_macro={summary['test_f1_macro']:.3f}  "
            f"prec_macro={summary['test_precision_macro']:.3f}  rec_macro={summary['test_recall_macro']:.3f}  "
            f"roc_auc_ovr={summary['test_roc_auc_ovr_macro']:.3f}"
        )

    print()
    print("=" * 70)
    print("STEP 5: Select best model (by CV ROC-AUC, not accuracy)")
    print("=" * 70)
    best_name = max(cv_results, key=lambda k: cv_results[k]["test_roc_auc_ovr_macro"])
    print(f"Best model: {best_name} (CV ROC-AUC={cv_results[best_name]['test_roc_auc_ovr_macro']:.3f})")

    best_pipe = build_pipeline(candidates[best_name])
    best_pipe.fit(X_train, y_train)
    classes = best_pipe.classes_

    print()
    print("=" * 70)
    print("STEP 6: Final evaluation on held-out test set")
    print("=" * 70)
    metrics = evaluate(best_pipe, X_test, y_test, classes)
    for k, v in metrics.items():
        if not k.startswith("confusion"):
            print(f"  {k}: {v}")
    print(f"\nConfusion matrix (labels={metrics['confusion_matrix_labels']}):")
    for row in metrics["confusion_matrix"]:
        print(" ", row)
    print()
    print(classification_report(y_test, best_pipe.predict(X_test)))

    print()
    print("=" * 70)
    print("STEP 7: Refit on ALL sampled data and save complete pipeline")
    print("=" * 70)
    final_pipe = build_pipeline(candidates[best_name])
    final_pipe.fit(X, y)
    model_path = MODEL_DIR / "risk_pipeline.joblib"
    joblib.dump(final_pipe, model_path)
    print(f"Saved pipeline to {model_path}")

    categories = {
        col: sorted(df[col].dropna().unique().tolist()) for col in CATEGORICAL_FEATURES
    }
    (MODEL_DIR / "categories.json").write_text(json.dumps(categories, indent=2))

    numeric_ranges = {
        col: {"min": float(df[col].min()), "max": float(df[col].max())} for col in NUMERIC_FEATURES
    }
    (MODEL_DIR / "numeric_ranges.json").write_text(json.dumps(numeric_ranges, indent=2))

    (MODEL_DIR / "fixed_context.json").write_text(json.dumps(FIXED_CONTEXT_DEFAULTS, indent=2))

    report = {
        "model_name": best_name,
        "dataset": "BDRoadRisk (Mendeley Data, DOI 10.17632/m33bsbsgx2.3) — SYNTHETIC",
        "sample_size": len(df),
        "sampling_strategy": "systematic 1-in-20 rows from the full 10,000,000-row source CSV",
        "live_controls": LIVE_CONTROLS,
        "auto_environment": AUTO_ENVIRONMENT,
        "fixed_context": FIXED_CONTEXT,
        "excluded_features": EXCLUDED_FEATURES,
        "target": f"{TARGET_COL}: No_Accident / Minor / Major",
        "cv_results": cv_results,
        "test_set_metrics": metrics,
        "class_distribution": y.value_counts(normalize=True).round(4).to_dict(),
    }
    (MODEL_DIR / "metrics.json").write_text(json.dumps(report, indent=2, default=str))
    print(f"Saved metrics to {MODEL_DIR / 'metrics.json'}")
    print(f"Saved category vocabulary to {MODEL_DIR / 'categories.json'}")
    print(f"Saved numeric ranges to {MODEL_DIR / 'numeric_ranges.json'}")
    print(f"Saved fixed-context defaults to {MODEL_DIR / 'fixed_context.json'}")


if __name__ == "__main__":
    main()
