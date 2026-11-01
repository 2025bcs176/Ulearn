"""Role-separated six-digit start and completion handshake coverage."""

import uuid

import pytest
from sqlalchemy import select

from app.models.session import Session
from app.services.session_service import MAX_PIN_ATTEMPTS
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
async def handshake(committed_env: CommittedEnv) -> dict:
    course_unit = await first_course_unit(committed_env)
    tutor = await verified_tutor(committed_env, "pin.tutor@peerpass.mak.ac.ug")
    student = await register(committed_env.client, "pin.student@student.mak.ac.ug")
    await complete_profile(committed_env.client, student, course_unit=course_unit)
    session = await scheduled_session(committed_env, tutor, student, course_unit)
    reveal = await committed_env.client.get(
        f"/v1/sessions/{session['id']}/pin",
        headers=bearer(tutor),
    )
    assert reveal.status_code == 200, reveal.text
    return {
        "env": committed_env,
        "client": committed_env.client,
        "session_id": session["id"],
        "start_pin": reveal.json()["session_pin"],
        "tutor": tutor,
        "student": student,
    }


async def _session_row(ctx: dict, db) -> Session:
    result = await db.execute(
        select(Session).where(Session.public_id == uuid.UUID(ctx["session_id"]))
    )
    return result.scalar_one()


async def _enter_start(ctx: dict, pin: str, who: str = "student"):
    return await ctx["client"].post(
        f"/v1/sessions/{ctx['session_id']}/verify-pin",
        headers=bearer(ctx[who]),
        json={"pin": pin},
    )


async def test_start_code_is_tutor_only_and_six_digits(handshake: dict) -> None:
    client = handshake["client"]
    session_id = handshake["session_id"]

    tutee = await client.get(
        f"/v1/sessions/{session_id}/pin",
        headers=bearer(handshake["student"]),
    )
    assert tutee.status_code == 403

    tutor = await client.get(
        f"/v1/sessions/{session_id}/pin",
        headers=bearer(handshake["tutor"]),
    )
    assert tutor.status_code == 200
    assert len(tutor.json()["session_pin"]) == 6
    assert tutor.json()["attempts_remaining"] == MAX_PIN_ATTEMPTS


async def test_tutee_enters_start_code_and_tutor_cannot(handshake: dict) -> None:
    response = await _enter_start(handshake, handshake["start_pin"], "tutor")
    assert response.status_code == 403

    response = await _enter_start(handshake, handshake["start_pin"])
    assert response.status_code == 200
    assert response.json()["status"] == "in_progress"


async def test_wrong_start_codes_are_locked_after_limit(handshake: dict) -> None:
    wrong = "000000" if handshake["start_pin"] != "000000" else "000001"
    for _ in range(MAX_PIN_ATTEMPTS):
        response = await _enter_start(handshake, wrong)
        assert response.status_code == 422
    locked = await _enter_start(handshake, wrong)
    assert locked.status_code == 429


async def test_completion_code_is_revealed_to_tutee_and_verified_by_tutor(
    handshake: dict,
) -> None:
    assert (await _enter_start(handshake, handshake["start_pin"])).status_code == 200
    client = handshake["client"]
    session_id = handshake["session_id"]

    requested = await client.post(
        f"/v1/sessions/{session_id}/request-completion",
        headers=bearer(handshake["tutor"]),
    )
    assert requested.status_code == 200
    assert "session_pin" not in requested.json()

    tutor_reveal = await client.post(
        f"/v1/sessions/{session_id}/reveal-completion",
        headers=bearer(handshake["tutor"]),
    )
    assert tutor_reveal.status_code == 403

    tutee_reveal = await client.post(
        f"/v1/sessions/{session_id}/reveal-completion",
        headers=bearer(handshake["student"]),
    )
    assert tutee_reveal.status_code == 200
    completion_pin = tutee_reveal.json()["session_pin"]
    assert len(completion_pin) == 6

    tutee_verify = await client.post(
        f"/v1/sessions/{session_id}/verify-completion",
        headers=bearer(handshake["student"]),
        json={"pin": completion_pin},
    )
    assert tutee_verify.status_code == 403

    tutor_verify = await client.post(
        f"/v1/sessions/{session_id}/verify-completion",
        headers=bearer(handshake["tutor"]),
        json={"pin": completion_pin},
    )
    assert tutor_verify.status_code == 200
    assert tutor_verify.json()["status"] == "completed"


async def test_direct_completion_transition_is_rejected(handshake: dict) -> None:
    response = await handshake["client"].post(
        f"/v1/sessions/{handshake['session_id']}/transition",
        headers=bearer(handshake["student"]),
        json={"status": "completed"},
    )
    assert response.status_code == 422
