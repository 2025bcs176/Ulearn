"""Compatibility shim.

Re-exports the canonical PeerPass FastAPI app so that ``uvicorn main:app``
works as documented, while routing all requests through the proper
``app.main`` application with its /v1 routes, health checks, and security
middleware.
"""

from app.main import create_app

app = create_app()

__all__ = ["app"]
