# MUST FCI undergraduate catalogue

## Pilot scope

The pilot catalogue is limited to MUST's **Faculty of Computing and
Informatics**. Postgraduate programmes and every other faculty are excluded
until a later scope decision.

The seed currently publishes these undergraduate degrees:

- Computer Science
- Information Technology
- Software Engineering

The course-unit list is sourced from PR #39. It contains 63 FCI units using the
codes and names supplied there, with the PR's faculty label normalized to the
pilot label **Faculty of Computing and Informatics**. The PR includes Software
Engineering units even though its programme list omitted the degree; the seed
therefore includes Software Engineering explicitly.

## Data ownership

PR #39 is an engineering source for the pilot catalogue, not a substitute for
MUST approval. Before invitations are issued, FCI must confirm:

1. The three undergraduate degree names.
2. The 63 course-unit codes and names that are launchable.
3. The initial tutor cohort and the units each tutor may support.

The seed is idempotent and can be rerun with:

```bash
cd backend
python -m app.db.seed
```

The course-unit endpoint remains faculty-scoped. A student with no faculty or
with a faculty whose catalogue is empty receives an empty list and can still
complete onboarding.
