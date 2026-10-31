"""add reg_no, tel, program_id, semester to users and year_level, semester to course_units

Revision ID: 338454f4d328
Revises: 7ee34bda22e0
Create Date: 2026-10-31 06:03:42.604953

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "338454f4d328"
down_revision: str | None = "7ee34bda22e0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("course_units", sa.Column("year_level", sa.Integer(), nullable=True))
    op.add_column("course_units", sa.Column("semester", sa.Integer(), nullable=True))
    op.add_column("users", sa.Column("reg_no", sa.String(length=64), nullable=True))
    op.add_column("users", sa.Column("tel", sa.String(length=32), nullable=True))
    op.add_column("users", sa.Column("program_id", sa.UUID(), nullable=True))
    op.add_column("users", sa.Column("semester", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_users_program_id_programs",
        "users",
        "programs",
        ["program_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index("ix_users_program_id", "users", ["program_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_users_program_id", table_name="users")
    op.drop_constraint("fk_users_program_id_programs", "users", type_="foreignkey")
    op.drop_column("users", "semester")
    op.drop_column("users", "program_id")
    op.drop_column("users", "tel")
    op.drop_column("users", "reg_no")
    op.drop_column("course_units", "semester")
    op.drop_column("course_units", "year_level")