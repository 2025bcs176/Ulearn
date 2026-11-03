"""Notification and device-token transport types.

The response never carries a user id: the only user who can read a notification
is the one it belongs to, so the field would be the caller's own id repeated on
every row. It also never carries a device token back, because a token is a
credential that can be used to push to a handset -- echoing it would put it in a
response body, a client log, and a proxy trace for no benefit when the client
already holds the value it sent.
"""

import uuid
from datetime import datetime

from pydantic import Field

from app.models.enums import DevicePlatform, NotificationType
from app.models.notification import MAX_DEVICE_TOKEN_LENGTH
from app.schemas.base import OrmSchema, RequestSchema, Trimmed
from app.schemas.common import Page

#: Longer than any real FCM registration token, short enough that the column and
#: the request agree. A token much shorter than this is a client bug rather than
#: a handset, and accepting it would fill the table with placeholders.
MIN_DEVICE_TOKEN_LENGTH = 20


class NotificationResponse(OrmSchema):
    """One inbox row, exactly as its owner reads it."""

    id: uuid.UUID = Field(validation_alias="public_id")
    type: NotificationType
    title: str
    body: str
    data: dict[str, str] | None = None
    read_at: datetime | None = None
    created_at: datetime


class NotificationPage(Page[NotificationResponse]):
    """A bounded page of one user's inbox."""


class UnreadCountResponse(OrmSchema):
    """The number on the bell."""

    count: int = Field(ge=0)


class ReadAllResponse(OrmSchema):
    """How many rows the operation actually changed.

    A client that shows "all caught up" can tell a fresh empty inbox from one
    where the request was a no-op, and the count is the cheapest way to say so.
    """

    marked: int = Field(ge=0)


class DeviceRegistrationRequest(RequestSchema):
    """A handset asking to receive push for the signed-in account."""

    token: Trimmed = Field(
        min_length=MIN_DEVICE_TOKEN_LENGTH,
        max_length=MAX_DEVICE_TOKEN_LENGTH,
        description="The push provider's registration token for this install.",
    )
    platform: DevicePlatform


class DeviceResponse(OrmSchema):
    """A registered device, without the token that identifies it."""

    id: uuid.UUID = Field(validation_alias="public_id")
    platform: DevicePlatform
    last_seen_at: datetime
