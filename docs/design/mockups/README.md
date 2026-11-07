# Campus Energy reference screens

These are design targets for the beta redesign, not screenshots of the app and
not production assets. They exist so a review can argue about a concrete screen
instead of an adjective.

| Screen | File |
| --- | --- |
| Home composer | `peerpass-home.png` |
| Find a tutor | `peerpass-find.png` |
| Session pass and timeline | `peerpass-session.png` |
| Tutor HQ | `peerpass-tutor-hq.png` |

The screens were drawn from the tokens in
[`docs/design-system.md`](../../design-system.md). If a token changes, these
images are stale: update the token and the mockup together.

`render.py` regenerates all four images from the same tokens (`inkscape` must be
on the path):

```bash
python3 docs/design/mockups/render.py
```

The four screens cover the beta's two critical loops:

1. **Tutee:** Home → Find → request → session → rate.
2. **Tutor:** Tutor HQ → accept → session → certificate progress.

They deliberately contain no six-digit PIN. The beta replaces the two code
handshakes with a one-tap mutual check-in, so the session screen shows a
timeline and two actions instead.
