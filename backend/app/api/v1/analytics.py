from fastapi import APIRouter

from app.api.deps import AdminUser, DatabaseSession
from app.schemas.analytics import PilotFunnelResponse, TopicHeatmapResponse
from app.services import analytics_service

router = APIRouter(prefix="/admin/analytics", tags=["admin analytics"])


@router.get("/topic-heatmap", response_model=TopicHeatmapResponse)
async def get_topic_heatmap(
    _caller: AdminUser,
    db: DatabaseSession,
) -> TopicHeatmapResponse:
    return await analytics_service.topic_heatmap(db)


@router.get("/pilot-funnel", response_model=PilotFunnelResponse)
async def get_pilot_funnel(
    _caller: AdminUser,
    db: DatabaseSession,
) -> PilotFunnelResponse:
    """Count the pilot's requests, accepted requests, and completed/rated sessions.

    Aggregates only. The operator needs to know whether the loop is moving, not
    who is inside it; anything that names a student belongs in a different
    report, behind a different decision.
    """
    return await analytics_service.pilot_funnel(db)
