from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from src.api.v1.endpoints import router as v1_router
from src.config import get_settings
import uvicorn
import asyncio
from concurrent.futures import ThreadPoolExecutor

settings = get_settings()

asyncio.set_event_loop_policy(asyncio.DefaultEventLoopPolicy())

thread_pool = ThreadPoolExecutor(max_workers=settings.MAX_WORKERS)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="An asynchronous REST API for detecting face issues using GPT-4 Vision",
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url=f"{settings.API_V1_STR}/docs",
    redoc_url=f"{settings.API_V1_STR}/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(v1_router, prefix=settings.API_V1_STR)

@app.on_event("startup")
async def startup_event():
    loop = asyncio.get_event_loop()
    loop.set_default_executor(thread_pool)

@app.on_event("shutdown")
async def shutdown_event():
    thread_pool.shutdown(wait=True)

if __name__ == "__main__":
    uvicorn.run(
        "face_issue_detection.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=True,
        workers=settings.MAX_WORKERS,
        loop="uvloop",
        http="httptools"
    ) 