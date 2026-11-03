"""Aggregate tutor performance, maintained as sessions complete.

Counters are stored rather than recomputed per request. The promotion rule
needs an average rating and a session count on every matching query, and
aggregating the whole session log on each one would make the matching endpoint's
cost grow with the pilot's history rather than with the page being served.

The averages are deliberately not stored as a float. A running total and a
count divide to the current average without the rounding error that a stored
running average accumulates, which matters because the promotion threshold is an
equality test.
"""

import uuid
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, CheckConstraint, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.security import new_uuid7
from app.models.base import (
    TimestampMixin,
    enum_column,
    public_id_column,
)
from app.models.enums import TutorStanding

if TYPE_CHECKING:
    from app.models.user import User


class TutorProfile(Base, TimestampMixin):
    """A tutor's standing and the counters the standing is derived from.

    A row exists for every user holding the tutor role, created when the role is
    granted. It is separate from `users` because a student's row has no standing
    and no reason to carry columns that are always null for them.
    """

    __tablename__ = "tutor_profiles"
    __table_args__ = (
        CheckConstraint(
            "completed_sessions >= 0", name="completed_sessions_non_negative"
        ),
        CheckConstraint("rating_count >= 0", name="rating_count_non_negative"),
        CheckConstraint("rating_total >= 0", name="rating_total_non_negative"),
        # A total below its count would mean a negative rating slipped in.
        CheckConstraint(
            "rating_total >= rating_count", name="rating_total_at_least_count"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=new_uuid7)
    public_id: Mapped[uuid.UUID] = public_id_column()

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )

    #: `server_default` as well as `default` because the migration, a data fix,
    #: or a future analytics query may insert without going through the ORM, and
    #: a column that is only defaulted in Python is NULL for all of them.
    standing: Mapped[TutorStanding] = mapped_column(
        enum_column(TutorStanding, name="tutor_standing"),
        nullable=False,
        default=TutorStanding.PROBATIONARY,
        server_default=TutorStanding.PROBATIONARY.value,
    )

    completed_sessions: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )

    #: Sessions that counted towards a certificate, in minutes. Distinct from
    #: `completed_sessions`, because the two thresholds count different things:
    #: promotion is about breadth of experience, certificate eligibility about
    #: volume of time.
    certified_minutes: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )

    rating_total: Mapped[Decimal] = mapped_column(
        Numeric(10, 2), nullable=False, default=Decimal("0"), server_default="0"
    )

    rating_count: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )

    #: Set when the tutor was suspended, with the reason. Kept so a suspension
    #: is explainable to the tutor and auditable later.
    suspended_reason: Mapped[str | None] = mapped_column(nullable=True)
    operator_suspended: Mapped[bool] = mapped_column(
        nullable=False, default=False, server_default="false"
    )

    #: A few sentences in the tutor's own voice, shown on their card and detail
    #: screen. Bounded rather than free text because it sits inside a card: a
    #: tutor who writes an essay is not summarised by it, and the client would
    #: have to truncate a sentence it cannot see the end of.
    #:
    #: Nullable, and null is a normal state: a tutor who has not written one is
    #: shown their grade evidence and standing instead, which is what the card
    #: was doing before bios existed.
    bio: Mapped[str | None] = mapped_column(String(280), nullable=True)

    #: A photo, when one has been uploaded. The beta ships generated initials
    #: avatars, so this is null for every seeded tutor; the column exists so
    #: turning photos on later is a server-side change rather than a migration
    #: in the middle of the pilot.
    #:
    #: Stored as a URL rather than bytes: the API is not a file host, and a
    #: database column holding an image makes every tutor query read it.
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    #: How a student reaches the tutor once a session exists. Private: it is
    #: returned to the two parties of a confirmed session and to nobody else,
    #: because a phone number on a public tutor card is a number that gets
    #: called by people who never booked.
    contact_phone: Mapped[str | None] = mapped_column(String(32), nullable=True)

    #: Whether the tutor is currently taking new requests.
    #:
    #: The beta's stand-in for an availability calendar: a single switch a tutor
    #: can flip when they are too busy to teach, rather than a weekly schedule
    #: the pilot has no booking engine to honour. Matching excludes a tutor who
    #: has paused, so pausing is a real promise rather than a label.
    accepting_requests: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True, server_default="true"
    )

    user: Mapped[User] = relationship(back_populates="tutor_profile")

    @property
    def average_rating(self) -> Decimal | None:
        """The mean rating, or None when there are no ratings yet.

        None rather than zero: a tutor with no ratings is not badly rated, and
        treating them as zero would fail a `>= 4.0` promotion test for the
        wrong reason.
        """
        # `not` rather than `== 0` so an unsaved profile, whose Python-side
        # defaults are not populated until flush, reads as unrated rather than
        # dividing a None total by a count.
        if not self.rating_count:
            return None
        return (self.rating_total or Decimal("0")) / Decimal(self.rating_count)

    def __repr__(self) -> str:
        return f"<TutorProfile user={self.user_id} {self.standing}>"
