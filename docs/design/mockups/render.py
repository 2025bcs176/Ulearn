"""Render PeerPass Campus Energy reference screens as SVG -> PNG.

This is a design reference, not production UI. It exists so the first
implementation slice can be reviewed against a concrete visual target.
"""

from __future__ import annotations

import math
import subprocess
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).parent
W, H = 412, 915

INK = "#14142B"
INDIGO = "#2D2A8C"
AMBER = "#FFB020"
CORAL = "#E8503F"
MINT = "#18A77E"
CREAM = "#FFF9F2"
WHITE = "#FFFFFF"
MUTED = "#6B6B85"
LINE = "#ECE6DE"
SOFT = "#F7F3ED"
CORAL_TINT = "#FFF0ED"
AMBER_TINT = "#FFF6E3"
MINT_TINT = "#E8F7F1"
INDIGO_TINT = "#EEEDF9"

FONT = "Inter"
DISPLAY = "Inter Display"

_icon_paths = {
    "home": '<path d="M3 10.5 12 3l9 7.5V21a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z"/>',
    "calendar": '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M8 3v4M16 3v4M3 11h18"/>',
    "bell": '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
    "user": '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    "search": '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    "back": '<path d="M15 18l-6-6 6-6"/>',
    "check": '<path d="M4 12l5 5L20 6"/>',
    "mic": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3M9 21h6"/>',
    "share": '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 10.5l6.8-4M8.6 13.5l6.8 4"/>',
    "settings": '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
    "arrow": '<path d="M5 12h14M13 6l6 6-6 6"/>',
    "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    "video": '<rect x="3" y="6" width="13" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/>',
    "chat": '<path d="M21 11.5a8.5 8.5 0 0 1-12.3 7.6L3 21l1.9-5.7A8.5 8.5 0 1 1 21 11.5z"/>',
    "shield": '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/>',
    "star": '<path d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.3 5.9 20.6l1.4-6.8L2.2 9.1l6.9-.8z" fill="currentColor" stroke="none"/>',
}

_avatar_gradients: list[str] = []
_avatar_index = 0
_gradients = [
    (INDIGO, "#6C63D9"),
    (CORAL, "#F29B6D"),
    (MINT, "#5ED3B0"),
    (AMBER, "#F7D06B"),
    ("#8B5CF6", "#C4B5FD"),
]


def esc(value: str) -> str:
    return escape(value)


def text(
    x: float,
    y: float,
    value: str,
    *,
    size: float = 14,
    weight: int = 400,
    fill: str = INK,
    anchor: str = "start",
    family: str = FONT,
    opacity: float = 1.0,
    italic: bool = False,
    spacing: float | None = None,
) -> str:
    extra = ""
    if italic:
        extra += ' font-style="italic"'
    if spacing is not None:
        extra += f' letter-spacing="{spacing}"'
    return (
        f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" '
        f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" '
        f'opacity="{opacity}"{extra}>{esc(value)}</text>'
    )


def rect(
    x: float,
    y: float,
    w: float,
    h: float,
    *,
    r: float = 0,
    fill: str = WHITE,
    stroke: str | None = None,
    sw: float = 1,
    shadow: bool = False,
    opacity: float = 1.0,
) -> str:
    filt = ' filter="url(#shadow)"' if shadow else ""
    stroke_attr = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" '
        f'fill="{fill}"{stroke_attr}{filt} opacity="{opacity}"/>'
    )


def line(
    x1: float, y1: float, x2: float, y2: float, *, color: str = LINE, sw: float = 1, dash: str | None = None
) -> str:
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    return (
        f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" '
        f'stroke="{color}" stroke-width="{sw}"{dash_attr}/>'
    )


def circle(
    cx: float, cy: float, r: float, *, fill: str = WHITE, stroke: str | None = None, sw: float = 1
) -> str:
    stroke_attr = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{stroke_attr}/>'


def icon(name: str, x: float, y: float, size: float = 22, color: str = INK, sw: float = 1.8) -> str:
    path = _icon_paths[name]
    return (
        f'<g transform="translate({x},{y}) scale({size / 24})" color="{color}" '
        f'stroke="{color}" fill="none" stroke-width="{sw}" '
        f'stroke-linecap="round" stroke-linejoin="round">{path}</g>'
    )


