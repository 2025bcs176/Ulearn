"""add safeguarding report public id index.

Revision ID: a7b8c9d0e1f2
Revises: f2a3b4c5d6e7
"""

from collections.abc import Sequence

from alembic import op

revision: str = "a7b8c9d0e1f2"
down_revision: str | None = "f2a3b4c5d6e7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_index(
        "ix_session_reports_public_id",
        "session_reports",
        ["public_id"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_session_reports_public_id", table_name="session_reports")
