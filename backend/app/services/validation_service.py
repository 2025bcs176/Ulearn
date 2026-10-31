"""Tutor validation and competency verification business logic."""

import uuid
from decimal import Decimal

from fastapi import UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.exceptions import NotFoundProblem, ValidationProblem
from app.models.competency import Competency
from app.models.course_unit import CourseUnit, University
from app.models.enums import CompetencyStatus
from app.models.grading_scale import Grade
from app.models.user import User
from app.schemas.competency import CompetencyCreate, CompetencyResponse
from app.services import faculty_scope

#: Everything `_competency_response` reads, in one place.
#:
#: The response builder is a plain function, so it cannot await a lazy load. When
#: a query omitted one of these the request failed with `MissingGreenlet` while
#: building its own response -- and under the suite's shared-session fixture it
#: did not fail at all, because the identity map already held the rows from an
#: earlier call in the same test. Declaring the set once means a new query cannot
#: quietly forget part of it.
_COMPETENCY_LOAD = (
    selectinload(Competency.user),
    selectinload(Competency.grade),
    selectinload(Competency.course_unit)
    .selectinload(CourseUnit.university)
    .selectinload(University.grading_scale),
)


async def list_competencies(db: AsyncSession, user: User) -> list[CompetencyResponse]:
    """Every competency this user has submitted."""
    result = await db.execute(
        select(Competency)
        .where(Competency.user_id == user.id)
        .options(*_COMPETENCY_LOAD)
        .order_by(Competency.created_at.desc())
    )
    return [_competency_response(row) for row in result.scalars()]


async def get_competency(
    db: AsyncSession, user: User, competency_id: uuid.UUID
) -> CompetencyResponse:
    """One competency, when the caller owns it."""
    return _competency_response(await _load_competency(db, user, competency_id))


async def _load_competency(
    db: AsyncSession, user: User, competency_id: uuid.UUID
) -> Competency:
    """One competency the caller owns, loaded for the response builder.

    The filter is on `public_id` because that is the only id a client is ever
    given. Filtering on the internal primary key made this route unreachable:
    every request carried a public UUID, matched nothing, and returned 404.
    """
    result = await db.execute(
        select(Competency)
        .where(Competency.public_id == competency_id, Competency.user_id == user.id)
        .options(*_COMPETENCY_LOAD)
    )
    competency = result.scalar_one_or_none()
    if competency is None:
        raise NotFoundProblem("That competency record could not be found.")
    return competency


async def create_competency(
    db: AsyncSession,
    user: User,
    payload: CompetencyCreate,
) -> CompetencyResponse:
    """Submit a tutor's grade proof for a single course unit."""
    if user.academic_data_consented_at is None:
        raise ValidationProblem(
            "Academic-data consent is required before submitting transcript proof.",
            errors={"academic_data_consented": "consent is required"},
        )

    if user.university_id is None:
        raise ValidationProblem(
            "Choose your university before submitting tutor verification.",
            errors={"university_id": "university is required"},
        )

    course_unit = await _load_course_unit(db, payload.course_unit_id)
    faculty_scope.require_own_university(course_unit, user)
    # The other half of the verification gate. A tutor is verified for the units
    # they teach, and they teach their own faculty's; without this a Computing
    # student could be verified against a Medicine unit and then appear in a rail
    # that is scoped away from every Medicine student.
    faculty_scope.require_own_faculty(course_unit, user)

    # A tutor may only claim units they have actually completed: a YR2 student
    # cannot tutor a YR4 unit. When either side is unknown we let it through and
    # leave the decision to the reviewer, so onboarding gaps do not hard-block.
    if (
        user.year_of_study is not None
        and course_unit.year_level is not None
        and user.year_of_study < course_unit.year_level
    ):
        raise ValidationProblem(
            "You have not yet completed this course unit.",
            errors={"course_unit_id": "unit not yet completed"},
        )

    grade = await _load_grade(db, payload.grade_id)
    if course_unit.university.grading_scale_id is None:
        raise ValidationProblem(
            "This university has not published a grading scale yet.",
            errors={"university_id": "grading scale is missing"},
        )
    if grade.grading_scale_id != course_unit.university.grading_scale_id:
        raise ValidationProblem(
            "That grade does not belong to the unit's university scale.",
            errors={"grade_id": "must match the unit's grading scale"},
        )

    existing = await db.scalar(
        select(Competency).where(
            Competency.user_id == user.id,
            Competency.course_unit_id == course_unit.id,
        )
    )
    if existing is not None:
        # A rejected proof is the one state a tutor may answer. The reviewer
        # rejected it with a reason the runbook requires to be actionable, and
        # the only way to act on that is to submit again for the same unit. The
        # earlier guard matched on `(user_id, course_unit_id)` alone, so a
        # rejection was a permanent dead end: the tutor read the reason and
        # could do nothing about it, for that unit, ever.
        #
        # `pending` and `verified` stay closed. A pending proof is already with
        # a reviewer, and letting a second one through would leave an operator
        # deciding between two live claims for one unit. A verified one is the
        # basis of a matching record; replacing it is a different question, and
        # not one a submission form should answer.
        if existing.status is not CompetencyStatus.REJECTED:
            raise ValidationProblem(
                "A competency already exists for this unit.",
                errors={"course_unit_id": "duplicate competency"},
            )
        # Reopening the row keeps the reviewer history on the same record, so
        # `reviewed_by_id` and `verified_at` are cleared rather than the old
        # decision silently describing a claim that no longer exists.
        existing.grade_id = grade.id
        existing.status = CompetencyStatus.PENDING
        existing.source = payload.source
        existing.evidence_reference = payload.evidence_reference
        existing.notes = payload.notes
        existing.verified_at = None
        existing.rejection_reason = None
        existing.reviewed_by_id = None
        await db.flush()
        await db.commit()
        return _competency_response(
            await _load_competency(db, user, existing.public_id)
        )

    competency = Competency(
        user_id=user.id,
        course_unit_id=course_unit.id,
        grade_id=grade.id,
        status=CompetencyStatus.PENDING,
        source=payload.source,
        evidence_reference=payload.evidence_reference,
        notes=payload.notes,
    )
    db.add(competency)
    await db.flush()
    await db.flush()
    await db.commit()
    # Re-read rather than building the response off the flushed instance: the
    # relationships `_competency_response` walks are not populated on a row that
    # has only just been inserted, and the builder is synchronous.
    return _competency_response(await _load_competency(db, user, competency.public_id))


