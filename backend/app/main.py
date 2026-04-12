from fastapi import FastAPI
from app.routes.predict import router as predict_router

app = FastAPI(
    title="MEng Project Backend",
    version="1.0.0",
    description="Backend API for skin lesion image analysis."
)

@app.get("/")
def root() -> dict[str, str]:
    return {"message": "MEng Project backend is running."}

@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok"}

app.include_router(predict_router)