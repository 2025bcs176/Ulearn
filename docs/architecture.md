# Ulearn Architecture

**System Design & Technical Blueprint**

> This document describes the high-level architecture, core components, data model, matching engine, and validation protocol of Ulearn — a peer-to-peer academic support network for university students.

**Last Updated**: September 2026 | **Status**: Active

---

## 1. Vision & Design Goals

Ulearn exists to replace the “attend lectures and fight for your life” model with a reliable, stigma-free micro-intervention safety net. The architecture is shaped by the following goals:

| Goal                        | Architectural Implication                                                           |
| --------------------------- | ----------------------------------------------------------------------------------- |
| Mobile-first, low-bandwidth | Flutter client; lightweight API payloads; offline-friendly patterns where practical |
| Academic integrity          | Multi-tier tutor validation before matching is allowed                              |
| Low friction for students   | Simple request → match → session flow                                               |
| Verifiable incentives       | Session logging that can generate Teaching Assistant certificates                   |
| Institutional readiness     | PostgreSQL relational model, SSO-ready auth, DPPA-compliant data handling           |
| Future LMS integration      | Clean API boundaries and modular services                                           |

---

## 2. High-Level System Overview

```
┌─────────────────┐         HTTPS / REST          ┌──────────────────────┐
│                 │  ◄──────────────────────────► │                      │
│  Flutter App    │                               │   FastAPI Backend    │
│  (Mobile)       │                               │                      │
│                 │                               │  • Auth & Users      │
└─────────────────┘                               │  • Matching Engine   │
                                                  │  • Validation        │
                                                  │  • Sessions & Ratings│
                                                  │  • Incentives        │
                                                  └──────────┬───────────┘
                                                             │
                                                             │ SQLAlchemy
                                                             ▼
                                                  ┌──────────────────────┐
                                                  │    PostgreSQL        │
                                                  │                      │
                                                  │  Users               │
                                                  │  Course_Units        │
                                                  │  Competencies        │
                                                  │  Session_Logs        │
                                                  │  Ratings             │
                                                  └──────────────────────┘
```

**Key characteristics**

- Client-server architecture with a single mobile client (Flutter)
- Stateless REST API (FastAPI) for all business logic
- Relational database as the source of truth for users, competencies, and sessions
- Matching and validation logic live in dedicated backend services (not in the client)

---

## 3. Technology Stack

| Layer                | Technology                  | Rationale                                                                                                    |
| -------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------ |
| **Frontend**         | Flutter                     | Cross-platform (Android + iOS), excellent performance on modest devices, strong offline capabilities         |
| **Backend**          | FastAPI (Python 3.10+)      | High performance, automatic OpenAPI docs, excellent async support, rapid development                         |
| **ORM / Migrations** | SQLAlchemy + Alembic        | Mature, type-friendly, reliable schema evolution                                                             |
| **Database**         | PostgreSQL                  | Strong relational integrity, excellent for complex joins (matching + competencies), JSON support when needed |
| **Auth**             | JWT + future University SSO | Stateless tokens for mobile; designed for institutional SSO integration                                      |
| **API Style**        | RESTful JSON                | Simple, cacheable, easy to consume from Flutter                                                              |

---

## 4. Core Components

### 4.1 Frontend (Flutter)

Organized in a **feature-first** structure:

- `auth` — Login, registration, SSO hand-off
- `profile` — Student / tutor profile & role management
- `matching` — Create topic requests, view matches, accept/reject
- `sessions` — Schedule, join, and complete micro-sessions
- `tutor_validation` — Upload transcript / link portfolio, view verification status
- `incentives` — View logged hours and certificate status

Shared layers:

- Network client (Dio or equivalent)
- Riverpod (or similar) for state management
- Core theme, constants, and reusable widgets

### 4.2 Backend (FastAPI)

Layered structure:

```
api/          → HTTP routes & request validation
services/     → Business logic (matching, validation, incentives)
models/       → SQLAlchemy ORM models
schemas/      → Pydantic request/response models
core/         → Config, security, database session, exceptions
```

**Critical services**

- `MatchingService` — Core algorithm that pairs tutee requests with eligible tutors
- `ValidationService` — Implements the three-tier tutor quality gate
- `SessionService` — Lifecycle of a tutoring session + logging
- `IncentiveService` — Aggregates hours and prepares certificate data

### 4.3 Database (PostgreSQL)

Primary tables (see Section 5 for details):

| Table          | Responsibility                                                  |
| -------------- | --------------------------------------------------------------- |
| `users`        | Identity, role (`tutee`, `provisional_tutor`, `verified_tutor`) |
| `course_units` | University curriculum mapping                                   |
| `competencies` | Tutor eligibility per course unit (grade + verification status) |
| `session_logs` | Record of every completed or cancelled session                  |
| `ratings`      | Post-session feedback that drives tutor promotion / demotion    |

---

## 5. Data Model

### 5.1 Entity Relationships (Conceptual)

```
Users 1 ─────── * Competencies * ─────── 1 Course_Units
  │
  │ 1
  │
  * Session_Logs
  │
  │ 1
  │
  * Ratings
```

### 5.2 Schema Highlights

