"""Tutoring session scheduling and logging routes."""

import uuid

from fastapi import APIRouter, status

from app.api.deps import CurrentUser, DatabaseSession
from app.schemas.session import (
    SessionCreate,
    SessionResponse,
    SessionTransitionRequest,
)
from app.services import session_service

router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post(
    "",
    response_model=SessionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create an accepted tutoring session",
)
async def create_session(
    payload: SessionCreate,
    caller: CurrentUser,
    db: DatabaseSession,
) -> SessionResponse:
    """Accept a matched request and create the live tutoring session."""
    return await session_service.create_session(db, caller.user, payload)


@router.get(
    "/me",
    response_model=list[SessionResponse],
    summary="My sessions",
)
async def list_sessions(
    caller: CurrentUser,
    db: DatabaseSession,
) -> list[SessionResponse]:
    """Every session the current user is part of."""
    return await session_service.list_sessions(db, caller.user)


@router.get(
    "/{session_id}",
    response_model=SessionResponse,
    summary="Load one session",
)
async def get_session(
    session_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
) -> SessionResponse:
    """Fetch a specific session that belongs to the caller."""
    return await session_service.get_session(db, caller.user, session_id)


@router.post(
    "/{session_id}/transition",
    response_model=SessionResponse,
    summary="Cancel or mark a session as a no-show",
)
async def transition_session(
    session_id: uuid.UUID,
    payload: SessionTransitionRequest,
    caller: CurrentUser,
    db: DatabaseSession,
) -> SessionResponse:
    """Cancel a session or record that it did not happen.

    Starting and completing are deliberately not transitions: they are
    `check-in` and `finish`, called by both parties, so no single account can
    move a session to a state that claims the other person was present.
    """
    return await session_service.transition_session(
        db,
        caller.user,
        session_id,
        payload,
    )


@router.post(
    "/{session_id}/check-in",
    response_model=SessionResponse,
    summary="Record your arrival for a session",
)
async def check_in(
    session_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
) -> SessionResponse:
    """One party's half of the start handshake.

    The session goes live when both parties have called this. Repeating the
    call is harmless: it does not move the timestamp a second time and does not
    report an error for a check-in that already happened.
    """
    return await session_service.check_in(db, caller.user, session_id)


@router.post(
    "/{session_id}/finish",
    response_model=SessionResponse,
    summary="Record your departure from a session",
)
async def finish(
    session_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
) -> SessionResponse:
    """One party's half of the completion handshake.

    The session completes when both parties have called this, and only then are
    the minutes banked. The elapsed time is the window both were present, so one
    party cannot extend the session after the other has left.
    """
    return await session_service.finish(db, caller.user, session_id)
