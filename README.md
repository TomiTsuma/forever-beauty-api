# Async Face Issue Detection API

This project implements an asynchronous REST API using FastAPI to detect face issues (Dark Circles and Flyaways) using OpenAI's GPT-4 Vision API.

Requires python3.11

## Features

- Base64 image input support
- Asynchronous processing of face images
- Support for 20+ concurrent requests
- Detection of Dark Circles and Flyaways
- Error handling and input validation
- Docker containerization
- AWS ECS deployment support
- AWS EC2 deployment support


## Setup

1. Clone the repository
2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Create a `.env` file use the .env.example as your guide

## Running the Application

```bash
    python src/main.py
```

The API will be available at `http://localhost:8000`

## Project Structure

```
forever_beauty_api/
├── src/
│   ├── __init__.py
│   ├── main.py            # FastAPI application entry point
│   ├── config.py          # Configuration settings
│   ├── models/            # Data models
│   ├── routers/           # API routes
│   └── services/          # Business logic
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── e2e/              # End-to-end tests
│   └── unit/             # Unit tests
├── .env                   # Environment variables
├── .gitignore
├── Dockerfile
├── README.md
└── requirements.txt
```

# Run all tests
pytest

# Run specific test types
pytest -m e2e


## ECS Deployment
Run the following commands
```bash
    mv ./scripts/build_and_push.sh ./
    bash build_and_push.sh
    bash ./scripts/ecs_deploy.sh
```