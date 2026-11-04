"""Mutual check-in: two arrivals start a session, two departures close it.

The old lifecycle proved attendance with two six-digit PINs. These tests pin the
replacement: each party records their own arrival, the session goes live only
when both are present, and it completes only when both have left. The
interesting cases are the ones a single-sided design would pass by accident --
one check-in starting a session, one finish banking hours, and a party who
leaves early extending the session for the person who stayed.
"""

from datetime import UTC, datetime, timedelta
from decimal import Decimal

import pytest
from sqlalchemy import select, update

from app.core.exceptions import (
    AuthorizationProblem,
    ConflictProblem,
    ValidationProblem,
)
from app.models.competency import Competency
from app.models.course_unit import CourseUnit, Subject, University
from app.models.enums import (
    CompetencyStatus,
    HelpRequestStatus,
    NotificationType,
    SessionStatus,
    TutorStanding,
    UserRole,
    VerificationSource,
)
from app.models.grading_scale import Grade, GradingScale
from app.models.notification import Notification
from app.models.session import HelpRequest, Session
from app.models.tutor_profile import TutorProfile
from app.models.user import User, set_roles
from app.schemas.session import (
    HelpRequestCreate,
    SessionCreate,
    SessionTransitionRequest,
)
from app.services import matching_service, session_service


def _instant(value: datetime) -> datetime:
    """Compare instants, not representations.

    SQLite drops the timezone from a `DateTime(timezone=True)` column, so a row
    just written is aware while the same row read back is naive. Both describe
    the same instant, which is what an idempotency assertion is about.
    """
    return value if value.tzinfo is not None else value.replace(tzinfo=UTC)


async def _seed_session_data(db_session):
    scale = GradingScale(
        name="Makerere 5-point",
        max_points=Decimal("5.00"),
        competency_min_points=Decimal("4.00"),
    )
    university = University(name="Makerere University", grading_scale=scale)
    subject = Subject(name="Computer Science")
    grade = Grade(
        label="A",
        grade_points=Decimal("4.50"),
        max_points=Decimal("5.00"),
        grading_scale=scale,
    )
    course_unit = CourseUnit(
        code="CSC 121",
        name="Algorithms",
        subject=subject,
        university=university,
        grade=grade,
    )
    student = User(
        email="student@mak.ac.ug",
        password_hash="hashed-password",
        full_name="Student Example",
        university=university,
        faculty=subject,
    )
    tutor = User(
        email="tutor@mak.ac.ug",
        password_hash="hashed-password",
        full_name="Tutor Example",
        university=university,
        faculty=subject,
    )
    stranger = User(
        email="stranger@mak.ac.ug",
        password_hash="hashed-password",
        full_name="Stranger Example",
        university=university,
        faculty=subject,
    )
    tutor_profile = TutorProfile(
        user=tutor,
        standing=TutorStanding.VERIFIED,
        completed_sessions=12,
        rating_total=Decimal("42.00"),
        rating_count=10,
    )
    competency = Competency(
        user=tutor,
        course_unit=course_unit,
        grade=grade,
        status=CompetencyStatus.VERIFIED,
        source=VerificationSource.TRANSCRIPT,
    )
    db_session.add_all(
        [
            scale,
            university,
            subject,
            grade,
            course_unit,
            student,
            tutor,
            stranger,
            tutor_profile,
            competency,
        ]
    )
    await db_session.flush()
    await set_roles(db_session, tutor.id, {UserRole.TUTOR})
    await db_session.commit()
    return student, tutor, stranger, course_unit


async def _scheduled_session(
    db_session, student, tutor, course_unit, topic="hash tables"
):
    """A session in the state `create_session` leaves it: scheduled, nobody here."""
    request = await matching_service.create_help_request(
        db_session,
        student,
        HelpRequestCreate(course_unit_id=course_unit.public_id, topic=topic),
    )
    help_request = await db_session.scalar(
        select(HelpRequest).where(HelpRequest.public_id == request.id)
    )
    assert help_request is not None
    help_request.matched_tutor_id = tutor.id
    # `PENDING_CONFIRMATION` is the state a chosen request is actually in; the
    # confirmation that moves it to `MATCHED` is asserted in
    # `test_help_request_selection.py`.
    help_request.status = HelpRequestStatus.PENDING_CONFIRMATION
    await db_session.commit()

    return await session_service.create_session(
        db_session,
        tutor,
        SessionCreate(
            help_request_id=request.id,
            course_unit_id=course_unit.public_id,
            topic=topic,
            duration_minutes=60,
        ),
    )


