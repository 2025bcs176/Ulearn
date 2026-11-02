"""Migrate reference data from a Firebase Realtime Database export into PeerPass."""

import argparse
import asyncio
import json
from decimal import Decimal

from sqlalchemy import select

from app.core.database import get_session_factory
from app.models.course_unit import CourseUnit, Subject, University
from app.models.grading_scale import Grade, GradingScale


def _dec(value, default=None):
    if value is None:
        return default
    return Decimal(str(value))


async def migrate(data: dict) -> None:
    db = get_session_factory()()
    try:
        scale_map = {}
        for _fb_id, payload in (data.get("grading_scales") or {}).items():
            name = payload.get("name")
            if not name:
                continue
            row = await db.scalar(select(GradingScale).where(GradingScale.name == name))
            if row is None:
                row = GradingScale(
                    name=name,
                    max_points=_dec(payload.get("max_points"), Decimal("5.00")),
                    competency_min_points=_dec(
                        payload.get("competency_min_points"), Decimal("4.50")
                    ),
                )
                db.add(row)
                await db.flush()
            scale_map[_fb_id] = row

        for _fb_id, payload in (data.get("grades") or {}).items():
            label = payload.get("label")
            if not label:
                continue
            scale = scale_map.get(payload.get("grading_scale_id"))
            if scale is None:
                scale = await db.scalar(select(GradingScale))
            if scale is None:
                continue
            existing = await db.scalar(
                select(Grade).where(
                    Grade.label == label, Grade.grading_scale_id == scale.id
                )
            )
            if existing is None:
                db.add(
                    Grade(
                        label=label,
                        grade_points=_dec(payload.get("grade_points"), Decimal("0")),
                        grading_scale_id=scale.id,
                    )
                )
        await db.flush()

        uni_map = {}
        for _fb_id, payload in (data.get("universities") or {}).items():
            name = payload.get("name")
            if not name:
                continue
            row = await db.scalar(select(University).where(University.name == name))
            if row is None:
                scale = scale_map.get(payload.get("grading_scale_id"))
                if scale is None:
                    scale = await db.scalar(select(GradingScale))
                row = University(
                    name=name, grading_scale_id=scale.id if scale else None
                )
                db.add(row)
                await db.flush()
            uni_map[_fb_id] = row

        if not uni_map:
            for row in (await db.execute(select(University))).scalars().all():
                uni_map[row.name] = row

        subject_map = {}
        for _fb_id, payload in (data.get("subjects") or {}).items():
            name = payload.get("name")
            if not name:
                continue
            uni = uni_map.get(payload.get("university_id"))
            if uni is None:
                uni = next(iter(uni_map.values()), None)
            if uni is None:
                uni = await db.scalar(select(University))
            if uni is None:
                continue
            row = await db.scalar(
                select(Subject).where(
                    Subject.name == name, Subject.university_id == uni.id
                )
            )
            if row is None:
                row = Subject(name=name, university_id=uni.id)
                db.add(row)
                await db.flush()
            subject_map[_fb_id] = row

        for _fb_id, payload in (data.get("course_units") or {}).items():
            code = payload.get("code")
            name = payload.get("name")
            if not code or not name:
                continue
            uni = uni_map.get(payload.get("university_id"))
            if uni is None:
                uni = await db.scalar(select(University))
            if uni is None:
                continue
            subject = subject_map.get(payload.get("subject_id"))
            existing = await db.scalar(
                select(CourseUnit).where(
                    CourseUnit.code == code, CourseUnit.university_id == uni.id
                )
            )
            if existing is None:
                db.add(
                    CourseUnit(
                        code=code,
                        name=name,
                        university_id=uni.id,
                        subject_id=subject.id if subject else None,
                    )
                )
            else:
                existing.name = name
                if subject is not None:
                    existing.subject_id = subject.id

        await db.commit()
        print("Migration complete.")
    finally:
        await db.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True)
    args = parser.parse_args()
    with open(args.file, encoding="utf-8") as fh:
        data = json.load(fh)
    asyncio.run(migrate(data))


if __name__ == "__main__":
    main()
