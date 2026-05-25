from fastapi import FastAPI
from app.core.config import settings

app = FastAPI(title=settings.APP_NAME)


@app.get("/health")
async def health() -> dict[str, bool]:
    return {"ok": True}
