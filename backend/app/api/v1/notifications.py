"""The signed-in user's inbox and push registration.

Every path here is scoped to the caller's own rows. There is no admin variant:
an operator already has the audit log and the review queues, and an inbox that
could be read from the console would be a second, quieter way to read a
student's messages.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import CurrentUser, DatabaseSession
from app.schemas.common import PageParams
from app.schemas.notification import (
    DeviceRegistrationRequest,
    DeviceResponse,
    NotificationPage,
    NotificationResponse,
    ReadAllResponse,
    UnreadCountResponse,
)
from app.services import notification_service

router = APIRouter(prefix="/notifications", tags=["notifications"])

InboxPageParams = Annotated[PageParams, Depends()]


@router.get("", response_model=NotificationPage, summary="My notifications")
async def list_notifications(
    caller: CurrentUser,
    db: DatabaseSession,
    params: InboxPageParams,
) -> NotificationPage:
    """One page of the caller's inbox, newest first."""
    return await notification_service.list_notifications(db, caller.user, params)


@router.get(
    "/unread-count",
    response_model=UnreadCountResponse,
    summary="How many notifications are unread",
)
async def unread_count(
    caller: CurrentUser,
    db: DatabaseSession,
) -> UnreadCountResponse:
    """The number behind the bell."""
    return UnreadCountResponse(
        count=await notification_service.unread_count(db, caller.user)
    )


@router.post(
    "/{notification_id}/read",
    response_model=NotificationResponse,
    summary="Mark one notification read",
)
async def mark_read(
    notification_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
) -> NotificationResponse:
    """Idempotent: reading twice is the same as reading once."""
    return await notification_service.mark_read(db, caller.user, notification_id)


@router.post(
    "/read-all",
    response_model=ReadAllResponse,
    summary="Mark every notification read",
)
async def mark_all_read(
    caller: CurrentUser,
    db: DatabaseSession,
) -> ReadAllResponse:
    """Clear the badge in one tap, and report how many rows changed."""
    return ReadAllResponse(
        marked=await notification_service.mark_all_read(db, caller.user)
    )


@router.post(
    "/devices",
    response_model=DeviceResponse,
    summary="Register this device for push",
)
async def register_device(
    payload: DeviceRegistrationRequest,
    caller: CurrentUser,
    db: DatabaseSession,
) -> DeviceResponse:
    """Idempotent: re-registering refreshes the token's owner and last-seen time."""
    return await notification_service.register_device(db, caller.user, payload)


@router.delete(
    "/devices/{token}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Forget this device",
)
async def remove_device(
    token: str,
    caller: CurrentUser,
    db: DatabaseSession,
) -> Response:
    """Called on sign-out. Succeeds even when the token is already gone."""
    await notification_service.remove_device(db, caller.user, token)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
