"""Tutor discovery routes: the rail a student browses, and one tutor's profile.

Student-facing and read-only. Nothing here creates a `TutorProfile` and nothing
here offers a tutor for work -- a browse is discovery, and `POST
/v1/matching/suggestions` is the only place a tutor is proposed. The
suspension filter lives in the service query rather than in the route, so a
suspended tutor cannot appear in any list this module grows later.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentUser, DatabaseSession
from app.schemas.rating import (
    DEFAULT_TUTOR_REVIEWS,
    MAX_TUTOR_REVIEWS,
    TutorReview,
)
from app.schemas.tutor import (
    DEFAULT_RAIL_TUTORS,
    MAX_RAIL_TUTORS,
    TutorDetailResponse,
    TutorRailEntry,
)
from app.services import rating_service, tutor_service

router = APIRouter(prefix="/tutors", tags=["tutors"])


# Declared before `/{user_id}` below. FastAPI matches in declaration order, and
# `GET /v1/tutors/top` would otherwise reach the parameterised route and be
# refused as a malformed UUID -- a 422 for a path that exists.
@router.get(
    "/top",
    response_model=list[TutorRailEntry],
    summary="Tutors to browse",
)
async def top_tutors(
    caller: CurrentUser,
    db: DatabaseSession,
    course_unit_id: uuid.UUID | None = None,
    limit: Annotated[int, Query(ge=1, le=MAX_RAIL_TUTORS)] = DEFAULT_RAIL_TUTORS,
) -> list[TutorRailEntry]:
    """The strongest tutors available to the signed-in student.

    `course_unit_id` narrows the rail to tutors who pass the competency gate in
    that unit; without it the rail spans every verified competency at the
    student's own university, so a screen with no unit picker still has something
    to show. Omit it on first paint and send it once the student picks a course.

    A `course_unit_id` that names no unit, or one at another institution, gives
    an empty rail rather than a 404: the client filtered on a stale value, and
    the honest answer to "tutors for this unit" is none.

    A student who has not chosen a university gets a 422 instead, because the
    rail is defined as their own university's tutors and there is no sensible
    fallback to invent -- the remedy is one onboarding step away.
    """
    return await tutor_service.list_top_tutors(
        db,
        caller.user,
        course_unit_id=course_unit_id,
        limit=limit,
    )


@router.get(
    "/{user_id}/reviews",
    response_model=list[TutorReview],
    summary="A tutor's recent public reviews",
)
async def tutor_reviews(
    user_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
    limit: Annotated[int, Query(ge=1, le=MAX_TUTOR_REVIEWS)] = DEFAULT_TUTOR_REVIEWS,
) -> list[TutorReview]:
    """What other students said about this tutor, newest first.

    Separate from the profile rather than nested in it so the detail screen can
    paint the tutor's name, standing and rating without waiting on the review
    query, and can retry one without refetching the other. `limit` is a page
    size, not a cursor: there is no offset because nothing has asked for a
    second page yet.
    """
    return await rating_service.list_public_reviews(db, user_id, limit=limit)


@router.get(
    "/{user_id}",
    response_model=TutorDetailResponse,
    summary="One tutor's public profile",
)
async def tutor_detail(
    user_id: uuid.UUID,
    caller: CurrentUser,
    db: DatabaseSession,
) -> TutorDetailResponse:
    """A single tutor's standing, ratings, and endorsed units.

    404 for a user who does not exist and for one who is not a tutor: the two
    are the same answer on purpose, so the route cannot be used to discover
    which accounts hold the tutor role. The body is `TutorProfileSummary`, so a
    student never receives the suspension reason or the raw rating total.
    """
    return await tutor_service.get_tutor_detail(db, caller.user, user_id)
