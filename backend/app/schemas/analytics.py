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


class PilotFunnelResponse(OrmSchema):
    """The four counts the pilot runbook tracks, as one read.

    The names carry the unit each count belongs to: a request is accepted when
    a tutor confirmed it, a session is completed when both parties finished,
    and a session is rated when its tutee submitted the mandatory feedback.
    Keeping the rating count direction-specific is what makes it evidence the
    quality loop closed, not just that some rating row exists.
    """

    requests_total: int = Field(ge=0)
    requests_accepted: int = Field(ge=0)
    sessions_completed: int = Field(ge=0)
    sessions_rated: int = Field(ge=0)
