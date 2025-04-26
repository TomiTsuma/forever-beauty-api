from fastapi import APIRouter, HTTPException, BackgroundTasks
from  domain.models import FaceDetectionRequest, FaceDetectionResponse
from  services.face_detection import FaceDetectionService
from  config import get_settings
import asyncio

router = APIRouter()
settings = get_settings()
face_detection_service = FaceDetectionService()


@router.post("/detect-face-issues")
async def detect_face_issues(
    request: FaceDetectionRequest,
    background_tasks: BackgroundTasks
):
    try:
        issues = await face_detection_service.detect_issues_gemini(request.image_base64)
        
        return {"issues_detected": issues}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) 