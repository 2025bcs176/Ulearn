"""Safeguarding reports raised against a tutoring session."""

import uuid
from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, Index, Text, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.core.security import new_uuid7
from app.models.base import TimestampMixin, enum_column, public_id_column
from app.models.enums import ReportCategory, ReportStatus

if TYPE_CHECKING:
    from app.models.session import Session
    from app.models.user import User


class SessionReport(Base, TimestampMixin):
    __tablename__ = "session_reports"
    __table_args__ = (
        Index(
            "uq_session_reports_open_reporter",
            "session_id",
            "reporter_id",
            unique=True,
            postgresql_where=text("status <> 'resolved'"),
            sqlite_where=text("status <> 'resolved'"),
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=new_uuid7)
    public_id: Mapped[uuid.UUID] = public_id_column()
    session_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, index=True
    )
    reporter_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    category: Mapped[ReportCategory] = mapped_column(
        enum_column(ReportCategory, name="report_category"), nullable=False
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[ReportStatus] = mapped_column(
        enum_column(ReportStatus, name="report_status"),
        nullable=False,
        default=ReportStatus.OPEN,
        server_default=ReportStatus.OPEN.value,
        index=True,
    )

    session: Mapped[Session] = relationship()
    reporter: Mapped[User] = relationship()

    @property
    def session_public_id(self) -> uuid.UUID:
        return self.session.public_id

    @property
    def reporter_public_id(self) -> uuid.UUID:
        return self.reporter.public_id
