"""Suggested questions inside one course unit.

A course unit is too broad to type a help request against ("Linear Algebra II"
is a semester), and a student asking for help often cannot name the concept they
are stuck on. These are the unit's own suggestions, so the request sheet can
offer them as chips instead of asking a first-year to invent the vocabulary.

Reference data, like the units they belong to: loaded by an administrator, never
created by a student. The list is advisory and nothing is matched on it -- a
student may still type their own topic, and a topic outside this table is not a
worse request.
"""

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.security import new_uuid7
from app.models.base import TimestampMixin, public_id_column

if TYPE_CHECKING:
    from app.models.course_unit import CourseUnit


class CourseUnitTopic(Base, TimestampMixin):
    """One suggested topic for one course unit."""

    __tablename__ = "course_unit_topics"

    #: One label per unit. Seeding is idempotent by this constraint rather than by
    #: the label alone, because two units may legitimately suggest "Recursion".
    __table_args__ = (
        UniqueConstraint("course_unit_id", "label", name="topic_label_per_course_unit"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=new_uuid7)
    public_id: Mapped[uuid.UUID] = public_id_column()

    course_unit_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("course_units.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    #: The student-facing phrase, in the words a student would say. Not a slug:
    #: it is rendered verbatim as a chip and becomes the request topic if tapped.
    label: Mapped[str] = mapped_column(String(120), nullable=False)

    #: The publisher's order, smallest first. Ties fall back to the label so a
    #: list is never different between two requests.
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    course_unit: Mapped[CourseUnit] = relationship(back_populates="topics")

    def __repr__(self) -> str:
        return f"<CourseUnitTopic {self.label}>"
