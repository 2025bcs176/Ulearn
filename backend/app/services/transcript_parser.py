"""Best-effort parsing of MUST transcripts (QR code + text).

MUST transcripts carry a QR code (the "MUST stamp") and a tabular list of
course units with grades. This module extracts:

  * the QR payload (validated as a MUST-issued transcript),
  * the course unit code(s) mentioned, and
  * the grade(s) paired with them.

Parsing is heuristic and depends on the transcript layout. When a field cannot
be extracted with confidence it is left as ``None`` and the caller decides
whether to auto-verify or leave the claim pending for manual review.

OCR of scanned (image-only) transcripts is NOT supported here because tesseract
is not installed in this environment; only text-based PDFs and QR codes are
handled. Install tesseract + pytesseract to extend coverage.
"""

from __future__ import annotations

import re
import subprocess
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

from pdf2image import convert_from_bytes
from PIL import Image
from pyzbar.pyzbar import decode as decode_qr


@dataclass
class TranscriptParseResult:
    qr_data: str | None = None
    qr_valid: bool = False
    course_codes: list[str] = field(default_factory=list)
    grades: list[str] = field(default_factory=list)
    raw_text: str = ""
    error: str | None = None


# Regex for a MUST-style course code: 2-4 letters followed by 4 digits.
_CODE_RE = re.compile(r"\b([A-Z]{2,4}\d{4})\b")

# Common grade labels on MUST's 5-point scale.
_GRADE_RE = re.compile(r"\b(A|B\+|B|C\+|C|D\+|D|F)\b")


def _ocr_available() -> bool:
    """Whether the tesseract binary is installed."""
    import shutil

    return shutil.which("tesseract") is not None


_MUST_QR_MARKERS = ("MUST", "must.ac.ug", "mbarara")


def _ocr_image(image: Image.Image) -> str:
    if not _ocr_available():
        return ""
    try:
        import pytesseract

        return pytesseract.image_to_string(image) or ""
    except Exception:
        return ""


def _extract_qr(image: Image.Image) -> str | None:
    try:
        results = decode_qr(image)
    except Exception:
        return None
    for r in results:
        try:
            return r.data.decode("utf-8", errors="replace")
        except Exception:
            continue
    return None


def _qr_is_must(qr: str | None) -> bool:
    if not qr:
        return False
    low = qr.lower()
    return any(m.lower() in low for m in _MUST_QR_MARKERS)


def parse_transcript(
    data: bytes, content_type: str, filename: str
) -> TranscriptParseResult:
    """Parse a transcript file. Returns a best-effort result."""
    result = TranscriptParseResult()
    suffix = Path(filename).suffix.lower()

    # --- PDF path -----------------------------------------------------------
    if suffix == ".pdf" or "pdf" in (content_type or "").lower():
        # text extraction via pdftotext (poppler)
        try:
            with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
                tmp.write(data)
                tmp_path = tmp.name
            out = subprocess.run(
                ["pdftotext", "-layout", tmp_path, "-"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            result.raw_text = out.stdout or ""
            # QR from first page
            try:
                images = convert_from_bytes(data, first_page=1, last_page=1)
                if images:
                    qr = _extract_qr(images[0])
                    result.qr_data = qr
                    result.qr_valid = _qr_is_must(qr)
                    # OCR fallback for scanned (image-only) PDFs
                    if not result.raw_text.strip() and _ocr_available():
                        result.raw_text = _ocr_image(images[0])
            except Exception as exc:
                result.error = f"qr extraction failed: {exc}"
            Path(tmp_path).unlink(missing_ok=True)
        except Exception as exc:
            result.error = f"pdf parse failed: {exc}"
            return result
    else:
        # --- image path -----------------------------------------------------
        try:
            from io import BytesIO

            img = Image.open(BytesIO(data))
            qr = _extract_qr(img)
            result.qr_data = qr
            result.qr_valid = _qr_is_must(qr)
            # OCR for scanned images when tesseract is available
            if _ocr_available():
                result.raw_text = _ocr_image(img)
        except Exception as exc:
            result.error = f"image parse failed: {exc}"
            return result

    result.course_codes = list(dict.fromkeys(_CODE_RE.findall(result.raw_text)))
    result.grades = _GRADE_RE.findall(result.raw_text)
    return result
