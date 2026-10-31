"""Object storage for transcript / QR evidence.

Backed by Firebase Storage when configured, then Supabase Storage (free tier),
then the local filesystem (zero cost). Files are never exposed via public URLs:
``evidence_reference`` stores an opaque object key, and clients fetch bytes
through the authenticated ``GET /competencies/{id}/evidence`` endpoint.
"""

from __future__ import annotations

import os
from pathlib import Path

from fastapi import UploadFile

from app.core.exceptions import ValidationProblem

_firebase_app = None


def _firebase_ready() -> bool:
    global _firebase_app
    if _firebase_app is not None:
        return True
    creds_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
    bucket = os.getenv("FIREBASE_STORAGE_BUCKET")
    if not creds_path or not bucket:
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(creds_path)
        _firebase_app = firebase_admin.initialize_app(cred, {"storageBucket": bucket})
        return True
    except Exception:
        _firebase_app = None
        return False


def _supabase_ready() -> bool:
    return bool(
        os.getenv("SUPABASE_URL")
        and os.getenv("SUPABASE_SERVICE_KEY")
        and os.getenv("SUPABASE_STORAGE_BUCKET")
    )


def _local_dir() -> Path:
    return Path(os.getenv("LOCAL_STORAGE_DIR", "uploads")).resolve()


def upload_transcript(upload: UploadFile, object_key: str) -> str:
    """Store a transcript/QR file and return its object key (not a public URL)."""
    if _firebase_ready():
        try:
            from firebase_admin import storage

            bucket = storage.bucket()
            blob = bucket.blob(object_key)
            upload.file.seek(0)
            blob.upload_from_file(upload.file, content_type=upload.content_type)
            return object_key
        except Exception as exc:
            raise ValidationProblem(
                "Could not store the transcript.",
                errors={"evidence": str(exc)},
            ) from exc

    if _supabase_ready():
        try:
            url = os.getenv("SUPABASE_URL", "").rstrip("/")
            key = os.getenv("SUPABASE_SERVICE_KEY", "")
            bucket = os.getenv("SUPABASE_STORAGE_BUCKET", "")
            from supabase import create_client

            client = create_client(url, key)
            upload.file.seek(0)
            data = upload.file.read()
            client.storage.from_(bucket).upload(
                object_key,
                data,
                file_options={
                    "content-type": upload.content_type or "application/octet-stream"
                },
            )
            return object_key
        except Exception as exc:
            raise ValidationProblem(
                "Could not store the transcript.",
                errors={"evidence": str(exc)},
            ) from exc

    # --- local filesystem fallback (zero cost) ---
    try:
        dest = _local_dir() / object_key
        dest.parent.mkdir(parents=True, exist_ok=True)
        upload.file.seek(0)
        with dest.open("wb") as fh:
            import shutil

            shutil.copyfileobj(upload.file, fh)
        return object_key
    except Exception as exc:
        raise ValidationProblem(
            "Could not store the transcript.",
            errors={"evidence": str(exc)},
        ) from exc


def download_transcript(object_key: str) -> tuple[bytes, str]:
    """Return (bytes, content_type) for a stored transcript. Raises on failure."""
    if _firebase_ready():
        try:
            from firebase_admin import storage

            blob = storage.bucket().blob(object_key)
            data = blob.download_as_bytes()
            ct = blob.content_type or "application/octet-stream"
            return data, ct
        except Exception as exc:
            raise ValidationProblem(
                "Could not read the transcript.",
                errors={"evidence": str(exc)},
            ) from exc

    if _supabase_ready():
        try:
            url = os.getenv("SUPABASE_URL", "").rstrip("/")
            key = os.getenv("SUPABASE_SERVICE_KEY", "")
            bucket = os.getenv("SUPABASE_STORAGE_BUCKET", "")
            from supabase import create_client

            client = create_client(url, key)
            data = client.storage.from_(bucket).download(object_key)
            return data, "application/octet-stream"
        except Exception as exc:
            raise ValidationProblem(
                "Could not read the transcript.",
                errors={"evidence": str(exc)},
            ) from exc

    # --- local filesystem fallback ---
    try:
        dest = _local_dir() / object_key
        data = dest.read_bytes()
        return data, "application/octet-stream"
    except Exception as exc:
        raise ValidationProblem(
            "Could not read the transcript.",
            errors={"evidence": str(exc)},
        ) from exc


def is_available() -> bool:
    return True
