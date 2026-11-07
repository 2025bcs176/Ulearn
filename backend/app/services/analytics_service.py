from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.course_unit import CourseUnit
from app.models.enums import HelpRequestStatus, SessionStatus
from app.models.rating import Rating
from app.models.session import HelpRequest, Session
from app.schemas.analytics import (
    PilotFunnelResponse,
    TopicHeatmapEntry,
    TopicHeatmapResponse,
)

MINIMUM_COHORT_SIZE = 5


async def topic_heatmap(db: AsyncSession) -> TopicHeatmapResponse:
    """Return only aggregates large enough to reduce re-identification risk."""
    result = await db.execute(
        select(
            CourseUnit.code,
            CourseUnit.name,
            HelpRequest.topic,
            func.count(HelpRequest.id),
        )
        .join(CourseUnit, CourseUnit.id == HelpRequest.course_unit_id)
        .group_by(CourseUnit.code, CourseUnit.name, HelpRequest.topic)
        .having(func.count(HelpRequest.id) >= MINIMUM_COHORT_SIZE)
        .having(func.count(func.distinct(HelpRequest.tutee_id)) >= MINIMUM_COHORT_SIZE)
        .order_by(func.count(HelpRequest.id).desc(), HelpRequest.topic.asc())
    )
    return TopicHeatmapResponse(
        entries=[
            TopicHeatmapEntry(
                course_unit_code=code,
                course_unit_name=name,
                topic=topic,
                request_count=count,
            )
            for code, name, topic, count in result.all()
        ]
    )


async def pilot_funnel(db: AsyncSession) -> PilotFunnelResponse:
    """Return the pilot's four launch counts without identifying anyone.

    Each count is a separate aggregate rather than a stage derived by
    subtraction: a request can be accepted and its session cancelled, so
    "accepted minus completed" is not the number of sessions still open. The
    runbook asks for four numbers, and this answers exactly those.
    """
    requests_total = (
        await db.scalar(select(func.count()).select_from(HelpRequest))
    ) or 0
    requests_accepted = (
        await db.scalar(
            select(func.count())
            .select_from(HelpRequest)
            .where(HelpRequest.status == HelpRequestStatus.MATCHED)
        )
    ) or 0
    sessions_completed = (
        await db.scalar(
            select(func.count())
            .select_from(Session)
            .where(Session.status == SessionStatus.COMPLETED)
        )
    ) or 0
    # Ratings are the tutee's mandatory feedback on the tutor. Only the tutee
    # can submit one today, and the direction is still part of the predicate:
    # a future tutor-facing rating must not silently count the loop as closed.
    sessions_rated = (
        await db.scalar(
            select(func.count())
            .select_from(Rating)
            .join(Session, Session.id == Rating.session_id)
            .where(
                Rating.rater_id == Session.tutee_id,
                Session.status == SessionStatus.COMPLETED,
            )
        )
    ) or 0
    return PilotFunnelResponse(
        requests_total=requests_total,
        requests_accepted=requests_accepted,
        sessions_completed=sessions_completed,
        sessions_rated=sessions_rated,
    )
