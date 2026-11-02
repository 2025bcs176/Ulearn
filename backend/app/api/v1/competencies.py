"""Tutor competence validation routes."""

import uuid
from typing import Annotated

from fastapi import APIRouter, File, Response, UploadFile, status

from app.api.deps import CurrentUser, DatabaseSession
from app.schemas.competency import CompetencyCreate, CompetencyResponse
from app.services import validation_service

router = APIRouter(prefix="/competencies", tags=["competencies"])


@router.get("/me", response_model=list[CompetencyResponse], summary="My competencies")
async def list_my_competencies(
    caller: CurrentUser,
    db: DatabaseSession,
) -> list[CompetencyResponse]:
    """Every submitted proof for the signed-in tutor."""
    return await validation_service.list_competencies(db, caller.user)


@router.post(
    "",
    response_model=CompetencyResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit tutor validation evidence",
)
async def create_competency(
    payload: CompetencyCreate,
    caller: CurrentUser,
    db: DatabaseSession,
) -> CompetencyResponse:
    """Submit a transcript or portfolio claim for a course unit."""
    return await validation_service.create_competency(db, caller.user, payload)


@router.post(
    "/{competency_id}/evidence",
    response_model=CompetencyResponse,
    summary="Upload transcript or QR evidence",
)
async def upload_evidence(
    competency_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
    upload: Annotated[UploadFile, File()],
) -> CompetencyResponse:
    """Upload a transcript/QR file for a competency and store its reference."""
    return await validation_service.upload_evidence(
        db, caller.user, competency_id, upload
    )


@router.get(
    "/{competency_id}/evidence",
    summary="Download transcript or QR evidence",
)
async def download_evidence(
    competency_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
) -> Response:
    """Stream the stored evidence file (authenticated)."""
    data, content_type = await validation_service.download_evidence(
        db, caller.user, competency_id
    )
    return Response(content=data, media_type=content_type)


@router.get(
    "/{competency_id}",
    response_model=CompetencyResponse,
    summary="Fetch one competency",
)
async def get_competency(
    competency_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
) -> CompetencyResponse:
    """A single competency record owned by the signed-in user."""
    return await validation_service.get_competency(db, caller.user, competency_id)
