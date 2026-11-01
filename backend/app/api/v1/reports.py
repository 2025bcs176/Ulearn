import uuid

from fastapi import APIRouter, status

from app.api.deps import CurrentUser, DatabaseSession
from app.schemas.report import ReportCreate, ReportResponse
from app.services import report_service

router = APIRouter(prefix="/sessions", tags=["safeguarding"])


@router.post(
    "/{session_id}/reports",
    response_model=ReportResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Report a session",
)
async def report_session(
    session_id: uuid.UUID,
    payload: ReportCreate,
    caller: CurrentUser,
    db: DatabaseSession,
) -> ReportResponse:
    return await report_service.create_report(db, caller.user, session_id, payload)
