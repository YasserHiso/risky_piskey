from typing import Literal

from pydantic import BaseModel, Field


class PredictRequest(BaseModel):
    speed_kmh: float = Field(..., ge=0, le=250, description="Current vehicle speed in km/h")
    seatbelt_worn: Literal["Yes", "No"]
    weather_condition: str
    road_surface: str
    light_condition: str
    time_of_day: str


class PredictResponse(BaseModel):
    prediction: Literal["No_Accident", "Minor", "Major"]
    risk_label: Literal["SAFE", "MINOR RISK", "HIGH RISK"]
    probability: float
    probability_percent: int
    probabilities: dict[str, float]
