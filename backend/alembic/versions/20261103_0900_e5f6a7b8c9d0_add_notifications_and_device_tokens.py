"""add notifications and device tokens

Revision ID: e5f6a7b8c9d0
Revises: d9e0f1a2b3c4

The beta needs an inbox before it needs a push provider. `notifications` is the
durable record a student reads in the app; `device_tokens` is the address a
notifier would later deliver to. Keeping them apart is what lets the inbox work
with Firebase unconfigured, which is the state the first APK ships in.

`notifications.dedupe_key` is unique per user, so a retried event or a reminder
job that runs twice leaves one row. Null is the normal case and is distinct from
null in both databases, so unkeyed notifications never collide.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "e5f6a7b8c9d0"
down_revision: str | None = "d9e0f1a2b3c4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "notifications",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("public_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column(
            "type",
            sa.Enum(
                "request_received",
                "request_accepted",
                "request_declined",
                "session_started",
                "session_completed",
                "session_cancelled",
                "rating_received",
                "promotion",
                name="notification_type",
                native_enum=False,
                create_constraint=True,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("body", sa.String(length=500), nullable=False),
        sa.Column("data", sa.JSON(), nullable=True),
        sa.Column("read_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("dedupe_key", sa.String(length=200), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_notifications_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_notifications")),
        sa.UniqueConstraint(
            "user_id", "dedupe_key", name="uq_notifications_user_dedupe"
        ),
    )
    op.create_index(
        op.f("ix_notifications_public_id"),
        "notifications",
        ["public_id"],
        unique=True,
    )
    op.create_index(op.f("ix_notifications_type"), "notifications", ["type"])
    op.create_index(
        "ix_notifications_user_read_created",
        "notifications",
        ["user_id", "read_at", "created_at"],
    )

    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("public_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column(
            "platform",
            sa.Enum(
                "android",
                "ios",
                "web",
                name="device_platform",
                native_enum=False,
                create_constraint=True,
                length=32,
            ),
            nullable=False,
        ),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "length(token) > 0", name=op.f("ck_device_tokens_device_token_not_blank")
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_device_tokens_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_device_tokens")),
        sa.UniqueConstraint("token", name=op.f("uq_device_tokens_token")),
    )
    op.create_index(
        op.f("ix_device_tokens_public_id"),
        "device_tokens",
        ["public_id"],
        unique=True,
    )
    op.create_index(op.f("ix_device_tokens_user_id"), "device_tokens", ["user_id"])


def downgrade() -> None:
    op.drop_index(op.f("ix_device_tokens_user_id"), table_name="device_tokens")
    op.drop_index(op.f("ix_device_tokens_public_id"), table_name="device_tokens")
    op.drop_table("device_tokens")
    op.drop_index(
        "ix_notifications_user_read_created", table_name="notifications"
    )
    op.drop_index(op.f("ix_notifications_type"), table_name="notifications")
    op.drop_index(op.f("ix_notifications_public_id"), table_name="notifications")
    op.drop_table("notifications")
