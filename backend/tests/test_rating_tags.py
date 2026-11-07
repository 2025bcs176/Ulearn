"""Rating tags, and the reviews a tutor's profile publishes.

Two decisions are asserted here and both are about what other students get to
read. A tag is picked from a fixed vocabulary so a profile can render it without
a moderation queue behind free text, and a review carries an initial rather than
a name and no written note at all.

The note is the part worth being explicit about. It was written *to* the tutor,
not for an audience, and a pilot cohort small enough to recognise itself can
identify "the student who mentioned their resit" from the text alone. The public
review is the score, the tags, the initials, and the date; the note stays between
the two people who were in the room.

The report case is the other one. A session with an unresolved report has its
review withheld -- from the profile, not from the tutor's standing. The rating
still counts in the average, because the session happened and the platform
already acted on it; what is paused is the publication while somebody looks.
That asymmetry is deliberate and it is what stops a report being a way to scrub
a low score out of a tutor's record.
"""

import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import select

from app.models.course_unit import CourseUnit, Subject, University
from app.models.enums import (
    ReportCategory,
    ReportStatus,
    SessionStatus,
    TutorStanding,
    UserRole,
)
from app.models.grading_scale import Grade, GradingScale
from app.models.rating import Rating
from app.models.report import SessionReport
from app.models.session import Session
from app.models.tutor_profile import TutorProfile
from app.models.user import User, set_roles

GOOD_PASSWORD = "correct horse battery staple"


# --- seeding ---------------------------------------------------------------


async def _institution(db_session) -> tuple[University, CourseUnit, Grade]:
    scale = GradingScale(
        name="MUST 5-point",
        max_points=Decimal("5.00"),
        competency_min_points=Decimal("4.00"),
    )
    university = University(name="Mbarara University of Science and Technology")
    subject = Subject(name="Faculty of Science")
    grade = Grade(
        label="A",
        grade_points=Decimal("4.50"),
        max_points=Decimal("5.00"),
        grading_scale=scale,
    )
    course_unit = CourseUnit(
        code="MAT 221",
        name="Linear Algebra",
        subject=subject,
        university=university,
        grade=grade,
    )
    db_session.add_all([scale, university, subject, grade, course_unit])
    await db_session.flush()
    return university, course_unit, grade


async def _account(
    db_session,
    university: University,
    *,
    email: str,
    full_name: str | None,
) -> User:
    user = User(
        email=email,
        password_hash="hashed-password",
        full_name=full_name,
        university=university,
    )
    db_session.add(user)
    await db_session.flush()
    return user


async def _tutor(db_session, university: University) -> tuple[User, TutorProfile]:
    tutor = await _account(
        db_session,
        university,
        email="tutor@must.ac.ug",
        full_name="Okello Daniel",
    )
    profile = TutorProfile(
        user=tutor,
        standing=TutorStanding.PROBATIONARY,
        completed_sessions=1,
        rating_total=Decimal("0"),
        rating_count=0,
    )
    db_session.add(profile)
    await db_session.flush()
    await set_roles(db_session, tutor.id, {UserRole.TUTOR})
    await db_session.commit()
    return tutor, profile


async def _completed_session(
    db_session,
    course_unit: CourseUnit,
    *,
    tutee: User,
    tutor: User,
) -> Session:
    now = datetime.now(UTC)
    session = Session(
        tutee_id=tutee.id,
        tutor_id=tutor.id,
        course_unit_id=course_unit.id,
        topic="Eigenvalues",
        status=SessionStatus.COMPLETED,
        started_at=now,
        ended_at=now,
        duration_minutes=60,
        tutor_checked_in_at=now,
        tutee_checked_in_at=now,
        tutor_finished_at=now,
        tutee_finished_at=now,
    )
    db_session.add(session)
    await db_session.flush()
    return session


async def _rating(
    db_session,
    session: Session,
    *,
    rater: User,
    tutor: User,
    score: int,
    tags: list[str] | None = None,
    feedback_text: str | None = None,
    created_at: datetime | None = None,
) -> Rating:
    rating = Rating(
        session_id=session.id,
        rater_id=rater.id,
        ratee_id=tutor.id,
        score=score,
        comprehension_helped=True,
        feedback_text=feedback_text,
        tags=tags or [],
    )
    if created_at is not None:
        rating.created_at = created_at
    db_session.add(rating)
    await db_session.flush()
    return rating


async def _register(client, email: str) -> dict:
    response = await client.post(
        "/v1/auth/register", json={"email": email, "password": GOOD_PASSWORD}
    )
    assert response.status_code == 201, response.text
    return response.json()


