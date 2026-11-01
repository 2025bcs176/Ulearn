"""prevent duplicate unresolved reports per reporter and session.

Revision ID: f7a8b9c0d1e2
Revises: c6d7e8f9a0b1
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "f7a8b9c0d1e2"
down_revision: str | None = "c6d7e8f9a0b1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "uq_session_reports_open_reporter",
        "session_reports",
        ["session_id", "reporter_id"],
        unique=True,
        postgresql_where=sa.text("status <> 'resolved'"),
        sqlite_where=sa.text("status <> 'resolved'"),
    )


def downgrade() -> None:
    op.drop_index("uq_session_reports_open_reporter", table_name="session_reports")
