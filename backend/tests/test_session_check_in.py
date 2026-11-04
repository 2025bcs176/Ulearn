"""Mutual check-in over the real router.

The service tests prove the rules; these prove the route, the auth guard, and
the wire shape the client actually calls. A check-in with no body is easy to
break by leaving a request schema in place, and a client would see a 422 for a
tap that only sends a header.
"""

import uuid
from datetime import UTC, datetime

import pytest
from sqlalchemy import select

from app.models.session import Session
from tests.conftest import CommittedEnv
from tests.support import (
    bearer,
    complete_profile,
    first_course_unit,
    register,
    scheduled_session,
    verified_tutor,
)


@pytest.fixture
async def booked(committed_env: CommittedEnv) -> dict:
    course_unit = await first_course_unit(committed_env)
    tutor = await verified_tutor(committed_env, "checkin.tutor@peerpass.mak.ac.ug")
    student = await register(committed_env.client, "checkin.student@student.mak.ac.ug")
    await complete_profile(committed_env.client, student, course_unit=course_unit)
    session = await scheduled_session(committed_env, tutor, student, course_unit)
    return {
        "env": committed_env,
        "client": committed_env.client,
        "session_id": session["id"],
        "tutor": tutor,
        "student": student,
    }


async def _post(ctx: dict, action: str, who: str):
    return await ctx["client"].post(
        f"/v1/sessions/{ctx['session_id']}/{action}",
        headers=bearer(ctx[who]),
    )


def _instant(value: str) -> datetime:
    parsed = datetime.fromisoformat(value)
    return parsed if parsed.tzinfo is not None else parsed.replace(tzinfo=UTC)


async def test_each_party_checks_in_and_the_second_starts_the_session(
    booked: dict,
) -> None:
    tutor_tap = await _post(booked, "check-in", "tutor")
    assert tutor_tap.status_code == 200, tutor_tap.text
    assert tutor_tap.json()["status"] == "scheduled"
    assert tutor_tap.json()["tutor_checked_in_at"] is not None
    assert tutor_tap.json()["tutee_checked_in_at"] is None

    student_tap = await _post(booked, "check-in", "student")
    assert student_tap.status_code == 200, student_tap.text
    assert student_tap.json()["status"] == "in_progress"
    assert student_tap.json()["started_at"] is not None

    # The waiting party hears about it; the caller does not need their own tap
    # repeated back to them. Read through the inbox a client actually opens.
    inbox = await booked["client"].get(
        "/v1/notifications", headers=bearer(booked["tutor"])
    )
    assert inbox.status_code == 200, inbox.text
    types = [item["type"] for item in inbox.json()["items"]]
    # Newest first. The request-received row was written when the student chose
    # this tutor; the check-in is the newer event.
    assert types[0] == "session_started"
    assert types.count("session_started") == 1


async def test_a_repeated_check_in_is_not_an_error(booked: dict) -> None:
    first = await _post(booked, "check-in", "tutor")
    second = await _post(booked, "check-in", "tutor")

    assert second.status_code == 200, second.text
    # SQLite drops the timezone on the way back; compare the instant, not the
    # representation.
    assert _instant(second.json()["tutor_checked_in_at"]) == _instant(
        first.json()["tutor_checked_in_at"]
    )
    assert second.json()["status"] == "scheduled"


async def test_both_finishes_complete_the_session(booked: dict) -> None:
    assert (await _post(booked, "check-in", "tutor")).status_code == 200
    assert (await _post(booked, "check-in", "student")).status_code == 200

    tutor_finish = await _post(booked, "finish", "tutor")
    assert tutor_finish.status_code == 200, tutor_finish.text
    assert tutor_finish.json()["status"] == "in_progress"

    student_finish = await _post(booked, "finish", "student")
    assert student_finish.status_code == 200, student_finish.text
    assert student_finish.json()["status"] == "completed"
    assert student_finish.json()["ended_at"] is not None
    assert student_finish.json()["duration_minutes"] >= 1


async def test_finishing_a_session_nobody_started_is_refused(booked: dict) -> None:
    response = await _post(booked, "finish", "tutor")

    assert response.status_code == 409
    assert "checked in" in response.json()["detail"]


async def test_a_party_outside_the_session_is_refused(booked: dict) -> None:
    outsider = await register(booked["client"], "checkin.outsider@student.mak.ac.ug")

    response = await booked["client"].post(
        f"/v1/sessions/{booked['session_id']}/check-in",
        headers=bearer(outsider),
    )

    assert response.status_code == 403


async def test_the_old_handshake_routes_are_gone(booked: dict) -> None:
    """A 404 is the contract change: there is no PIN to reveal or guess."""
    for path in ("pin", "verify-pin", "request-completion", "reveal-completion"):
        response = await booked["client"].post(
            f"/v1/sessions/{booked['session_id']}/{path}",
            headers=bearer(booked["tutor"]),
        )
        assert response.status_code == 404, path


async def test_direct_completion_transition_is_rejected(booked: dict) -> None:
    assert (await _post(booked, "check-in", "tutor")).status_code == 200
    assert (await _post(booked, "check-in", "student")).status_code == 200

    response = await booked["client"].post(
        f"/v1/sessions/{booked['session_id']}/transition",
        headers=bearer(booked["tutor"]),
        json={"status": "completed"},
    )

    assert response.status_code == 422
    assert response.json()["errors"]["status"] == "completion requires both finishes"


async def test_completion_is_recorded_on_the_row(booked: dict) -> None:
    assert (await _post(booked, "check-in", "tutor")).status_code == 200
    assert (await _post(booked, "check-in", "student")).status_code == 200
    assert (await _post(booked, "finish", "tutor")).status_code == 200
    assert (await _post(booked, "finish", "student")).status_code == 200

    async with booked["env"].session() as db:
        row = await db.scalar(
            select(Session).where(Session.public_id == uuid.UUID(booked["session_id"]))
        )
    assert row is not None
    assert row.tutor_checked_in_at is not None
    assert row.tutee_checked_in_at is not None
    assert row.tutor_finished_at is not None
    assert row.tutee_finished_at is not None
