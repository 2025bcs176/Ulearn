# MUST Beta Redesign

**Goal:** a beta at Mbarara University of Science and Technology that a student
can use without being taught, and that a tutor wants to keep using.

**Target:** 10–12 weeks from the start of implementation.

This document is the plan of record for the redesign. The design language is in
[`design-system.md`](./design-system.md); the product scope it changes is in
[`MVP_Brief.md`](./MVP_Brief.md).

---

## 1. Decisions locked

| Decision | Choice |
| --- | --- |
| Visual direction | Campus Energy |
| Session start/finish | One-tap mutual check-in; the six-digit PIN is retired |
| Notifications | In-app inbox plus FCM push |
| Tutor profiles | Bio, availability, optional avatar and contact |
| Avatar for beta | Generated illustrated avatars; photo upload pipeline built behind config |
| Distribution | Signed APK, not the Play Store |
| Timeline | 10–12 weeks |

## 2. What changes for the student

- Home is a composer, not a feature directory.
- Course units are chips, not a catalogue to scan.
- Tutors are people with a year, a bio, a rating, a response time, and a quote.
- A request is one sheet, not a page.
- A session is a pass with a timeline, not a PIN form.
- The inbox tells the student what happened. They never press "check for an
  answer".
- Rating is an emoji scale and a few tags.

## 3. What changes for the tutor

- Tutor HQ surfaces requests, progress to Verified, the certificate, and recent
  reviews in one place.
- Accepting a request asks for time, length, and online/campus — the API already
  supports all three; the client currently asks only for length.
- Availability is a visible toggle.
- The certificate is a shareable pass, not a progress bar buried in a tab.

## 4. Backend changes

### 4.1 Session lifecycle

The PIN handshake is replaced by two independent check-ins.

```
Tutor confirms request → scheduled
Tutor taps I'm here     ─┐
Tutee taps I'm here     ─┴→ in_progress   (both timestamps recorded)
Tutor taps Finish       ─┐
Tutee taps Finish       ─┴→ completed     (both timestamps; accrual once)
Rating submitted        →    quality loop closes
```

New columns on `sessions`:

- `tutor_checked_in_at`
- `tutee_checked_in_at`
- `tutor_finished_at`
- `tutee_finished_at`

Endpoints:

- `POST /v1/sessions/{id}/check-in`
- `POST /v1/sessions/{id}/finish`

Removed: `reveal-pin`, `verify-pin`, `request-completion`,
`reveal-completion-pin`, `verify-completion-pin`, and the PIN columns and
counters. The migration is reversible.

**Why this is still attendance evidence:** the old code proved attendance with a
secret one party read to the other. The new code proves it with two independent
timestamps from two accounts. A tutee can no longer fabricate a session alone,
and a tutor can no longer bank hours without the student confirming. The rating
gate is unchanged.

### 4.2 Notifications

New tables:

- `notifications` (`user_id`, `type`, `title`, `body`, `data`, `read_at`,
  `dedupe_key`, `created_at`)
- `device_tokens` (`user_id`, `token`, `platform`, `last_seen_at`)

Endpoints:

- `GET /v1/notifications`
- `GET /v1/notifications/unread-count`
- `POST /v1/notifications/{id}/read`
- `POST /v1/notifications/read-all`
- `POST /v1/notifications/devices`
- `DELETE /v1/notifications/devices/{token}`

Events: request received, request accepted, request declined, session starting,
session started, session completed, rating received, promotion, certificate
earned.

Push uses Firebase Admin behind `FCM_ENABLED`. With it off, in-app
notifications still persist and the API still boots. Reminders are sent by
`python -m app.cli send-session-reminders`, run by cron, and are idempotent
through `dedupe_key`. There is no in-process scheduler.

### 4.3 Tutor profile

New fields on `tutor_profiles`:

- `bio` (280 chars)
- `accepting_requests` (bool, default true)
- `avatar_url` (nullable)
- `contact_phone` (nullable, never public)

The public tutor summary adds `avatar_url`, `bio`, `accepting_requests`, and
`year_of_study`. A phone number is only returned to the two parties of a
confirmed session through `GET /v1/sessions/{id}/contact`. It is never logged,
never in a list response, and never on a public profile.

### 4.4 Reviews and rating tags

- `ratings.tags` (JSON list, fixed vocabulary).
- `GET /v1/tutors/{id}/reviews` returns recent public feedback, score, tags,
  rater initials, and date. It does not return a rater identity.
- Reported feedback is filtered.

### 4.5 Topic suggestions

`course_unit_topics` (`course_unit_id`, `label`, `sort_order`) and
`GET /v1/academics/course-units/{id}/topics`. Seeded for the six MUST pilot
units so a student taps instead of typing.

## 5. Delivery sequence

| Week | Phase | Output |
| --- | --- | --- |
| 1 | Foundation | Tokens, typography, components, shell, auth restyle, design docs |
| 2 | Onboarding + Home | Faster wizard, Home composer, live session hero |
| 3 | Find + request | Course chips, tutor cards, request sheet, topic chips |
| 4 | Tutor profile | Bio, reviews, accept-time scheduling |
| 5 | Notifications | Backend, inbox, badge, FCM, deep links |
| 6 | Sessions | Mutual check-in, timeline, rating with tags |
| 7 | Tutor HQ | Requests, progress ring, certificate, availability |
| 8 | Hardening | Offline cache, error copy, analytics, crash reporting, safety |
| 9 | Validation | Integration tests, PostgreSQL and migration checks, performance |
| 10 | Dry run | 5–10 students, 5 tutors, real feedback |
| 11–12 | Launch | Fixes, signed APK, content, runbook |

## 6. Beta launch checklist

- [ ] A signed APK installs on a clean Android device.
- [ ] The full loop works from a cold start: sign up → onboard → request →
      accept → check in → complete → rate → notification.
- [ ] A student can recover from a dropped connection on every screen.
- [ ] No secret, token, phone number, or transcript data reaches a log.
- [ ] The database builds from migrations alone and `alembic check` is clean.
- [ ] The six MUST units have topic chips and at least one eligible tutor.
- [ ] 10–15 tutors have a bio, an avatar, and a Verified or Rising badge.
- [ ] A WhatsApp support line is staffed.
- [ ] The pilot runbook names who reviews a report and within what time.
- [ ] Analytics answers: how many requests, how many accepted, how many
      completed, how many rated.

## 7. Explicitly post-beta

- Availability calendars and slot booking.
- In-app chat.
- Payments.
- Leaderboards and streaks.
- Certificate PDF generation.
- Photo upload beyond the configured storage path.
- iOS distribution.
