"""Rating schemas.

The bounds are restated here as well as in the database. Duplicating them is
deliberate: a client gets a field-level message naming `score` instead of a 409
from a constraint, and a client that is not talking to this API can still see
what a valid score is.
"""

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Self

from pydantic import Field, model_validator

from app.models.enums import RatingTag
from app.models.rating import MAX_RATING, MAX_TAGS_PER_RATING, MIN_RATING
from app.schemas.base import MeanRating, OrmSchema, RequestSchema, Trimmed

MAX_FEEDBACK_LENGTH = 2000

#: How many reviews a tutor profile shows by default, and the most it will serve.
#:
#: A profile is a page, not an archive: the newest handful is what a student
#: reads before deciding, and the rating count beside the average says how much
#: evidence sits behind them. There is no offset parameter yet because nothing
#: asks for a second page -- adding one when a screen wants it beats shipping a
#: pager no client reads.
DEFAULT_TUTOR_REVIEWS = 5
MAX_TUTOR_REVIEWS = 20

#: How many course units one rating may endorse.
#:
#: A session is booked for exactly one course unit, so the largest list the
#: service will ever *accept* today is one. The cap is not a statement about what
#: is legal -- it is a bound on what a client may make the server look up. A
#: payload naming thousands of units is either a client bug or an attempt to turn
#: a single form submission into thousands of existence checks, and both should
#: be refused at the edge rather than after the work has been done.
#:
#: Five leaves room for the shape this will plausibly grow into -- a session that
#: legitimately covers a unit and its co-requisites -- without making the field
#: unbounded in the meantime. Raise it when a session can genuinely be about
#: more than a handful of units, not before.
MAX_ENDORSEMENTS_PER_RATING = 5


class RatingCreate(RequestSchema):
    """Scoring a session you attended.

    There is no `session_id` field, and that is on purpose. The route takes the
    session from its path, so a client cannot rate a session it was not part of
    by sending someone else's id, and the rater and ratee are filled in by the
    service from the session rather than trusted from the body.

    `endorsed_course_unit_ids` is the *other* half of the same submission and is
    separate from `score` for the reason set out in `app.models.endorsement`: the
    score is a judgement of the tutor, the endorsement is a claim about coverage.

    It is optional, and empty by default, because endorsement is optional. Not
    every session deserves one -- a tutor who turned up late has earned a score,
    and a student who did not want to say more should not be pushed into saying
    something. A client that cannot express "no endorsement" is a client that
    will make people endorse to get past a form.

    Only the session's own course unit can be endorsed, and that is enforced in
    the service rather than here: it is a comparison against existing state, not
    a property of the request body.
    """

    score: int = Field(
        ge=MIN_RATING,
        le=MAX_RATING,
        description=f"Whole score from {MIN_RATING} to {MAX_RATING}.",
    )
    comprehension_helped: bool = Field(
        description="Whether the session helped the tutee understand the topic."
    )
    feedback_text: Trimmed | None = Field(default=None, max_length=MAX_FEEDBACK_LENGTH)
    tags: list[RatingTag] = Field(
        default_factory=list,
        max_length=MAX_TAGS_PER_RATING,
        description=(
            "What the session was like, from a fixed vocabulary. Optional and "
            "empty by default: a student who only wants to give a score is not "
            "made to describe the tutor to get past the form."
        ),
    )
    endorsed_course_unit_ids: list[uuid.UUID] = Field(
        default_factory=list,
        max_length=MAX_ENDORSEMENTS_PER_RATING,
        description=(
            "Public ids of the course units the tutor actually covered. Empty "
            "means no endorsement, which is a legitimate submission."
        ),
    )

    @model_validator(mode="after")
    def tags_are_unique(self) -> Self:
        """The same tag may not appear twice in one submission.

        Not collapsed silently, for the reason the endorsement validator gives:
        the client sent something it can be told about, and a de-duplication
        would let a buggy picker send six ticks and have four saved without
        anything noticing.
        """
        if len(set(self.tags)) != len(self.tags):
            raise ValueError("tags must not contain duplicates")
        return self

    @model_validator(mode="after")
    def endorsed_units_are_unique(self) -> Self:
        """The same unit may not appear twice in one submission.

        The database refuses a duplicate row outright, so without this the
        client would get an unhandled integrity error for something it can be
        told plainly. A duplicate is also never meaningful: the rater is making
        one claim about one unit, and listing it twice is not a stronger claim.
        """
        seen: set[uuid.UUID] = set()
        for course_unit_id in self.endorsed_course_unit_ids:
            if course_unit_id in seen:
                raise ValueError("endorsed_course_unit_ids must not contain duplicates")
            seen.add(course_unit_id)
        return self


