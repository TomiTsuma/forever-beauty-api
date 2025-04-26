import pytest
from fastapi.testclient import TestClient
from src.config import Settings, get_settings
from typing import Generator
import os
import sys
from pathlib import Path

project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))
sys.path.append("../src")
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../src")))


@pytest.fixture(scope="session")
def test_settings() -> Settings:
    # Create test settings with test values
    return Settings(
        _env_file=".env.test",
    )

@pytest.fixture(scope="session")
def test_client(test_settings) -> Generator:
    # Override settings for testing
    from src.main import app  # Import your FastAPI app
    
    def get_test_settings():
        return test_settings
        
    app.dependency_overrides[get_settings] = get_test_settings
    
    with TestClient(app) as client:
        yield client