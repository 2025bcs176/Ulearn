from fastapi import APIRouter

from app.api.deps import AdminUser, DatabaseSession
from app.schemas.analytics import TopicHeatmapResponse
from app.services import analytics_service

router = APIRouter(prefix="/admin/analytics", tags=["admin analytics"])


@router.get("/topic-heatmap", response_model=TopicHeatmapResponse)
async def get_topic_heatmap(
    _caller: AdminUser,
    db: DatabaseSession,
) -> TopicHeatmapResponse:
    return await analytics_service.topic_heatmap(db)
