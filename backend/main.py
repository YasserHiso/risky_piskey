import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from backend.schemas import PredictRequest, PredictResponse
from backend.services.predictor import ValidationError, predictor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("risk-api")


@asynccontextmanager
async def lifespan(app: FastAPI):
    predictor.load()
    yield


app = FastAPI(
    title="AI Driving Risk & Accident Severity Simulator API",
    description="Predicts accident-severity risk from driving conditions using a trained ML pipeline "
    "on the synthetic BDRoadRisk benchmark dataset.",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": predictor.pipeline is not None}


@app.get("/categories")
def get_categories():
    return {"categories": predictor.categories, "numeric_ranges": predictor.numeric_ranges}


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    if predictor.pipeline is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    try:
        return predictor.predict(req)
    except ValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Prediction failed")
        raise HTTPException(status_code=500, detail="Internal prediction error") from exc
