# Ulearn contributor and agent guide

## Project context

Ulearn is a mobile-first peer tutoring network for university students. The
product connects tutees with verified peer tutors for focused academic
interventions, records completed sessions, and tracks tutor incentives.

Before changing behavior, read:

- `README.md` for product scope and local setup.
- `docs/Ulearn_Research_Document.md` for the problem, stakeholders, and pilot
  assumptions.
- `docs/architecture.md` for system boundaries, data model, matching, and
  validation rules.
- `docs/Contribution.md` for workflow, standards, and review requirements.

## Repository boundaries

- `frontend/` is the Flutter mobile client. Keep it feature-first and
  low-bandwidth friendly.
- `backend/` is the FastAPI service. Keep HTTP concerns in `app/api`, domain
  logic in `app/services`, persistence in `app/models`, and transport types in
  `app/schemas`.
- `backend/tests/` contains backend unit and integration tests.
- `frontend/test/` contains Flutter unit, widget, and integration tests.
- `docs/` contains architecture and project documentation.

The canonical client directory is `frontend/`; do not add new code under the
legacy misspelled `fontend/` directory.

## Domain invariants

- Tutor matching must consult validation and competency status before proposing
  a tutor.
- A tutor competency requires a verified B+ or higher unless an explicitly
  documented portfolio/manual override applies.
- Completed sessions require post-session ratings.
- Session records are the source for tutor hours and certificate eligibility.
- Academic records and credentials are sensitive: use environment variables for
  secrets, explicit consent for academic data, and HTTPS at runtime.

## Implementation standards

- Preserve the layered architecture; do not move business rules into Flutter
  widgets or route handlers.
- Use strong typing and narrow exception handling. Do not silently swallow
  validation, authorization, or persistence errors.
- Use snake_case for Python and Dart files, PascalCase for classes, camelCase
  for methods and variables, and UPPER_SNAKE_CASE for constants.
- Add focused tests for changed behavior, especially matching constraints,
  grade boundaries, rating thresholds, and session transitions.
- Update the relevant architecture or API documentation when a boundary or
  public behavior changes.

## Validation commands

Backend:

```bash
cd backend
pytest
```

Frontend:

```bash
cd frontend
flutter analyze
flutter test
```

Use conventional commits (`feat:`, `fix:`, `docs:`, `test:`, etc.) and keep
pull requests focused.
