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
    from app.core.config import get_settings

    return Path(get_settings().local_storage_dir).resolve()


def upload_transcript(upload: UploadFile, object_key: str) -> str:
    """Store a transcript/QR file and return its object key (not a public URL).

    Returns a prefixed key such as ``firebase:...``, ``supabase:...``, or
    ``local:...`` so downloads always use the same backend that received the
    file instead of silently switching backends.
    """
    # Track which backend receives the file to avoid silent switching
    if _firebase_ready():
        try:
            from firebase_admin import storage

            bucket = storage.bucket()
            blob = bucket.blob(object_key)
            upload.file.seek(0)
            blob.upload_from_file(upload.file, content_type=upload.content_type)
            return f"firebase:{object_key}"
        except Exception as exc:
            # Fail explicitly instead of silently switching backends
            raise ValidationProblem(
                "Could not store the transcript (Firebase).",
                errors={"evidence": str(exc)},
            ) from exc

    if _supabase_ready():
        try:
            url = os.getenv("SUPABASE_URL", "").rstrip("/")
            key = os.getenv("SUPABASE_SERVICE_KEY", "")
            bucket_name = os.getenv("SUPABASE_STORAGE_BUCKET", "")
            from supabase import create_client

            client = create_client(url, key)
            upload.file.seek(0)
            data = upload.file.read()
            client.storage.from_(bucket_name).upload(
                object_key,
                data,
                file_options={
                    "content-type": upload.content_type or "application/octet-stream"
                },
            )
            return f"supabase:{object_key}"
        except Exception as exc:
            raise ValidationProblem(
                "Could not store the transcript (Supabase).",
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
        return f"local:{object_key}"
    except Exception as exc:
        raise ValidationProblem(
            "Could not store the transcript (local).",
            errors={"evidence": str(exc)},
        ) from exc


def download_transcript(object_key: str) -> tuple[bytes, str]:
    """Return (bytes, content_type) for a stored transcript. Raises on failure."""
    # Parse backend prefix to avoid silent switching
    if object_key.startswith("firebase:"):
        backend = "firebase"
        object_key = object_key[len("firebase:") :]
    elif object_key.startswith("supabase:"):
        backend = "supabase"
        object_key = object_key[len("supabase:") :]
    elif object_key.startswith("local:"):
        backend = "local"
        object_key = object_key[len("local:") :]
    else:
        # No prefix: legacy object key, try backends in order
        backend = None

    if backend == "firebase" or (backend is None and _firebase_ready()):
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

    if backend == "supabase" or (backend is None and _supabase_ready()):
        try:
            url = os.getenv("SUPABASE_URL", "").rstrip("/")
            key = os.getenv("SUPABASE_SERVICE_KEY", "")
            bucket_name = os.getenv("SUPABASE_STORAGE_BUCKET", "")
            from supabase import create_client

            client = create_client(url, key)
            data = client.storage.from_(bucket_name).download(object_key)
            return data, "application/octet-stream"
        except Exception as exc:
            raise ValidationProblem(
                "Could not read the transcript.",
                errors={"evidence": str(exc)},
            ) from exc

    # --- local filesystem fallback ---
    if backend == "local" or backend is None:
        try:
            dest = _local_dir() / object_key
            data = dest.read_bytes()
            return data, "application/octet-stream"
        except Exception as exc:
            raise ValidationProblem(
                "Could not read the transcript.",
                errors={"evidence": str(exc)},
            ) from exc

    raise ValidationProblem(
        "Could not read the transcript.",
        errors={"evidence": "No matching storage backend found"},
    )


def is_available() -> bool:
    return True
