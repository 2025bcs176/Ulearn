"""add session venue fields

Revision ID: f2a3b4c5d6e7
Revises: e1f2a3b4c5d6
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "f2a3b4c5d6e7"
down_revision: str | None = "e1f2a3b4c5d6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("sessions", sa.Column("meeting_venue", sa.String(length=160)))
    op.add_column(
        "sessions",
        sa.Column("meeting_venue_detail", sa.String(length=160)),
    )


def downgrade() -> None:
    op.drop_column("sessions", "meeting_venue_detail")
    op.drop_column("sessions", "meeting_venue")