async def _check_in_both(db_session, student, tutor, session_id):
    await session_service.check_in(db_session, tutor, session_id)
    return await session_service.check_in(db_session, student, session_id)


async def _push_clock_back(db_session, session_id, *, minutes: int) -> None:
    """Move a live session's recorded start into the past.

    Real elapsed time cannot be produced inside a test, and the accrual rule is
    about the distance between two recorded instants, not about the wall clock.
    """
    now = datetime.now(UTC)
    await db_session.execute(
        update(Session)
        .where(Session.public_id == session_id)
        .values(
            started_at=now - timedelta(minutes=minutes),
            tutor_checked_in_at=now - timedelta(minutes=minutes),
            tutee_checked_in_at=now - timedelta(minutes=minutes),
        )
    )
    await db_session.commit()


async def test_create_session_starts_with_no_attendance(db_session):
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)

    session = await _scheduled_session(db_session, student, tutor, course_unit)

    assert session.status is SessionStatus.SCHEDULED
    assert session.tutor_checked_in_at is None
    assert session.tutee_checked_in_at is None
    assert session.tutor_finished_at is None
    assert session.tutee_finished_at is None


async def test_one_check_in_leaves_the_session_waiting(db_session):
    """A tutor alone must not be able to declare the student present."""
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)
    created = await _scheduled_session(db_session, student, tutor, course_unit)

    after_tutor = await session_service.check_in(db_session, tutor, created.id)

    assert after_tutor.status is SessionStatus.SCHEDULED
    assert after_tutor.tutor_checked_in_at is not None
    assert after_tutor.tutee_checked_in_at is None
    assert after_tutor.started_at is None

    live = await session_service.check_in(db_session, student, created.id)

    assert live.status is SessionStatus.IN_PROGRESS
    assert live.started_at is not None
    assert live.tutor_checked_in_at is not None
    assert live.tutee_checked_in_at is not None


async def test_a_second_check_in_from_the_same_party_is_idempotent(db_session):
    """A retried tap on a slow connection must not move the timestamp or fail."""
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)
    created = await _scheduled_session(db_session, student, tutor, course_unit)

    first = await session_service.check_in(db_session, tutor, created.id)
    second = await session_service.check_in(db_session, tutor, created.id)

    assert second.status is SessionStatus.SCHEDULED
    assert _instant(second.tutor_checked_in_at) == _instant(first.tutor_checked_in_at)
    assert second.tutee_checked_in_at is None


async def test_the_second_check_in_tells_the_party_who_was_waiting(db_session):
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)
    created = await _scheduled_session(db_session, student, tutor, course_unit)

    await session_service.check_in(db_session, tutor, created.id)
    # One person waiting is not an event either of them needs announced.
    assert (
        await db_session.scalar(
            select(Notification.id).where(Notification.user_id == tutor.id)
        )
    ) is None

    await session_service.check_in(db_session, student, created.id)

    rows = list(
        (
            await db_session.scalars(
                select(Notification).where(Notification.user_id == tutor.id)
            )
        ).all()
    )
    assert [row.type for row in rows] == [NotificationType.SESSION_STARTED]
    assert "Student Example" in rows[0].body


async def test_finishing_before_both_have_checked_in_is_refused(db_session):
    """Closing a session nobody attended is not a completion."""
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)
    created = await _scheduled_session(db_session, student, tutor, course_unit)
    await session_service.check_in(db_session, tutor, created.id)

    with pytest.raises(ConflictProblem):
        await session_service.finish(db_session, tutor, created.id)


