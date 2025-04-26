import pytest
from fastapi.testclient import TestClient
import base64
from unittest.mock import patch
from src.domain.models import FaceDetectionResponse

@pytest.fixture
def sample_image_base64():
    # Create a small dummy image
    return "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

class TestFaceDetectionEndpoint:
    @pytest.mark.asyncio
    async def test_detect_face_issues_success(self, test_client: TestClient, sample_image_base64):
        # Prepare test data
        request_data = {
            "image_base64": sample_image_base64
        }

        # Mock the face detection service
        mock_issues = ["Acne", "Dark spots"]
        with patch('src.services.face_detection.FaceDetectionService.detect_issues_gemini') as mock_detect:
            mock_detect.return_value = mock_issues
            
            # Make request to endpoint
            response = test_client.post("/api/v1/detect-face-issues", json=request_data)

        # Assert response
        assert response.status_code == 200
        assert response.json() == {"issues_detected": mock_issues}

    def test_detect_face_issues_invalid_image(self, test_client: TestClient):
        # Test with invalid base64
        request_data = {
            "image_base64": "invalid_base64"
        }
        
        response = test_client.post("/api/v1/detect-face-issues", json=request_data)
        
        assert response.status_code == 400

    def test_detect_face_issues_service_error(self, test_client: TestClient, sample_image_base64):
        request_data = {
            "image_base64": sample_image_base64
        }

        # Mock service to raise an exception
        with patch('src.services.face_detection.FaceDetectionService.detect_issues_gemini') as mock_detect:
            mock_detect.side_effect = Exception("Service error")
            
            response = test_client.post("/api/v1/detect-face-issues", json=request_data)

        assert response.status_code == 500
        assert "Service error" in response.json()["detail"]