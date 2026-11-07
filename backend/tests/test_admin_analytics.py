"""The pilot funnel: the four counts the launch runbook asks for."""

from httpx import AsyncClient

from tests.conftest import CommittedEnv
from tests.support import bearer, grant_admin, register


async def test_the_funnel_is_admin_only(client: AsyncClient) -> None:
    # These are cohort counts, not academic records, but they still describe the
    # pilot to whoever can read them. A student has no reason to see the
    # operator's daily numbers.
    body = await register(client, "funnel.student@student.mak.ac.ug")

    response = await client.get(
        "/v1/admin/analytics/pilot-funnel", headers=bearer(body)
    )

    assert response.status_code == 403
    assert response.json()["code"] == "not_permitted"


async def test_an_empty_pilot_is_four_zeroes_not_a_failure(
    committed_env: CommittedEnv,
) -> None:
    # The console opens on launch day before anyone has asked for anything. The
    # honest answer is zero at every stage, and it has to render as a dashboard
    # rather than as an error an operator would learn to ignore.
    admin = await grant_admin(committed_env, "funnel.admin@peerpass.mak.ac.ug")

    response = await committed_env.client.get(
        "/v1/admin/analytics/pilot-funnel", headers=bearer(admin)
    )

    assert response.status_code == 200
    assert response.json() == {
        "requests_total": 0,
        "requests_accepted": 0,
        "sessions_completed": 0,
        "sessions_rated": 0,
    }