def avatar(cx: float, cy: float, r: float, initials: str, palette: int = 0) -> str:
    global _avatar_index
    c1, c2 = _gradients[palette % len(_gradients)]
    gid = f"av{_avatar_index}"
    _avatar_index += 1
    _avatar_gradients.append(
        f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/>'
        f"</linearGradient>"
    )
    size = r * 1.32
    return (
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{gid})"/>'
        + text(
            cx,
            cy + size * 0.18,
            initials,
            size=size,
            weight=700,
            fill=WHITE,
            anchor="middle",
        )
    )


def pill(
    x: float,
    y: float,
    w: float,
    h: float,
    label: str,
    *,
    fill: str = MINT_TINT,
    color: str = MINT,
    size: float = 10,
    weight: int = 700,
    stroke: str | None = None,
) -> str:
    return (
        rect(x, y, w, h, r=h / 2, fill=fill, stroke=stroke)
        + text(x + w / 2, y + h / 2 + size * 0.36, label, size=size, weight=weight, fill=color, anchor="middle")
    )


def status_bar() -> str:
    pieces = [text(28, 28, "9:41", size=13, weight=600)]
    # signal bars
    for i, h in enumerate((5, 8, 11, 14)):
        pieces.append(rect(318 + i * 5, 34 - h, 3, h, r=1, fill=INK))
    # wifi arcs
    pieces.append(
        '<g fill="none" stroke="#14142B" stroke-width="1.8" stroke-linecap="round">'
        '<path d="M344 29a9 9 0 0 1 12 0"/><path d="M347 32a5 5 0 0 1 6 0"/>'
        '<circle cx="350" cy="35" r="1.4" fill="#14142B" stroke="none"/></g>'
    )
    # battery
    pieces.append(rect(366, 22, 22, 11, r=3, fill="none", stroke=INK, sw=1.5))
    pieces.append(rect(369, 25, 14, 5, r=1.5, fill=INK))
    pieces.append(rect(389, 25.5, 2, 4, r=1, fill=INK))
    return "".join(pieces)


def bottom_nav(active: str) -> str:
    items = [
        ("home", "Home", 52),
        ("calendar", "Sessions", 154),
        ("bell", "Inbox", 258),
        ("user", "Profile", 360),
    ]
    pieces = [
        rect(0, 855, W, 60, fill=WHITE),
        line(0, 855, W, 855, color=LINE),
    ]
    for name, label, cx in items:
        on = label.lower() == active.lower()
        color = INDIGO if on else MUTED
        pieces.append(icon(name, cx - 11, 865, 22, color, 1.8))
        pieces.append(text(cx, 903, label, size=10, weight=700 if on else 500, fill=color, anchor="middle"))
        if label == "Inbox":
            pieces.append(circle(cx + 12, 864, 8, fill=AMBER))
            pieces.append(text(cx + 12, 867.5, "3", size=9, weight=800, fill=INK, anchor="middle"))
    return "".join(pieces)


