"""course unit topics

Revision ID: b3c4d5e6f7a8
Revises: a2b3c4d5e6f7

A student asking for help often cannot name the concept they are stuck on, and a
course unit is too broad to type into one box. These are the unit's own
suggestions, shown as chips on the request sheet and sent as ordinary free-text
topics if tapped.

Reference data beside the units they belong to. A topic leaves when its unit
does, and the table carries no user foreign key because no student writes here.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "b3c4d5e6f7a8"
down_revision: str | None = "a2b3c4d5e6f7"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "course_unit_topics",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("public_id", sa.Uuid(), nullable=False),
        sa.Column("course_unit_id", sa.Uuid(), nullable=False),
        sa.Column("label", sa.String(length=120), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["course_unit_id"],
            ["course_units.id"],
            name=op.f("fk_course_unit_topics_course_unit_id_course_units"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_course_unit_topics")),
        sa.UniqueConstraint(
            "course_unit_id", "label", name="topic_label_per_course_unit"
        ),
    )
    op.create_index(
        op.f("ix_course_unit_topics_course_unit_id"),
        "course_unit_topics",
        ["course_unit_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_course_unit_topics_public_id"),
        "course_unit_topics",
        ["public_id"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_course_unit_topics_public_id"),
        table_name="course_unit_topics",
    )
    op.drop_index(
        op.f("ix_course_unit_topics_course_unit_id"),
        table_name="course_unit_topics",
    )
    op.drop_table("course_unit_topics")
