import base64
from typing import List
import openai
import asyncio
from ..domain.models import FaceIssue
from ..config import get_settings


class FaceDetectionService:
    def __init__(self):
        self.settings = get_settings()
        openai.api_key = self.settings.OPENAI_API_KEY
        self._thread_pool = asyncio.get_event_loop().run_in_executor(None, lambda: None)

    async def detect_issues(self, image_base64: str) -> List[FaceIssue]:
        try:
            try:
                await asyncio.to_thread(base64.b64decode, image_base64)
            except Exception:
                raise ValueError("Invalid base64 image format")

            prompt = """
            Analyze this face image and detect the following issues:
            1. Dark Circles - Look for dark discoloration under the eyes
            2. Flyaways - Look for hair strands that are visibly sticking out
            
            Only report these specific issues if they are present. If none are found, return an empty list.
            """
            
            response = await asyncio.to_thread(
                openai.chat.completions.create,
                model=self.settings.MODEL_NAME,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{image_base64}"
                                }
                            }
                        ]
                    }
                ],
                max_tokens=self.settings.MAX_TOKENS
            )
            
            content = response.choices[0].message.content.lower()
            issues = []
            
            if "dark circles" in content:
                issues.append(FaceIssue(
                    issue="Dark Circles",
                    description="Dark circles and discoloration below eyes"
                ))
            
            if "flyaways" in content:
                issues.append(FaceIssue(
                    issue="Flyaways",
                    description="Hair strands visibly sticking out"
                ))
            
            return issues
        
        except Exception as e:
            raise Exception(f"Error processing image: {str(e)}") 