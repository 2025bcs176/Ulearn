"""The suggested topics a request sheet offers for a unit.

Topic chips are reference data with the same faculty rule as the catalogue they
sit under: a unit a student may not see has no suggestions to offer them, and
saying "this unit has none" would be a different claim from "you may not see this
unit". These tests drive the endpoint over HTTP for that reason -- the scoping is
enforced in one place, and a unit test on the handler with a mocked caller would
not prove the route, the dependency, or the guard work.
"""

import uuid

from sqlalchemy import func, select

from app.db.seed import COURSE_UNIT_TOPICS
from app.models.course_unit import CourseUnit, Subject, University
from app.models.course_unit_topic import CourseUnitTopic
from tests.conftest import CommittedEnv
from tests.support import bearer, complete_profile, first_course_unit, register

UNITS_URL = "/v1/academics/course-units"


async def _student(env: CommittedEnv, email: str) -> tuple[dict, dict]:
    """A registered student whose faculty owns the first seeded unit."""
    unit = await first_course_unit(env)
    body = await register(env.client, email)
    await complete_profile(env.client, body, course_unit=unit)
    return body, unit


def _topics_url(unit: dict) -> str:
    return f"{UNITS_URL}/{unit['id']}/topics"


async def test_lists_a_units_suggestions_in_the_seeded_order(
    committed_env: CommittedEnv,
) -> None:
    body, unit = await _student(committed_env, "topics@must.ac.ug")

    response = await committed_env.client.get(_topics_url(unit), headers=bearer(body))

    assert response.status_code == 200, response.text
    rows = response.json()
    assert [row["label"] for row in rows] == list(COURSE_UNIT_TOPICS[unit["code"]])
    # The id is public and stable, so a chip can be keyed on it without the label
    # standing in as an identifier.
    assert all(uuid.UUID(row["id"]) for row in rows)
    assert [row["sort_order"] for row in rows] == list(range(len(rows)))


async def test_a_unit_with_no_suggestions_is_an_empty_list(
    committed_env: CommittedEnv,
) -> None:
    """The normal state before suggestions are loaded, not a failure.

    The catalogue and its topics are separate rows, so a unit can be published
    before anybody has written suggestions for it. The sheet falls back to the
    free-text field, which is why an empty list must be renderable.
    """
    body, unit = await _student(committed_env, "bare.unit@must.ac.ug")
    async with committed_env.session() as session:
        row = await session.scalar(
            select(CourseUnit).where(CourseUnit.public_id == uuid.UUID(unit["id"]))
        )
        assert row is not None
        bare = CourseUnit(
            code="TST1000",
            name="A Unit With No Suggestions",
            university_id=row.university_id,
            subject_id=row.subject_id,
        )
        session.add(bare)
        await session.commit()
        bare_id = str(bare.public_id)

    response = await committed_env.client.get(
        _topics_url({"id": bare_id}), headers=bearer(body)
    )

    assert response.status_code == 200, response.text
    assert response.json() == []


async def test_another_facultys_unit_is_not_found(
    committed_env: CommittedEnv,
) -> None:
    """404, not an empty list.

    An empty list would say the unit exists and has no suggestions; the truth is
    that the caller may not act on it at all. The catalogue endpoint applies the
    same rule, so a client cannot use suggestions to prove a unit it was not
    offered exists.
    """
    body, _ = await _student(committed_env, "scoped.topics@must.ac.ug")
    async with committed_env.session() as session:
        university = await session.scalar(select(University))
        assert university is not None
        other_faculty = Subject(name="Faculty of Science", university=university)
        session.add(other_faculty)
        await session.flush()
        other_unit = CourseUnit(
            code="SCH 211",
            name="A Unit In Another Faculty",
            university_id=university.id,
            subject_id=other_faculty.id,
        )
        session.add(other_unit)
        await session.commit()
        other_id = str(other_unit.public_id)

    response = await committed_env.client.get(
        _topics_url({"id": other_id}), headers=bearer(body)
    )

    assert response.status_code == 404, response.text


async def test_an_unknown_unit_is_not_found(committed_env: CommittedEnv) -> None:
    body, _ = await _student(committed_env, "unknown.topics@must.ac.ug")

    response = await committed_env.client.get(
        _topics_url({"id": str(uuid.uuid4())}), headers=bearer(body)
    )

    assert response.status_code == 404, response.text


async def test_anonymous_callers_are_refused(committed_env: CommittedEnv) -> None:
    unit = await first_course_unit(committed_env)

    response = await committed_env.client.get(_topics_url(unit))

    assert response.status_code == 401, response.text


async def test_every_planned_unit_has_its_whole_topic_list(
    committed_env: CommittedEnv,
) -> None:
    """The six pilot units are catalogued and seeded together.

    A topic list keyed on a code that is not in the catalogue would be invisible
    from the student's side: the unit shows no chips and nothing reports why. The
    seed prints a warning, but this is the assertion that keeps the two constants
    from drifting apart.
    """
    async with committed_env.session() as session:
        codes = set((await session.execute(select(CourseUnit.code))).scalars().all())
        counts = {
            code: (
                await session.scalar(
                    select(func.count(CourseUnitTopic.id))
                    .join(CourseUnit, CourseUnit.id == CourseUnitTopic.course_unit_id)
                    .where(CourseUnit.code == code)
                )
                or 0
            )
            for code in COURSE_UNIT_TOPICS
        }

    assert set(COURSE_UNIT_TOPICS) <= codes, "a planned unit is missing from the seed"
    for code, labels in COURSE_UNIT_TOPICS.items():
        assert counts[code] == len(labels), f"{code} is missing topic suggestions"
