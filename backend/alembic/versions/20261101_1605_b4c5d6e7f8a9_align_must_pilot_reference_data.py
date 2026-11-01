"""align stale pilot reference-data labels with MUST.

Revision ID: b4c5d6e7f8a9
Revises: f7a8b9c0d1e2
"""

from collections.abc import Sequence

from alembic import op

revision: str = "b4c5d6e7f8a9"
down_revision: str | None = "f7a8b9c0d1e2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # Older pilot databases could contain the temporary Makerere reference row.
    # Reuse its identity so profiles and course units remain attached to it.
    op.execute(
        """
        UPDATE universities
        SET name = 'Mbarara University of Science and Technology'
        WHERE name = 'Makerere University'
          AND NOT EXISTS (
              SELECT 1
              FROM universities
              WHERE name = 'Mbarara University of Science and Technology'
          )
        """
    )
    op.execute(
        """
        UPDATE subjects
        SET name = 'Faculty of Computing and Informatics'
        WHERE name = 'Faculty of Computing and Informatics Sciences'
          AND university_id = (
              SELECT id
              FROM universities
              WHERE name = 'Mbarara University of Science and Technology'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM subjects AS current_subject
              WHERE current_subject.name = 'Faculty of Computing and Informatics'
                AND current_subject.university_id = subjects.university_id
          )
        """
    )


def downgrade() -> None:
    op.execute(
        """
        UPDATE subjects
        SET name = 'Faculty of Computing and Informatics Sciences'
        WHERE name = 'Faculty of Computing and Informatics'
          AND university_id = (
              SELECT id
              FROM universities
              WHERE name = 'Mbarara University of Science and Technology'
          )
          AND NOT EXISTS (
              SELECT 1
              FROM subjects AS legacy_subject
              WHERE legacy_subject.name =
                  'Faculty of Computing and Informatics Sciences'
                AND legacy_subject.university_id = subjects.university_id
          )
        """
    )
    op.execute(
        """
        UPDATE universities
        SET name = 'Makerere University'
        WHERE name = 'Mbarara University of Science and Technology'
          AND NOT EXISTS (
              SELECT 1
              FROM universities
              WHERE name = 'Makerere University'
          )
        """
    )
