import base64
from typing import List
import openai
import google.generativeai as genai
import asyncio
from  domain.models import FaceIssue
from  config import get_settings
from PIL import Image
from io import BytesIO
import re
import json



class FaceDetectionService:
    def __init__(self):
        self.settings = get_settings()
        openai.api_key = self.settings.OPENAI_API_KEY
        self._thread_pool = asyncio.get_event_loop().run_in_executor(None, lambda: None)

    async def detect_issues_openai(self, image_base64: str) -> str:
        try:
            try:
                await asyncio.to_thread(base64.b64decode, image_base64)
            except Exception:
                raise ValueError("Invalid base64 image format")

            prompt = """
                Analyze this face image and check if there are any visible signs of any of the following facial issues:
                1. Dark Circles - Look for dark discoloration under the eyes
                2. Flyaways - Look for hair strands that are visibly sticking out
                
                While analyzing the images take into consideration the following factors:
                1. Skin Tone and Type
                2. Lighting and Shadows
                3. Natural Facial Structure
                4. Fatigue vs. Pigmentation
                5. Hair Color and Texture (for Flyaways)

                Only report these specific issues if they are present. If none are found, return an empty list.

                Use this JSON format for the response:
                {
                    "issues": [
                        {
                            "issue": <issue_name>,
                            "description": <issue_description>
                        }
                        ...
                    ]
                }

                After creating the json make sure to fix any possible issues with the json format
                Ensure that the json is valid and well-structured.
                If there are any issues with the json format, fix them and return the corrected json.
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
            json_pattern = '\{.*\}'
            json_match = re.findall(json_pattern, content, flags=re.DOTALL)

            return json.loads(json_match[0])
            
        except Exception as e:
            raise Exception(f"Error processing image: {str(e)}") 
        
    async def detect_issues_gemini(self, image_base64: str) -> str:
        genai.configure(api_key=self.settings.GEMINI_API_KEY)   

        try:
            try:
                await asyncio.to_thread(base64.b64decode, image_base64)
            except Exception:
                raise ValueError("Invalid base64 image format")
            
            image_data = base64.b64decode(image_base64)
            image_data = Image.open(BytesIO(image_data))

            prompt = """
                Analyze this face image and check if there are any visible signs of any of the following facial issues:
                1. Dark Circles - Look for dark discoloration under the eyes
                2. Flyaways - Look for hair strands that are visibly sticking out
                
                While analyzing the images take into consideration the following factors:
                1. Skin Tone and Type
                2. Lighting and Shadows
                3. Natural Facial Structure
                4. Fatigue vs. Pigmentation
                5. Hair Color and Texture (for Flyaways)

                Only report these specific issues if they are present. If none are found, return an empty list.

                Use this JSON format for the response:
                {
                    "issues": [
                        {
                            "issue": <issue_name>,
                            "description": <issue_description>
                        }
                        ...
                    ]
                }

                After creating the json make sure to fix any possible issues with the json format.
                Ensure that the json is valid and well-structured.
                If there are any issues with the json format, fix them and return the corrected json.
            """
            
            model = genai.GenerativeModel(self.settings.GEMINI_MODEL_NAME)
            response = model.generate_content([
                prompt,
                image_data
            ])

            json_pattern = '\{.*\}'
            content = response.text
            json_match = re.findall(json_pattern, content, flags=re.DOTALL)
            print(content)
            print(json_match[0])
            return json.loads(json_match[0])
        
        except Exception as e:
            raise Exception(f"Error processing image: {str(e)}") 