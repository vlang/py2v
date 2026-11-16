from typing import Optional
from pydantic import BaseModel, Field


class Mood(BaseModel):
    mood: str = Field(min_length=1, max_length=500, description="Mood text")
    valence: float = Field(ge=-1.0, le=1.0, description="Pleasure")
    dominance: float = Field(ge=0.0, le=1.0, default=0.5, description="Dominance")
    category: Optional[str] = Field(default=None, max_length=50)
    tags: list[str] = Field(default_factory=list)
    weight: float = Field(1.5, ge=0.0)
    required: int = Field(...)
