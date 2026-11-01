import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import AuthorizationProblem, ConflictProblem, NotFoundProblem
from app.models.report import SessionReport
from app.models.session import Session
from app.models.user import User
from app.schemas.report import ReportCreate, ReportResponse


async def create_report(
    db: AsyncSession, user: User, session_id: uuid.UUID, payload: ReportCreate
) -> ReportResponse:
    result = await db.execute(
        select(Session)
        .where(Session.public_id == session_id)
        .options(selectinload(Session.tutee), selectinload(Session.tutor))
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise NotFoundProblem("That session could not be found.")
    if user.id not in {session.tutee_id, session.tutor_id}:
        raise AuthorizationProblem("You do not have access to that session.")

    existing = await db.scalar(
        select(SessionReport.id).where(
            SessionReport.session_id == session.id,
            SessionReport.reporter_id == user.id,
            SessionReport.status != "resolved",
        )
    )
    if existing is not None:
        raise ConflictProblem("You already have an open report for this session.")

    report = SessionReport(
        session_id=session.id,
        reporter_id=user.id,
        category=payload.category,
        description=payload.description,
    )
    db.add(report)
    try:
        await db.commit()
    except IntegrityError as error:
        await db.rollback()
        if "uq_session_reports_open_reporter" not in str(error.orig):
            raise
        raise ConflictProblem(
            "You already have an open report for this session."
        ) from error
    result = await db.execute(
        select(SessionReport)
        .where(SessionReport.id == report.id)
        .options(
            selectinload(SessionReport.session),
            selectinload(SessionReport.reporter),
        )
    )
    return ReportResponse.model_validate(result.scalar_one())
