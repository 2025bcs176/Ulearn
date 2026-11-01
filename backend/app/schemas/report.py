import uuid
from datetime import datetime

from pydantic import Field

from app.models.enums import ReportCategory, ReportStatus
from app.schemas.base import OrmSchema, RequestSchema, Trimmed


class ReportCreate(RequestSchema):
    category: ReportCategory
    description: Trimmed | None = Field(default=None, max_length=2000)


class ReportResponse(OrmSchema):
    id: uuid.UUID = Field(validation_alias="public_id")
    session_id: uuid.UUID = Field(validation_alias="session_public_id")
    reporter_id: uuid.UUID = Field(validation_alias="reporter_public_id")
    category: ReportCategory
    description: str | None = None
    status: ReportStatus
    created_at: datetime
