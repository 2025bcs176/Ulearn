"""harden session handshakes.

Revision ID: c9d4e5f6a7b8
Revises: 7ee34bda22e0
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "c9d4e5f6a7b8"
down_revision: str | None = "7ee34bda22e0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("sessions", sa.Column("session_pin_hash", sa.String(64)))
    op.add_column(
        "sessions",
        sa.Column("session_pin_expires_at", sa.DateTime(timezone=True)),
    )
    op.add_column("sessions", sa.Column("completion_pin_hash", sa.String(64)))
    op.add_column(
        "sessions",
        sa.Column("completion_pin_expires_at", sa.DateTime(timezone=True)),
    )
    op.add_column(
        "sessions",
        sa.Column("completion_requested_at", sa.DateTime(timezone=True)),
    )
    op.add_column(
        "sessions",
        sa.Column(
            "completion_pin_failed_attempts",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "sessions",
        sa.Column("completion_pin_locked_until", sa.DateTime(timezone=True)),
    )
    op.drop_column("sessions", "session_pin")


def downgrade() -> None:
    op.add_column("sessions", sa.Column("session_pin", sa.String(2)))
    op.create_check_constraint(
        op.f("ck_sessions_session_pin_length"),
        "sessions",
        "session_pin IS NULL OR length(session_pin) = 2",
    )
    op.drop_column("sessions", "completion_pin_locked_until")
    op.drop_column("sessions", "completion_pin_failed_attempts")
    op.drop_column("sessions", "completion_requested_at")
    op.drop_column("sessions", "completion_pin_expires_at")
    op.drop_column("sessions", "completion_pin_hash")
    op.drop_column("sessions", "session_pin_expires_at")
    op.drop_column("sessions", "session_pin_hash")
