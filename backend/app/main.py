"""FastAPI application entry point."""

from fastapi import FastAPI

app = FastAPI(title="Ulearn API", version="0.1.0")


@app.get("/health", tags=["system"])
def health_check() -> dict[str, str]:
    """Report service availability."""
    return {"status": "ok"}
