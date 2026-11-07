"""mutual check-in for session attendance

Revision ID: f1a2b3c4d5e6
Revises: e5f6a7b8c9d0

Attendance used to be proved by two six-digit codes: the tutor revealed a start
PIN and the tutee read a completion PIN back. A code proves that two people were
in the same room, but it also means one of them can read it to the other and the
server still accepts a session only one person attended.

Two independent timestamps from two accounts prove the same thing without a
secret to share. Each party records their own arrival and their own departure;
the session goes live when both have arrived and completes when both have left.
The PIN columns and their throttle counters are dropped rather than left
unused, because a nullable column that no code writes is a trap for the next
contributor.

The migration is reversible. The downgrade restores the PIN shape empty, which
is the honest state: the evidence those columns would hold was never collected
for rows created under the new scheme, and inventing it would be worse.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "f1a2b3c4d5e6"
down_revision: str | None = "e5f6a7b8c9d0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

#: Columns that represented the PIN handshake. Dropped as a group so no partial
#: upgrade can leave a session with half a handshake.
_PIN_COLUMNS = (
    "session_pin_hash",
    "session_pin_expires_at",
    "completion_pin_hash",
    "completion_pin_expires_at",
    "completion_requested_at",
    "pin_failed_attempts",
    "pin_locked_until",
    "completion_pin_failed_attempts",
    "completion_pin_locked_until",
)


def upgrade() -> None:
    op.add_column(
        "sessions",
        sa.Column("tutor_checked_in_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "sessions",
        sa.Column("tutee_checked_in_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "sessions",
        sa.Column("tutor_finished_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "sessions",
        sa.Column("tutee_finished_at", sa.DateTime(timezone=True), nullable=True),
    )

    # Existing rows predate the new evidence. Backfilling from the timestamps
    # they do have is the only defensible reconstruction, and it lets the new
    # constraints be added without a table rewrite that rejects every live row.
    # `started_at` is already present on anything past `scheduled`.
    op.execute(
        sa.text(
            "UPDATE sessions "
            "SET tutor_checked_in_at = COALESCE(started_at, created_at), "
            "    tutee_checked_in_at = COALESCE(started_at, created_at) "
            "WHERE status IN ('in_progress', 'completed') "
            "  AND (tutor_checked_in_at IS NULL OR tutee_checked_in_at IS NULL)"
        )
    )
    op.execute(
        sa.text(
            "UPDATE sessions "
            "SET tutor_finished_at = COALESCE(ended_at, updated_at), "
            "    tutee_finished_at = COALESCE(ended_at, updated_at) "
            "WHERE status = 'completed' "
            "  AND (tutor_finished_at IS NULL OR tutee_finished_at IS NULL)"
        )
    )

    op.create_check_constraint(
        "live_session_has_both_check_ins",
        "sessions",
        "status <> 'in_progress' "
        "OR (tutor_checked_in_at IS NOT NULL AND tutee_checked_in_at IS NOT NULL)",
    )
    op.create_check_constraint(
        "completed_session_has_both_finishes",
        "sessions",
        "status <> 'completed' "
        "OR (tutor_finished_at IS NOT NULL AND tutee_finished_at IS NOT NULL)",
    )

    op.drop_constraint(
        op.f("ck_sessions_pin_failed_attempts_not_negative"),
        "sessions",
        type_="check",
    )
    for column in _PIN_COLUMNS:
        op.drop_column("sessions", column)


def downgrade() -> None:
    op.drop_constraint(
        op.f("ck_sessions_completed_session_has_both_finishes"),
        "sessions",
        type_="check",
    )
    op.drop_constraint(
        op.f("ck_sessions_live_session_has_both_check_ins"),
        "sessions",
        type_="check",
    )

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
            "pin_failed_attempts",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    op.add_column(
        "sessions",
        sa.Column("pin_locked_until", sa.DateTime(timezone=True)),
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
    op.create_check_constraint(
        "pin_failed_attempts_not_negative",
        "sessions",
        "pin_failed_attempts >= 0",
    )

    for column in (
        "tutor_checked_in_at",
        "tutee_checked_in_at",
        "tutor_finished_at",
        "tutee_finished_at",
    ):
        op.drop_column("sessions", column)
