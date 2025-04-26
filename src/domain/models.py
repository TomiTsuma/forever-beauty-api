from pydantic import BaseModel
from typing import List, Dict


class FaceIssue(BaseModel):
    issue: str
    description: str


class FaceDetectionRequest(BaseModel):
    image_base64: str


class FaceDetectionResponse(BaseModel):
    issues_detected: Dict[str, str]