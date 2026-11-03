"""In-app notifications and the devices that can receive them.

Two tables rather than one. A notification belongs to a person and has to be
readable on any device they sign in from; a push token belongs to a physical
device and moves between accounts when someone signs out and someone else signs
in. Storing the token on the notification would tie an inbox row to a handset.

`notifications` is the real deliverable. Push is a delivery channel on top of it,
and the in-app inbox keeps working with Firebase unconfigured -- the beta's first
build has no reason to make reading a request conditional on a push provider.
"""

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    JSON,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.security import new_uuid7
from app.models.base import TimestampMixin, enum_column, public_id_column
from app.models.enums import DevicePlatform, NotificationType

if TYPE_CHECKING:
    from app.models.user import User

#: Bumped together when either column grows. A title is a line; a body is the
#: sentence under it. Both are bounded so a notification cannot become a page.
MAX_TITLE_LENGTH = 120
MAX_BODY_LENGTH = 500
MAX_DEDUPE_KEY_LENGTH = 200
MAX_DEVICE_TOKEN_LENGTH = 512


class Notification(Base, TimestampMixin):
    """One thing that happened, addressed to one person.

    Separate from the event it describes. A session has two parties and each
    gets its own row, because "read" is a fact about a reader: sharing one row
    would mark the message read for the other person the moment either opened
    their inbox.

    `read_at` is a timestamp rather than a boolean so the inbox can say when
    something was read, and so a future retention job has something to work
    from.
    """

    __tablename__ = "notifications"
    __table_args__ = (
        # A notification is written inside the transaction of the action that
        # caused it, so a failed session update cannot leave a message saying
        # the session happened. The unique constraint is what makes a retried
        # event safe: the second insert loses, and the caller carries on.
        UniqueConstraint("user_id", "dedupe_key", name="uq_notifications_user_dedupe"),
        # The inbox query is "this user, newest first", and the badge is "this
        # user, unread". One index serves both, and the leading `user_id` is
        # what keeps two users' pages from interleaving in the scan.
        Index(
            "ix_notifications_user_read_created",
            "user_id",
            "read_at",
            "created_at",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=new_uuid7)
    public_id: Mapped[uuid.UUID] = public_id_column()

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )

    type: Mapped[NotificationType] = mapped_column(
        enum_column(NotificationType, name="notification_type"),
        nullable=False,
        index=True,
    )

    title: Mapped[str] = mapped_column(String(MAX_TITLE_LENGTH), nullable=False)

    body: Mapped[str] = mapped_column(String(MAX_BODY_LENGTH), nullable=False)

    #: Public ids and names the client needs to open the right screen. Values
    #: are strings because that is what JSON keys can hold without the client
    #: second-guessing a type; an id is opaque either way.
    data: Mapped[dict[str, str] | None] = mapped_column(JSON, nullable=True)

    #: Null means unread. Set once, by the owner, when they open the inbox.
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    #: The identity of the event this row announces, when a caller wants at most
    #: one notification per event. Null for the ordinary case, where every
    #: occurrence is worth a row. Nulls are distinct in both SQLite and
    #: PostgreSQL, so an unkeyed notification never collides with another.
    dedupe_key: Mapped[str | None] = mapped_column(
        String(MAX_DEDUPE_KEY_LENGTH), nullable=True
    )

    user: Mapped[User] = relationship()

    def __repr__(self) -> str:
        return f"<Notification {self.public_id} {self.type}>"


class DeviceToken(Base, TimestampMixin):
    """A push token belonging to one handset.

    `token` is unique across the table rather than per user. Firebase issues one
    token per app installation, so the same string arriving for a second account
    means the handset changed hands -- registering it again has to move it, not
    create a second row that would deliver one person's notifications to another
    person's phone.
    """

    __tablename__ = "device_tokens"
    __table_args__ = (
        CheckConstraint("length(token) > 0", name="device_token_not_blank"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=new_uuid7)

    #: Carried for the same codebase-wide reason as on `rate_limit_counters`:
    #: no mapped model is reachable only by its primary key, even when no
    #: endpoint returns the row.
    public_id: Mapped[uuid.UUID] = public_id_column()

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    token: Mapped[str] = mapped_column(
        String(MAX_DEVICE_TOKEN_LENGTH), nullable=False, unique=True
    )

    platform: Mapped[DevicePlatform] = mapped_column(
        enum_column(DevicePlatform, name="device_platform"), nullable=False
    )

    #: Refreshed on every registration, so a token that has not been seen since
    #: an app was uninstalled can be pruned without guessing.
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )

    user: Mapped[User] = relationship()

    def __repr__(self) -> str:
        return f"<DeviceToken {self.public_id} {self.platform}>"