def _bearer(body: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {body['tokens']['access_token']}"}


# --- tags ------------------------------------------------------------------


async def test_tags_are_stored_and_echoed_back(client, db_session) -> None:
    university, course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    student_body = await _register(client, "student@must.ac.ug")
    student = await db_session.scalar(
        select(User).where(User.email == "student@must.ac.ug")
    )
    assert student is not None
    session = await _completed_session(
        db_session, course_unit, tutee=student, tutor=tutor
    )
    await db_session.commit()

    response = await client.post(
        f"/v1/ratings/{session.public_id}",
        json={
            "comprehension_helped": True,
            "score": 5,
            "tags": ["clear_explanation", "made_it_click"],
        },
        headers=_bearer(student_body),
    )

    assert response.status_code == 201, response.text
    assert response.json()["tags"] == ["clear_explanation", "made_it_click"]
    stored = await db_session.scalar(
        select(Rating).where(Rating.public_id == uuid.UUID(response.json()["id"]))
    )
    assert stored is not None
    assert stored.tags == ["clear_explanation", "made_it_click"]


async def test_a_tag_outside_the_vocabulary_is_refused(client, db_session) -> None:
    university, course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    student_body = await _register(client, "student@must.ac.ug")
    student = await db_session.scalar(
        select(User).where(User.email == "student@must.ac.ug")
    )
    assert student is not None
    session = await _completed_session(
        db_session, course_unit, tutee=student, tutor=tutor
    )
    await db_session.commit()

    response = await client.post(
        f"/v1/ratings/{session.public_id}",
        json={
            "comprehension_helped": True,
            "score": 5,
            "tags": ["rude"],
        },
        headers=_bearer(student_body),
    )

    assert response.status_code == 422, response.text
    assert "tags" in response.text
    # Nothing was written: a refused submission is not a partial one.
    assert await db_session.scalar(select(Rating)) is None


async def test_the_same_tag_twice_is_refused(client, db_session) -> None:
    university, course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    student_body = await _register(client, "student@must.ac.ug")
    student = await db_session.scalar(
        select(User).where(User.email == "student@must.ac.ug")
    )
    assert student is not None
    session = await _completed_session(
        db_session, course_unit, tutee=student, tutor=tutor
    )
    await db_session.commit()

    response = await client.post(
        f"/v1/ratings/{session.public_id}",
        json={
            "comprehension_helped": True,
            "score": 5,
            "tags": ["patient", "patient"],
        },
        headers=_bearer(student_body),
    )

    assert response.status_code == 422, response.text
    # Collapsing the duplicate silently would let a picker that sends every tick
    # look like it worked. The caller is told instead.
    assert await db_session.scalar(select(Rating)) is None


async def test_more_than_four_tags_is_refused(client, db_session) -> None:
    university, course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    student_body = await _register(client, "student@must.ac.ug")
    student = await db_session.scalar(
        select(User).where(User.email == "student@must.ac.ug")
    )
    assert student is not None
    session = await _completed_session(
        db_session, course_unit, tutee=student, tutor=tutor
    )
    await db_session.commit()

    response = await client.post(
        f"/v1/ratings/{session.public_id}",
        json={
            "comprehension_helped": True,
            "score": 5,
            "tags": [
                "clear_explanation",
                "patient",
                "well_prepared",
                "made_it_click",
                "on_time",
            ],
        },
        headers=_bearer(student_body),
    )

    assert response.status_code == 422, response.text


async def test_a_rating_with_no_tags_gets_an_empty_list(client, db_session) -> None:
    """The field is optional, and "no tags" is a real answer rather than an error."""
    university, course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    student_body = await _register(client, "student@must.ac.ug")
    student = await db_session.scalar(
        select(User).where(User.email == "student@must.ac.ug")
    )
    assert student is not None
    session = await _completed_session(
        db_session, course_unit, tutee=student, tutor=tutor
    )
    await db_session.commit()

    response = await client.post(
        f"/v1/ratings/{session.public_id}",
        json={"comprehension_helped": True, "score": 4},
        headers=_bearer(student_body),
    )

    assert response.status_code == 201, response.text
    assert response.json()["tags"] == []


# --- reviews ---------------------------------------------------------------


async def test_a_review_publishes_the_score_and_tags_but_not_the_note(
    client, db_session
) -> None:
    university, course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    rater = await _account(
        db_session,
        university,
        email="sarah@must.ac.ug",
        full_name="Adongo Sarah",
    )
    session = await _completed_session(
        db_session, course_unit, tutee=rater, tutor=tutor
    )
    await _rating(
        db_session,
        session,
        rater=rater,
        tutor=tutor,
        score=5,
        tags=["clear_explanation", "patient"],
        feedback_text="Thanks for the extra hour before my resit.",
    )
    await db_session.commit()
    viewer = await _register(client, "viewer@must.ac.ug")

    response = await client.get(
        f"/v1/tutors/{tutor.public_id}/reviews", headers=_bearer(viewer)
    )

    assert response.status_code == 200, response.text
    reviews = response.json()
    assert len(reviews) == 1
    review = reviews[0]
    assert review["score"] == 5
    assert review["tags"] == ["clear_explanation", "patient"]
    assert review["rater_initials"] == "AS"
    # The byline is all a stranger gets. The note was written to the tutor, and
    # the rater's id would let a profile be walked back to an account.
    assert "feedback_text" not in review
    assert "rater_id" not in review
    assert "Adongo" not in response.text
    assert "resit" not in response.text


async def test_reviews_are_newest_first_and_capped(client, db_session) -> None:
    university, course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    student = await _account(
        db_session, university, email="student@must.ac.ug", full_name="Adongo Sarah"
    )
    newer = await _account(
        db_session, university, email="newer@must.ac.ug", full_name="Byaruhanga Peter"
    )
    oldest_at = datetime(2026, 3, 1, 9, tzinfo=UTC)

    first = await _completed_session(
        db_session, course_unit, tutee=student, tutor=tutor
    )
    second = await _completed_session(db_session, course_unit, tutee=newer, tutor=tutor)
    await _rating(
        db_session,
        first,
        rater=student,
        tutor=tutor,
        score=4,
        created_at=oldest_at,
    )
    await _rating(
        db_session,
        second,
        rater=newer,
        tutor=tutor,
        score=5,
        created_at=oldest_at + timedelta(days=1),
    )
    await db_session.commit()
    viewer = await _register(client, "viewer@must.ac.ug")

    response = await client.get(
        f"/v1/tutors/{tutor.public_id}/reviews",
        params={"limit": 1},
        headers=_bearer(viewer),
    )

    assert response.status_code == 200, response.text
    reviews = response.json()
    assert [review["score"] for review in reviews] == [5]
    assert reviews[0]["rater_initials"] == "BP"


async def test_an_unresolved_report_withholds_the_review_but_not_the_rating(
    client, db_session
) -> None:
    university, course_unit, _grade = await _institution(db_session)
    tutor, profile = await _tutor(db_session, university)
    rater = await _account(
        db_session, university, email="sarah@must.ac.ug", full_name="Adongo Sarah"
    )
    session = await _completed_session(
        db_session, course_unit, tutee=rater, tutor=tutor
    )
    await _rating(
        db_session,
        session,
        rater=rater,
        tutor=tutor,
        score=1,
        tags=["on_time"],
    )
    profile.rating_count = 1
    profile.rating_total = Decimal("1")
    report = SessionReport(
        session_id=session.id,
        reporter_id=rater.id,
        category=ReportCategory.SAFETY,
        status=ReportStatus.OPEN,
    )
    db_session.add(report)
    await db_session.commit()
    viewer = await _register(client, "viewer@must.ac.ug")

    withheld = await client.get(
        f"/v1/tutors/{tutor.public_id}/reviews", headers=_bearer(viewer)
    )

    assert withheld.status_code == 200, withheld.text
    assert withheld.json() == []
    # The score still counts. The publication is paused; the record is not
    # rewritten, so filing a report cannot scrub a tutor's average.
    assert profile.rating_count == 1
    assert profile.average_rating == Decimal("1")

    report.status = ReportStatus.RESOLVED
    await db_session.commit()

    restored = await client.get(
        f"/v1/tutors/{tutor.public_id}/reviews", headers=_bearer(viewer)
    )

    assert restored.status_code == 200, restored.text
    assert [review["score"] for review in restored.json()] == [1]


async def test_a_rater_with_no_name_is_bylined_by_their_address(
    client, db_session
) -> None:
    """An account with no name falls back to its address, and an initial is all
    that address contributes."""
    university, course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    rater = await _account(
        db_session, university, email="jdoe@must.ac.ug", full_name=None
    )
    session = await _completed_session(
        db_session, course_unit, tutee=rater, tutor=tutor
    )
    await _rating(db_session, session, rater=rater, tutor=tutor, score=4)
    await db_session.commit()
    viewer = await _register(client, "viewer@must.ac.ug")

    response = await client.get(
        f"/v1/tutors/{tutor.public_id}/reviews", headers=_bearer(viewer)
    )

    assert response.status_code == 200, response.text
    assert response.json()[0]["rater_initials"] == "J"


async def test_reviews_for_an_unknown_user_are_a_404(client, db_session) -> None:
    viewer = await _register(client, "viewer@must.ac.ug")

    response = await client.get(
        "/v1/tutors/00000000-0000-0000-0000-000000000000/reviews",
        headers=_bearer(viewer),
    )

    assert response.status_code == 404, response.text


async def test_reviews_for_a_student_are_a_404(client, db_session) -> None:
    """The 404 covers "not a tutor" as well as "not a person", so the route cannot
    be used to work out which accounts hold the tutor role."""
    university, _course_unit, _grade = await _institution(db_session)
    student = await _account(
        db_session, university, email="student@must.ac.ug", full_name="Adongo Sarah"
    )
    await db_session.commit()
    viewer = await _register(client, "viewer@must.ac.ug")

    response = await client.get(
        f"/v1/tutors/{student.public_id}/reviews", headers=_bearer(viewer)
    )

    assert response.status_code == 404, response.text


async def test_reviews_require_authentication(client, db_session) -> None:
    university, _course_unit, _grade = await _institution(db_session)
    tutor, _profile = await _tutor(db_session, university)
    await db_session.commit()

    response = await client.get(f"/v1/tutors/{tutor.public_id}/reviews")

    assert response.status_code == 401, response.text
