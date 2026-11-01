from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.course_unit import CourseUnit
from app.models.session import HelpRequest
from app.schemas.analytics import TopicHeatmapEntry, TopicHeatmapResponse

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
        .having(
            func.count(func.distinct(HelpRequest.tutee_id)) >= MINIMUM_COHORT_SIZE
        )
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