| Table            | Core Attributes                                               | Purpose                                                                               |
| ---------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| **Users**        | `user_id`, `role_type`                                        | Tracks role (`tutee`, `provisional_tutor`, `verified_tutor`) to control access levels |
| **Course_Units** | `unit_id`, `unit_code`                                        | Maps the exact university curriculum                                                  |
| **Competencies** | `user_id`, `unit_id`, `grade_achieved`, `verification_status` | Validation gate requiring a minimum of B+ or A                                        |
| **Session_Logs** | `session_id`, `status`, `duration_minutes`                    | Record of every tutoring session; feeds matching priority                             |
| **Ratings**      | `session_id`, `score`, `feedback_text`                        | Post-session feedback; low ratings reduce matching priority                           |

### 5.3 Detailed Table Definitions

**Users**

- `user_id` (PK)
- `email`, `full_name`, `university_id` (optional)
- `role_type` — `tutee` | `provisional_tutor` | `verified_tutor`
- `is_active`, timestamps

**Course_Units**

- `unit_id` (PK)
- `unit_code`, `unit_name`, `faculty`, `year_level`
- Optional metadata for matching (topics, keywords)

**Competencies**

- `competency_id` (PK)
- `user_id` (FK → users)
- `unit_id` (FK → course_units)
- `grade_achieved` (e.g. A, B+)
- `verification_status` (boolean or enum: pending / verified / rejected)
- `verification_source` (transcript | portfolio | manual)
- Unique constraint on (`user_id`, `unit_id`)

**Session_Logs**

- `session_id` (PK)
- `tutee_id`, `tutor_id` (FK → users)
- `unit_id` / topic
- `requested_at`, `started_at`, `ended_at`
- `status` (requested | matched | completed | cancelled)
- `duration_minutes`

**Ratings**

- `rating_id` (PK)
- `session_id` (FK)
- `rater_id`, `ratee_id`
- `score` (e.g. 1–5)
- `feedback_text`
- Used by the validation engine to promote or demote tutors

---

## 6. Multi-Tiered Tutor Validation Protocol

A peer-to-peer system is only useful if tutors are competent. Ulearn enforces quality through three sequential gates:

### Tier 1 — Academic Data Gate (Hard Gate)

- Tutor must have a verified grade of **B+ or higher** in the target course unit.
- Source: uploaded transcript or secure institutional query.
- Without this, the user cannot be matched as a tutor for that unit.

### Tier 2 — External Portfolio Gate (Practical Gate)

- Optional override / enhancement for practical subjects.
- Examples: GitHub activity for software modules, deployed projects, etc.
- Allows provisional elevation when traditional grades under-represent skill.

### Tier 3 — Probationary Feedback Loop (Community Gate)

- New tutors start as `provisional_tutor`.
- Every completed session requires a rating from the tutee.
- High average rating → promotion to `verified_tutor` + leadership credits.
- Low average rating → reduced matching priority or revocation of tutor status for that unit.

This logic lives in `ValidationService` and is consulted by `MatchingService` before any match is proposed.

---

## 7. Matching Engine

### High-Level Flow

1. Tutee submits a **topic request** (course unit + specific concept).
2. System queries `Competencies` for tutors who:
   - Have verified (or provisional) status for that unit
   - Meet the current rating threshold
   - Are available / not overloaded
3. Ranking may consider:
   - Verification tier (verified > provisional)
   - Average rating
   - Number of completed sessions in the unit
   - Recency of activity
4. Top candidate(s) are presented to the tutee (or auto-matched, depending on configuration).
5. Once accepted, a `Session_Log` is created and the scheduling flow begins.

The matching service is deliberately kept pure (no UI concerns) so it can later be exposed to institutional dashboards or LMS plugins.

---

## 8. Session Lifecycle

```
Request Created
      │
      ▼
Matching Engine runs
      │
      ▼
Tutor Accepts / Declines
      │
      ▼
Session Scheduled (in-app)
      │
      ▼
Session Completed
      │
      ▼
Rating Submitted → ValidationService updates tutor status
      │
      ▼
IncentiveService logs hours → certificate eligibility
```

---

## 9. Security & Compliance

- **Authentication**: JWT for mobile sessions; designed for future University SSO (SAML/OAuth).
- **Authorization**: Role-based access control via `role_type` and competency checks.
- **Data Protection**: Compliant with the Uganda Data Protection and Privacy Act, 2019 (DPPA). Sensitive academic data (grades, transcripts) requires explicit consent and secure storage.
- **Transport**: HTTPS only.
- **Secrets**: Never committed; loaded from environment variables.

---

## 10. Non-Functional Requirements

| Requirement            | Target / Approach                                                                              |
| ---------------------- | ---------------------------------------------------------------------------------------------- |
| **Latency**            | Matching responses under 1–2 seconds under normal load                                         |
| **Availability**       | Stateless API allows horizontal scaling                                                        |
| **Bandwidth**          | Minimal payloads; images and heavy assets avoided where possible                               |
| **Offline resilience** | Client can queue non-critical actions; critical flows remain online-first                      |
| **Observability**      | Structured logging + future metrics (request latency, match success rate, rating distribution) |

---

## 11. Future Extension Points

- Institutional SSO and direct academic database integration
- LMS plugin / LTI support
- Advanced matching (topic embeddings, availability calendars)
- Analytics dashboard for university administrators
- Multi-university support with tenant isolation

---

## 12. Related Documents

- [CONTRIBUTING.md](./CONTRIBUTING.md) — Contribution guidelines and Code of Conduct
- [README.md](../README.md) — Project overview and local setup
- Pilot roadmap and research proposal (project root / docs)

---

**Maintainers**: Gilbert Asiimwe ([@asiimwe-dev](https://github.com/asiimwe-dev))
