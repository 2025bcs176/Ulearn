from pydantic import Field

from app.schemas.base import OrmSchema


class TopicHeatmapEntry(OrmSchema):
    course_unit_code: str
    course_unit_name: str
    topic: str
    request_count: int = Field(ge=5)


class TopicHeatmapResponse(OrmSchema):
    minimum_cohort_size: int = Field(default=5, ge=5)
    entries: list[TopicHeatmapEntry] = Field(default_factory=list)
    ca_metrics_available: bool = False
