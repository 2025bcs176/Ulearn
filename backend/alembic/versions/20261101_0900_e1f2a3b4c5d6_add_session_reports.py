"""add safeguarding reports.

Revision ID: e1f2a3b4c5d6
Revises: d0e1f2a3b4c5
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "e1f2a3b4c5d6"
down_revision: str | None = "d0e1f2a3b4c5"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "session_reports",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("public_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("reporter_id", sa.Uuid(), nullable=False),
        sa.Column(
            "category",
            sa.Enum(
                "safety",
                "harassment",
                "fraud",
                "venue",
                "other",
                name="report_category",
                native_enum=False,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "status",
            sa.Enum(
                "open",
                "reviewing",
                "resolved",
                name="report_status",
                native_enum=False,
                length=32,
            ),
            nullable=False,
            server_default="open",
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["reporter_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id"], ["sessions.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_session_reports_session_id", "session_reports", ["session_id"])
    op.create_index("ix_session_reports_reporter_id", "session_reports", ["reporter_id"])
    op.create_index("ix_session_reports_status", "session_reports", ["status"])


def downgrade() -> None:
    op.drop_index("ix_session_reports_status", table_name="session_reports")
    op.drop_index("ix_session_reports_reporter_id", table_name="session_reports")
    op.drop_index("ix_session_reports_session_id", table_name="session_reports")
    op.drop_table("session_reports")
