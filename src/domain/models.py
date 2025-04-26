from pydantic import BaseModel
from typing import List


class FaceIssue(BaseModel):
    issue: str
    description: str


class FaceDetectionRequest(BaseModel):
    image_base64: str


class FaceDetectionResponse(BaseModel):
    issues_detected: dict[str, str]