async def upload_evidence(
    db: AsyncSession,
    user: User,
    competency_id: uuid.UUID,
    upload: UploadFile,
) -> CompetencyResponse:
    """Upload a transcript/QR file and verify it against the claimed unit/grade.

    When the competency's source is 'transcript', the file is parsed for a MUST
    QR stamp, the selected course unit code and the claimed grade. A valid
    transcript with a qualifying grade (A or B+) verifies the tutor on the spot;
    any mismatch rejects the claim with a reason. Claims without a transcript
    stay pending for manual (Dean) review.
    """
    competency = await _load_competency(db, user, competency_id)
    from datetime import UTC, datetime

    from app.services import storage_service, transcript_parser

    object_key = (
        f"transcripts/{user.public_id}/{competency.public_id}/{upload.filename}"
    )
    object_key = storage_service.upload_transcript(upload, object_key)
    competency.evidence_reference = object_key
    await db.flush()

    source_val = getattr(competency.source, "value", str(competency.source))
    if source_val == "transcript":
        upload.file.seek(0)
        content = await upload.read()
        parsed = transcript_parser.parse_transcript(
            content, upload.content_type or "", upload.filename or "transcript"
        )
        rejection: str | None = None
        if not parsed.qr_valid:
            rejection = "Transcript QR code is not a valid MUST stamp."
        elif competency.course_unit.code not in parsed.course_codes:
            rejection = (
                f"Transcript does not list the selected course unit "
                f"({competency.course_unit.code})."
            )
        elif competency.grade.label not in parsed.grades:
            rejection = (
                f"Claimed grade {competency.grade.label} does not match the transcript."
            )
        else:
            scale = competency.course_unit.university.grading_scale
            minimum = scale.competency_min_points if scale else None
            if minimum is not None and competency.grade.grade_points < minimum:
                rejection = (
                    f"Grade {competency.grade.label} is below the competency "
                    f"threshold (requires B+ or higher)."
                )

        if rejection is not None:
            competency.status = CompetencyStatus.REJECTED
            competency.rejection_reason = rejection
            competency.verified_at = None
            competency.reviewed_by_id = None
        else:
            competency.status = CompetencyStatus.VERIFIED
            competency.verified_at = datetime.now(UTC)
            competency.rejection_reason = None
            from sqlalchemy import select

            from app.models.enums import UserRole
            from app.models.tutor_profile import TutorProfile
            from app.models.user import load_roles, set_roles

            roles = set(await load_roles(db, user.id))
            roles.add(UserRole.TUTOR)
            await set_roles(db, user.id, roles)
            profile = await db.scalar(
                select(TutorProfile).where(TutorProfile.user_id == user.id)
            )
            if profile is None:
                db.add(TutorProfile(user_id=user.id))

    await db.flush()
    await db.commit()
    return _competency_response(await _load_competency(db, user, competency.public_id))


async def download_evidence(
    db: AsyncSession,
    user: User,
    competency_id: uuid.UUID,
) -> tuple[bytes, str]:
    """Return the bytes and content type of a competency's stored evidence."""
    competency = await _load_competency(db, user, competency_id)
    if not competency.evidence_reference:
        raise NotFoundProblem("No evidence has been uploaded for this competency.")
    from app.services import storage_service

    return storage_service.download_transcript(competency.evidence_reference)


async def _load_course_unit(db: AsyncSession, public_id: uuid.UUID) -> CourseUnit:
    result = await db.execute(
        select(CourseUnit)
        .where(CourseUnit.public_id == public_id)
        .options(
            selectinload(CourseUnit.university).selectinload(University.grading_scale)
        )
    )
    course_unit = result.scalar_one_or_none()
    if course_unit is None:
        raise NotFoundProblem("That course unit could not be found.")
    return course_unit


async def _load_grade(db: AsyncSession, public_id: uuid.UUID) -> Grade:
    result = await db.execute(select(Grade).where(Grade.public_id == public_id))
    grade = result.scalar_one_or_none()
    if grade is None:
        raise NotFoundProblem("That grade could not be found.")
    return grade


def _competency_response(competency: Competency) -> CompetencyResponse:
    scale = competency.course_unit.university.grading_scale
    minimum_points = scale.competency_min_points if scale is not None else Decimal("0")
    return CompetencyResponse.model_validate(
        {
            "id": competency.public_id,
            "user_id": competency.user_public_id,
            "course_unit_id": competency.course_unit_public_id,
            "course_unit_code": competency.course_unit.code,
            "course_unit_name": competency.course_unit.name,
            "grade_id": competency.grade_public_id,
            "grade_label": competency.grade.label,
            "status": competency.status,
            "source": competency.source,
            "grade_points": competency.grade.grade_points,
            "meets_threshold": (
                competency.status is CompetencyStatus.VERIFIED
                and competency.grade.grade_points >= minimum_points
            ),
            "verified_at": competency.verified_at,
            "rejection_reason": competency.rejection_reason,
            "evidence_reference": competency.evidence_reference,
            "created_at": competency.created_at,
        }
    )
