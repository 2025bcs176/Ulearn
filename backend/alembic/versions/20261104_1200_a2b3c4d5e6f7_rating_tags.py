"""rating tags

Revision ID: a2b3c4d5e6f7
Revises: f1a2b3c4d5e6

A rating used to be a score and a note. The score says how good the session was
and the note is written to the tutor; neither tells the next student what the
session was *like*, and the note stays between the two people who were there.
These six tags are the public vocabulary the profile can show.

The column is a JSON array rather than a table because a tag has no attributes
and is never read without the rating it belongs to. The array is not checked
against the vocabulary by the database -- `json` on SQLite cannot express
membership, and the migration has to be buildable on both backends -- so
`RatingCreate` enforces it at the edge. Every row that exists before this
revision gets an empty array, which is the honest value: those raters were never
offered the choice.
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "a2b3c4d5e6f7"
down_revision: str | None = "f1a2b3c4d5e6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Added nullable, filled, then made required. A server default would let the
    # column be omitted on insert, but it is also the one thing `alembic check`
    # cannot compare on PostgreSQL for a JSON column (`'[]'::json = '[]'` has no
    # equality operator), so the default would turn every future migration check
    # into a false drift report. The application supplies the value; the database
    # only insists that one exists.
    op.add_column("ratings", sa.Column("tags", sa.JSON(), nullable=True))
    op.execute("UPDATE ratings SET tags = '[]' WHERE tags IS NULL")
    op.alter_column("ratings", "tags", nullable=False)


def downgrade() -> None:
    op.drop_column("ratings", "tags")