def screen(body: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="160%">
    <feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#14142B" flood-opacity="0.07"/>
  </filter>
  {''.join(_avatar_gradients)}
</defs>
<rect width="{W}" height="{H}" fill="{CREAM}"/>
{body}
</svg>"""


def home() -> str:
    b = [status_bar()]
    # header
    b.append(avatar(44, 84, 20, "BA", 0))
    b.append(text(76, 80, "Hey Brian 👋", size=22, weight=800, family=DISPLAY))
    b.append(text(76, 100, "Let's get you unstuck.", size=12, fill=MUTED))
    b.append(icon("bell", 352, 68, 24, INK))
    b.append(circle(374, 66, 9, fill=AMBER))
    b.append(text(374, 69.5, "3", size=9, weight=800, fill=INK, anchor="middle"))

    # hero card
    b.append(rect(24, 124, 364, 330, r=24, fill=WHITE, shadow=True))
    b.append(text(44, 156, "ASK FOR HELP", size=10, weight=700, fill=INDIGO, spacing=1.2))
    b.append(text(44, 192, "What's giving you", size=28, weight=800, family=DISPLAY))
    b.append(text(44, 224, "trouble today?", size=28, weight=800, family=DISPLAY))
    b.append(rect(44, 248, 220, 36, r=18, fill=INDIGO))
    b.append(text(154, 271, "MAT 221 · Linear Algebra", size=12, weight=600, fill=WHITE, anchor="middle"))
    b.append(rect(44, 292, 150, 36, r=18, fill=WHITE, stroke=LINE))
    b.append(text(119, 315, "Database Programming", size=11, weight=600, fill=INK, anchor="middle"))
    b.append(rect(202, 292, 70, 36, r=18, fill=WHITE, stroke=LINE))
    b.append(text(237, 315, "+ Add", size=11, weight=700, fill=INDIGO, anchor="middle"))
    b.append(rect(44, 340, 324, 48, r=14, fill=SOFT))
    b.append(icon("search", 58, 353, 18, MUTED))
    b.append(text(84, 369, "e.g. eigenvalues before Friday's CAT", size=11, fill=MUTED))
    b.append(icon("mic", 342, 353, 18, CORAL))
    b.append(rect(44, 400, 324, 52, r=16, fill=AMBER))
    b.append(text(206, 432, "Find me a tutor  →", size=15, weight=800, fill=INK, anchor="middle"))

    # live session pass
    b.append(rect(24, 470, 364, 166, r=24, fill=CORAL_TINT, stroke="#F7D5CF"))
    b.append(pill(44, 488, 82, 22, "STARTS SOON", fill=CORAL, color=WHITE, size=9))
    b.append(text(44, 534, "Your session with Sarah", size=17, weight=800, family=DISPLAY))
    b.append(text(44, 554, "Today, 7:00 PM · Online", size=11, fill=MUTED))
    b.append(rect(44, 570, 140, 40, r=12, fill=INDIGO))
    b.append(text(114, 595, "I'm here", size=12, weight=700, fill=WHITE, anchor="middle"))
    b.append(rect(196, 570, 120, 40, r=12, fill=WHITE, stroke="#E7C8C2"))
    b.append(text(256, 595, "Join call", size=12, weight=700, fill=CORAL, anchor="middle"))
    b.append(icon("chat", 44, 616, 14, CORAL))
    b.append(text(62, 628, "Share on WhatsApp", size=10, weight=600, fill=CORAL))

    # tutors
    b.append(text(24, 660, "Tutors who can help", size=17, weight=800, family=DISPLAY))
    b.append(text(388, 660, "See all", size=11, weight=700, fill=INDIGO, anchor="end"))
    b.append(rect(24, 676, 230, 150, r=20, fill=WHITE, shadow=True))
    b.append(avatar(52, 704, 20, "SK", 1))
    b.append(text(82, 700, "Sarah K.", size=14, weight=700))
    b.append(text(82, 718, "Year 3 · Computer Science", size=10, fill=MUTED))
    b.append(pill(44, 736, 64, 20, "Verified"))
    b.append(icon("star", 116, 739, 11, AMBER, 0))
    b.append(text(130, 751, "4.9 · 12 sessions", size=10, weight=600, fill=INK))
    b.append(text(44, 774, "I break DB concepts down", size=10, fill=INK))
    b.append(text(44, 788, "with real examples.", size=10, fill=INK))
    b.append(text(44, 808, '"Joins finally made sense."', size=9, fill=MUTED, italic=True))

    b.append(rect(266, 676, 230, 150, r=20, fill=WHITE, shadow=True))
    b.append(avatar(294, 704, 20, "BO", 2))
    b.append(text(324, 700, "Brian O.", size=14, weight=700))
    b.append(text(324, 718, "Year 4 · Software Eng.", size=10, fill=MUTED))
    b.append(pill(286, 736, 78, 20, "Rising tutor", fill=AMBER_TINT, color="#8A5A00"))
    b.append(text(286, 774, "Patient with beginners.", size=10, fill=INK))
    b.append(text(286, 808, '"He made it click."', size=9, fill=MUTED, italic=True))

    b.append(bottom_nav("Home"))
    return screen("".join(b))


def find() -> str:
    b = [status_bar()]
    b.append(icon("back", 24, 64, 24, INK))
    b.append(text(56, 81, "MAT 221 · Linear Algebra", size=17, weight=800, family=DISPLAY))

    b.append(rect(24, 102, 364, 46, r=14, fill=WHITE, shadow=True))
    b.append(icon("search", 40, 116, 18, MUTED))
    b.append(text(66, 130, "Search a topic or tutor", size=11, fill=MUTED))

    b.append(pill(24, 162, 54, 32, "All", fill=INDIGO, color=WHITE, size=11))
    b.append(pill(86, 162, 82, 32, "Verified", fill=WHITE, color=INK, size=11, weight=600, stroke=LINE))
    b.append(pill(176, 162, 112, 32, "Free tonight", fill=WHITE, color=INK, size=11, weight=600, stroke=LINE))

    b.append(text(24, 224, "3 tutors can help", size=17, weight=800, family=DISPLAY))
    b.append(text(24, 243, "Meet on campus or online — you choose.", size=11, fill=MUTED))

    cards = [
        ("SK", "Sarah K.", "Year 3 · Computer Science", "Verified", MINT_TINT, MINT,
         "I break DB concepts down with real examples.", '"Joins finally made sense." — 3 students', "Ask Sarah", 1),
        ("BO", "Brian O.", "Year 4 · Software Engineering", "Rising tutor", AMBER_TINT, "#8A5A00",
         "Normalization, joins, and exam prep.", '"He made it click." — 5 students', "Ask Brian", 2),
        ("AN", "Amina N.", "Year 3 · Information Systems", "Verified", MINT_TINT, MINT,
         "Patient with beginners. Online or library.", '"Best session this semester." — 4 students', "Ask Amina", 0),
    ]
    y = 258
    for initials, name, sub, badge, badge_bg, badge_fg, bio, quote, cta, palette in cards:
        b.append(rect(24, y, 364, 176, r=20, fill=WHITE, shadow=True))
        b.append(avatar(52, y + 32, 22, initials, palette))
        b.append(text(86, y + 28, name, size=16, weight=800, family=DISPLAY))
        b.append(text(86, y + 48, sub, size=10, fill=MUTED))
        b.append(pill(300, y + 14, 64 if badge == "Verified" else 82, 22, badge, fill=badge_bg, color=badge_fg, size=9))
        b.append(icon("star", 44, y + 66, 11, AMBER, 0))
        b.append(text(59, y + 78, "4.9 (12 sessions) · replied in 15 min", size=10, weight=600, fill=INK))
        b.append(text(44, y + 100, bio, size=11, fill=INK))
        b.append(text(44, y + 122, quote, size=10, fill=MUTED, italic=True))
        b.append(rect(44, y + 136, 324, 34, r=12, fill=INDIGO))
        b.append(text(206, y + 158, cta, size=12, weight=700, fill=WHITE, anchor="middle"))
        y += 190

    b.append(bottom_nav("Home"))
    return screen("".join(b))


def session() -> str:
    b = [status_bar()]
    b.append(icon("back", 24, 64, 24, INK))
    b.append(text(56, 81, "Session", size=17, weight=800, family=DISPLAY))

    # pass card
    b.append(rect(24, 100, 364, 250, r=24, fill=WHITE, shadow=True))
    b.append('<path d="M24 124a24 24 0 0 1 24-24h316a24 24 0 0 1 24 24v8H24z" fill="#E8503F"/>')
    b.append(text(44, 148, "COURSE UNIT", size=9, weight=700, fill=MUTED, spacing=1.2))
    b.append(text(44, 180, "Eigenvalues &", size=24, weight=800, family=DISPLAY))
    b.append(text(44, 208, "diagonalisation", size=24, weight=800, family=DISPLAY))
    b.append(text(44, 232, "MAT 221 · Linear Algebra", size=11, fill=MUTED))
    b.append(circle(49, 250, 3, fill=MINT))
    b.append(text(58, 254, "With Sarah K. · Verified", size=11, weight=600, fill=INK))
    b.append(pill(44, 268, 150, 30, "Starts in 42 min", fill=AMBER_TINT, color="#8A5A00", size=11))
    # pass perforation
    b.append(line(44, 320, 368, 320, color="#E7DED2", sw=1.2, dash="5 5"))
    b.append(circle(24, 320, 8, fill=CREAM))
    b.append(circle(388, 320, 8, fill=CREAM))
    b.append(text(44, 338, "PASS  ·  7:00 PM", size=9, weight=700, fill=MUTED, spacing=1.2))

    # timeline card
    b.append(rect(24, 366, 364, 250, r=20, fill=WHITE, shadow=True))
    b.append(text(44, 398, "Session progress", size=14, weight=800, family=DISPLAY))
    b.append(line(60, 420, 60, 588, color=LINE, sw=2))
    steps = [
        ("Requested", "You asked for help", "done"),
        ("Accepted", "Sarah said yes", "done"),
        ("Starting soon", "Today, 7:00 PM", "active"),
        ("In session", "Tap I'm here when you meet", "todo"),
        ("Rate", "Tell us how it went", "todo"),
    ]
    sy = 424
    for title, sub, state in steps:
        if state == "done":
            b.append(circle(60, sy, 9, fill=MINT))
            b.append(icon("check", 54, sy - 6, 12, WHITE, 2.4))
        elif state == "active":
            b.append(circle(60, sy, 11, fill=AMBER_TINT, stroke=AMBER, sw=2))
            b.append(circle(60, sy, 4, fill=AMBER))
        else:
            b.append(circle(60, sy, 6, fill=WHITE, stroke="#CFC7BC", sw=2))
        b.append(text(82, sy + 4, title, size=12, weight=700, fill=INK if state != "todo" else MUTED))
        b.append(text(82, sy + 20, sub, size=10, fill=MUTED))
        sy += 42

    # actions
    b.append(rect(24, 632, 176, 52, r=16, fill=INDIGO))
    b.append(text(112, 664, "I'm here", size=14, weight=800, fill=WHITE, anchor="middle"))
    b.append(rect(212, 632, 176, 52, r=16, fill=WHITE, stroke=INDIGO, sw=1.4))
    b.append(icon("video", 238, 649, 18, INDIGO))
    b.append(text(264, 664, "Join call", size=14, weight=700, fill=INDIGO))

    b.append(icon("chat", 24, 700, 14, CORAL))
    b.append(text(42, 712, "Share on WhatsApp", size=10, weight=600, fill=CORAL))
    b.append(icon("calendar", 220, 700, 14, INDIGO))
    b.append(text(238, 712, "Add to calendar", size=10, weight=600, fill=INDIGO))

    b.append(icon("shield", 24, 728, 14, MUTED))
    b.append(text(42, 740, "Meet in a public place on campus.", size=10, fill=MUTED))
    b.append(text(42, 754, "Report anything that feels off.", size=10, fill=MUTED))

    b.append(rect(24, 768, 364, 64, r=16, fill=WHITE, stroke=LINE))
    b.append(icon("clock", 44, 786, 18, INDIGO))
    b.append(text(70, 798, "Today, 7:00 PM", size=12, weight=700, fill=INK))
    b.append(text(70, 816, "60 minutes · Online · video call", size=10, fill=MUTED))

    b.append(bottom_nav("Sessions"))
    return screen("".join(b))


def tutor_hq() -> str:
    b = [status_bar()]
    b.append(text(24, 80, "Your tutor HQ", size=24, weight=800, family=DISPLAY))
    b.append(text(24, 102, "Good evening, Sarah.", size=11, fill=MUTED))
    b.append(icon("settings", 320, 68, 22, MUTED))
    b.append(avatar(374, 80, 20, "SK", 1))

    # progress card
    b.append(rect(24, 124, 364, 190, r=24, fill=WHITE, shadow=True))
    circumference = 2 * math.pi * 44
    progress = 0.8
    b.append(circle(92, 219, 44, fill="none", stroke="#F1E9DF", sw=9))
    b.append(
        f'<circle cx="92" cy="219" r="44" fill="none" stroke="{MINT}" stroke-width="9" '
        f'stroke-linecap="round" stroke-dasharray="{circumference * progress:.1f} {circumference:.1f}" '
        f'transform="rotate(-90 92 219)"/>'
    )
    b.append(text(92, 218, "2", size=30, weight=800, fill=INK, anchor="middle"))
    b.append(text(92, 236, "to Verified", size=9, fill=MUTED, anchor="middle"))
    b.append(text(156, 190, "You're almost there", size=17, weight=800, family=DISPLAY))
    b.append(text(156, 212, "2 more sessions and a 4.10 average.", size=10, fill=MUTED))
    b.append(text(156, 244, "★ 4.8 average", size=11, weight=700, fill=INK))
    b.append(text(156, 262, "14 students helped", size=11, weight=700, fill=INK))
    b.append(pill(156, 274, 132, 24, "2 sessions to Verified", fill=MINT_TINT, color=MINT, size=9))

    # requests
    b.append(text(24, 342, "Waiting on you", size=17, weight=800, family=DISPLAY))
    b.append(pill(150, 326, 74, 22, "2 requests", fill=AMBER_TINT, color="#8A5A00", size=9))

    requests = [
        ("BA", "Brian A. · Year 2", "Needs help with SQL joins", "MAT 221 · Database Programming · 2h ago", 0),
        ("AN", "Amina N. · Year 2", "Struggling with normalization", "CSC 202 · Database Programming · 4h ago", 2),
    ]
    y = 360
    for initials, name, topic, unit, palette in requests:
        b.append(rect(24, y, 364, 140, r=20, fill=WHITE, shadow=True))
        b.append(avatar(52, y + 32, 20, initials, palette))
        b.append(text(84, y + 28, name, size=14, weight=700))
        b.append(text(84, y + 48, topic, size=12, weight=600, fill=INK))
        b.append(text(84, y + 66, unit, size=9, fill=MUTED))
        b.append(rect(44, y + 86, 200, 38, r=12, fill=INDIGO))
        b.append(text(144, y + 110, "Accept", size=12, weight=700, fill=WHITE, anchor="middle"))
        b.append(rect(256, y + 86, 112, 38, r=12, fill=WHITE, stroke=LINE))
        b.append(text(312, y + 110, "Not this one", size=10, weight=600, fill=MUTED, anchor="middle"))
        y += 154

    # stats
    stats = [("3", "sessions"), ("4.9", "rating"), ("2", "reviews")]
    x = 24
    for value, label in stats:
        b.append(rect(x, 670, 116, 68, r=16, fill=WHITE, stroke=LINE))
        b.append(text(x + 58, 700, value, size=22, weight=800, fill=INK, anchor="middle"))
        b.append(text(x + 58, 718, label, size=10, fill=MUTED, anchor="middle"))
        x += 124

    # certificate
    b.append(rect(24, 752, 364, 64, r=16, fill=WHITE, shadow=True))
    b.append(text(44, 776, "Your teaching certificate", size=12, weight=700))
    b.append(text(44, 794, "8 of 10 hours", size=10, fill=MUTED))
    b.append(rect(180, 782, 150, 8, r=4, fill="#F1E9DF"))
    b.append(rect(180, 782, 120, 8, r=4, fill=MINT))
    b.append(icon("share", 350, 772, 18, MUTED))

    # availability toggle
    b.append(rect(24, 826, 44, 24, r=12, fill=AMBER))
    b.append(circle(56, 838, 9, fill=WHITE))
    b.append(text(80, 842, "Accepting requests", size=11, weight=600, fill=INK))

    b.append(bottom_nav("Home"))
    return screen("".join(b))


SCREENS = {
    "home": home,
    "find": find,
    "session": session,
    "tutor-hq": tutor_hq,
}


def main() -> None:
    for name, builder in SCREENS.items():
        _avatar_gradients.clear()
        global _avatar_index
        _avatar_index = 0
        svg_path = OUT / f"peerpass-{name}.svg"
        png_path = OUT / f"peerpass-{name}.png"
        svg_path.write_text(builder(), encoding="utf-8")
        subprocess.run(
            [
                "inkscape",
                str(svg_path),
                "--export-type=png",
                f"--export-filename={png_path}",
                "--export-width=824",
            ],
            check=True,
            capture_output=True,
        )
        print(f"{png_path}  ({png_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
