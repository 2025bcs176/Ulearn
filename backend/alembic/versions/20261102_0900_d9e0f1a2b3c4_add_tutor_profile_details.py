"""add tutor bio, avatar, contact phone, and request pause

Revision ID: d9e0f1a2b3c4
Revises: b4c5d6e7f8a9

The beta needs a tutor card that reads like a person rather than a grade
report, and a tutor needs a way to say they are too busy to teach.

`accepting_requests` defaults to true so every existing tutor keeps behaving
exactly as they did: the pilot cohort was approved to take requests, and a
migration that silently paused them would be a product decision made by a
column default. `contact_phone` is nullable and empty for the seeded cohort,
which is why the contact endpoint that will read it does not exist yet --
there is nothing to hand out.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "d9e0f1a2b3c4"
down_revision: str | None = "b4c5d6e7f8a9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "tutor_profiles",
        sa.Column("bio", sa.String(length=280), nullable=True),
    )
    op.add_column(
        "tutor_profiles",
        sa.Column("avatar_url", sa.String(length=500), nullable=True),
    )
    op.add_column(
        "tutor_profiles",
        sa.Column("contact_phone", sa.String(length=32), nullable=True),
    )
    op.add_column(
        "tutor_profiles",
        sa.Column(
            "accepting_requests",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )


def downgrade() -> None:
    op.drop_column("tutor_profiles", "accepting_requests")
    op.drop_column("tutor_profiles", "contact_phone")
    op.drop_column("tutor_profiles", "avatar_url")
    op.drop_column("tutor_profiles", "bio")
