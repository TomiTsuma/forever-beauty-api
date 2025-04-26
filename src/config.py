from typing import List, Optional
from pydantic_settings import BaseSettings
from functools import lru_cache
import json


class Settings(BaseSettings):
    API_V1_STR: str
    PROJECT_NAME: str
    VERSION: str
    
    HOST: str
    PORT: int
    MAX_WORKERS: int
    RELOAD: bool
    
    OPENAI_API_KEY: str
    MODEL_NAME: str
    MAX_TOKENS: int

    GEMINI_API_KEY: str
    GEMINI_MODEL_NAME: str
    
    DOCKER_IMAGE_NAME: str
    DOCKER_IMAGE_TAG: str
    
    AWS_REGION: str
    AWS_ACCOUNT_ID: str
    ECR_REPOSITORY: str
    ECS_CLUSTER_NAME: str
    ECS_SERVICE_NAME: str
    ECS_TASK_FAMILY: str
    ECS_CONTAINER_NAME: str
    ECS_CONTAINER_PORT: int
    ECS_CPU: int
    ECS_MEMORY: int
    ECS_DESIRED_COUNT: int
    
    LOG_LEVEL: str
    LOG_FORMAT: str
    
    CORS_ORIGINS: List[str]
    CORS_METHODS: List[str]
    CORS_HEADERS: List[str]
    CORS_CREDENTIALS: bool
    
    UVICORN_WORKERS: int
    # UVICORN_LOOP: str
    UVICORN_HTTP: str
    UVICORN_RELOAD: bool
    UVICORN_HOST: str
    UVICORN_PORT: int
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        
        @classmethod
        def parse_env_var(cls, field_name: str, raw_val: str) -> any:
            if field_name in ["CORS_ORIGINS", "CORS_METHODS", "CORS_HEADERS"]:
                return json.loads(raw_val)
            return raw_val


@lru_cache()
def get_settings() -> Settings:
    return Settings() 