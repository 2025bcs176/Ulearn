"""Post-session ratings.

The rule that a completed session requires a rating is *not* enforced here, and
it cannot be: it spans `sessions` and `ratings`, and a CHECK constraint may only
reference columns of its own row. PostgreSQL could express it as a deferred
constraint trigger, at the cost of making the schema harder to read and to
migrate for a rule that has exactly one legitimate enforcement point.

It is therefore a service-layer rule -- see `app.services.sessions` -- and this
module's job is to make enforcing it possible rather than to pretend to: the
score is bounded, a rater cannot rate the same session twice, and
`Session.is_rated` is the check that rule is written against.
"""

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import (
    JSON,
    CheckConstraint,
    ForeignKey,
    Integer,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.security import new_uuid7
from app.models.base import TimestampMixin, public_id_column

if TYPE_CHECKING:
    from app.models.session import Session
    from app.models.user import User

#: The bounds of the rating scale. Stated once so the schema check, the schemas,
#: and the tests cannot disagree about what a valid score is.
MIN_RATING = 1
MAX_RATING = 5

#: How many tags one rating may carry.
#:
#: Four, and not "as many as apply": the tags are a summary a student reads at a
#: glance, and a rating that ticks every box says nothing. The cap also bounds
#: what a single submission can make the profile render.
MAX_TAGS_PER_RATING = 4


class Rating(Base, TimestampMixin):
    """One person's assessment of one session."""

    __tablename__ = "ratings"
    __table_args__ = (
        # One rating per person per session. A retried submit updates the
        # existing row instead of adding a second score that would be averaged
        # in twice.
        UniqueConstraint("session_id", "rater_id", name="rating_per_rater"),
        CheckConstraint(
            f"score >= {MIN_RATING} AND score <= {MAX_RATING}",
            name="score_within_scale",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=new_uuid7)
    public_id: Mapped[uuid.UUID] = public_id_column()

    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )

    rater_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    #: The other party. Stored rather than derived from the session so a rating
    #: survives the session row being archived, and so a query for a tutor's
    #: feedback does not have to join through sessions.
    ratee_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    score: Mapped[int] = mapped_column(Integer, nullable=False)
    comprehension_helped: Mapped[bool] = mapped_column(
        nullable=False, default=False, server_default="false"
    )

    #: Optional free text from the rater. A tutor suspended on a low average is
    #: entitled to know which session drove it, which is why this is kept rather
    #: than discarded with the rest of the rating.
    feedback_text: Mapped[str | None] = mapped_column(Text, nullable=True)

    #: What the rater said about the session, from the fixed vocabulary in
    #: `RatingTag`. Stored as a JSON array rather than a child table.
    #:
    #: A table of its own would buy nothing here: a tag has no attributes, is
    #: never queried on its own, and is always read with the rating it belongs
    #: to. What the array shape does cost is a database check on the values --
    #: `jsonb` could express membership on PostgreSQL and `json` on SQLite
    #: cannot -- so the vocabulary is enforced by `RatingCreate`, and an array is
    #: all the column promises. `default=list` is a callable on purpose: a
    #: mutable default shared between instances would let one rating's tags
    #: appear on another.
    #:
    #: No server default, unlike the counters elsewhere in this package. A JSON
    #: default is the one comparison `alembic check` cannot make on PostgreSQL
    #: (`'[]'::json = '[]'` has no equality operator), so carrying one here would
    #: report drift on every migration check for the rest of the project's life.
    tags: Mapped[list[str]] = mapped_column(
        JSON,
        nullable=False,
        default=list,
    )

    session: Mapped[Session] = relationship(back_populates="ratings")
    rater: Mapped[User] = relationship(foreign_keys=[rater_id])
    ratee: Mapped[User] = relationship(foreign_keys=[ratee_id])

    #: Public id of the user whose rating this is. A response that exposed
    #: `rater_id` straight from the column would leak an internal key, and a
    #: profile listing would then be built from primary keys.

    @property
    def session_public_id(self) -> uuid.UUID:
        return self.session.public_id

    @property
    def rater_public_id(self) -> uuid.UUID:
        return self.rater.public_id

    @property
    def ratee_public_id(self) -> uuid.UUID:
        return self.ratee.public_id

    def __repr__(self) -> str:
        return f"<Rating {self.score} by {self.rater_id}>"