async def test_one_finish_does_not_complete_the_session(db_session):
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)
    created = await _scheduled_session(db_session, student, tutor, course_unit)
    await _check_in_both(db_session, student, tutor, created.id)

    waiting = await session_service.finish(db_session, tutor, created.id)

    assert waiting.status is SessionStatus.IN_PROGRESS
    assert waiting.tutor_finished_at is not None
    assert waiting.tutee_finished_at is None


async def test_completion_banks_the_overlap_and_asks_the_tutee_to_rate(db_session):
    """The end of the session is the earlier departure, not the later one.

    The tutor finished thirty minutes in and the student tapped finish an hour
    later. The student's extra taps must not extend the tutor's hours: the time
    after the tutor left is not time the tutor can confirm.
    """
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)
    created = await _scheduled_session(db_session, student, tutor, course_unit)
    await _check_in_both(db_session, student, tutor, created.id)
    await _push_clock_back(db_session, created.id, minutes=90)

    # The tutor's finish was recorded thirty minutes after the start; the student
    # has only just finished. Simulated by writing the earlier timestamp, which
    # is what a real tutor's tap would have produced.
    now = datetime.now(UTC)
    await db_session.execute(
        update(Session)
        .where(Session.public_id == created.id)
        .values(tutor_finished_at=now - timedelta(minutes=60))
    )
    await db_session.commit()

    completed = await session_service.finish(db_session, student, created.id)

    assert completed.status is SessionStatus.COMPLETED
    assert completed.duration_minutes == 30
    assert completed.ended_at is not None
    assert completed.is_rated is False

    row = await db_session.scalar(
        select(Notification).where(
            Notification.user_id == student.id,
            Notification.type == NotificationType.SESSION_COMPLETED,
        )
    )
    assert row is not None
    assert row.type is NotificationType.SESSION_COMPLETED


async def test_a_completed_session_is_banked_once_across_repeated_calls(db_session):
    """The accrual is not a function of how often a client asks."""
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)
    profile = await db_session.scalar(
        select(TutorProfile).where(TutorProfile.user_id == tutor.id)
    )
    assert profile is not None
    sessions_before = profile.completed_sessions
    minutes_before = profile.certified_minutes

    created = await _scheduled_session(db_session, student, tutor, course_unit)
    await _check_in_both(db_session, student, tutor, created.id)
    await _push_clock_back(db_session, created.id, minutes=45)
    await session_service.finish(db_session, tutor, created.id)
    completed = await session_service.finish(db_session, student, created.id)

    # A retried finish after completion is a normal mobile retry, not an event.
    repeated = await session_service.finish(db_session, student, created.id)
    assert repeated.status is SessionStatus.COMPLETED

    with pytest.raises(ValidationProblem):
        await session_service.transition_session(
            db_session,
            tutor,
            created.id,
            SessionTransitionRequest(status=SessionStatus.COMPLETED),
        )

    await db_session.refresh(profile)
    assert profile.completed_sessions == sessions_before + 1
    assert profile.certified_minutes == minutes_before + completed.duration_minutes


async def test_transitions_cannot_fake_a_start_or_a_finish(db_session):
    student, tutor, _stranger, course_unit = await _seed_session_data(db_session)
    created = await _scheduled_session(db_session, student, tutor, course_unit)

    with pytest.raises(ValidationProblem, match="check in"):
        await session_service.transition_session(
            db_session,
            tutor,
            created.id,
            SessionTransitionRequest(status=SessionStatus.IN_PROGRESS),
        )

    await _check_in_both(db_session, student, tutor, created.id)

    with pytest.raises(ValidationProblem, match="finish"):
        await session_service.transition_session(
            db_session,
            tutor,
            created.id,
            SessionTransitionRequest(status=SessionStatus.COMPLETED),
        )


async def test_a_stranger_cannot_check_in(db_session):
    student, tutor, stranger, course_unit = await _seed_session_data(db_session)
    created = await _scheduled_session(db_session, student, tutor, course_unit)

    with pytest.raises(AuthorizationProblem):
        await session_service.check_in(db_session, stranger, created.id)