class RatingResponse(OrmSchema):
    """A rating, with its rater and ratee resolved to public ids.

    `rater_id` and `ratee_id` are sent to the recipient, not to an audience: a
    student sees who rated a session of theirs, and a tutor sees who rated their
    teaching. Neither is shown to a third party.
    """

    id: uuid.UUID = Field(validation_alias="public_id")
    session_id: uuid.UUID = Field(validation_alias="session_public_id")
    rater_id: uuid.UUID = Field(validation_alias="rater_public_id")
    ratee_id: uuid.UUID = Field(validation_alias="ratee_public_id")
    score: int
    comprehension_helped: bool
    feedback_text: str | None = None
    tags: list[str] = Field(
        default_factory=list,
        description="The tags the rater chose, in the order they chose them.",
    )
    created_at: datetime


class TutorReview(OrmSchema):
    """One review as any signed-in student reads it on a tutor's profile.

    Not `RatingResponse`, and not a trimmed copy of it, because the two are
    answering different questions. `RatingResponse` is a record of a transaction
    between two people: it names them, and it carries the note one wrote to the
    other. This is a publication to strangers, so it carries none of that -- the
    rater is an initial and the note is absent.

    The note is deliberately *not* published. It was written for the tutor, not
    for an audience, and a small cohort makes "the student who wrote about the
    resit" easy to identify from the text alone even without a name. What a
    browsing student needs is the score, what the session was like, and that a
    real person said so; the note stays between the two parties who were there.

    `rater_initials` is computed server-side from the display name. The name
    itself is never in this payload, and neither is any id belonging to the
    rater, so a review cannot be used to enumerate who rated whom.
    """

    id: uuid.UUID = Field(validation_alias="public_id")
    score: int = Field(ge=MIN_RATING, le=MAX_RATING)
    tags: list[str] = Field(
        default_factory=list,
        description="From the fixed vocabulary; unknown values are a newer tag.",
    )
    rater_initials: str = Field(max_length=4)
    created_at: datetime


class UnitEndorsementCount(OrmSchema):
    """How many sessions one tutor was endorsed for in one course unit.

    A raw count and nothing else. This is deliberately not a score: a per-unit
    average would need a decay model, a minimum-sample rule and an agreed way to
    show "not enough endorsements yet" to a student, and inventing those here
    would bake a matching policy into a transport type. Counts are the input that
    policy will later read.

    No `validation_alias`, unlike the schemas built from an ORM object. There is
    no ORM object here: the service groups in the database and hands over a row
    that already carries the *public* course unit id, so there is nothing for
    `from_attributes` to pick up and no attribute for an alias to point at. The
    rule the alias normally enforces -- a response body carries public ids and
    never primary keys -- is enforced by the query joining `course_units` for
    its public id rather than reading the endorsement's key column.
    """

    course_unit_id: uuid.UUID
    endorsement_count: int = Field(ge=0)


class TutorRatingSummary(OrmSchema):
    """A tutor's rating history, aggregated for their profile.

    The same total and count the promotion rule is computed from, so the number
    the tutor sees is the number the platform acted on.

    `per_unit` is separate from that total on purpose. A global average says a
    tutor is good; it does not say *at what*, and "4.8 overall" is compatible
    with a tutor who has never been endorsed for the unit a student is asking
    about. Units with no endorsement are absent rather than present with a zero,
    because an absent entry is not a claim that the tutor is weak there and a zero
    would be exactly that.
    """

    average_rating: MeanRating | None = Field(
        default=None,
        description="Null with no ratings yet; zero would read as badly rated.",
    )
    rating_total: Decimal = Field(max_digits=10, decimal_places=2, ge=0)
    rating_count: int = Field(ge=0)
    recent: list[RatingResponse] = Field(
        default_factory=list,
        description="Most recent first. Bounded by the page parameters.",
    )
    per_unit: list[UnitEndorsementCount] = Field(
        default_factory=list,
        description="Endorsement counts per course unit, most endorsed first.",
    )
