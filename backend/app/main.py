"""Citadel storage broker.

Issues short-lived, single-object presigned URLs for Cloudflare R2 so the
mobile app never holds storage credentials. Everything uploaded through these
URLs is already end-to-end encrypted on the device; this service never sees
plaintext, vault keys or master passwords, and never proxies object bytes.

Object keys are always derived server-side: users/{firebase uid}/{kind}/{uuid}
"""

from __future__ import annotations

import logging
import re
from enum import Enum
from functools import lru_cache

from fastapi import Depends, FastAPI, HTTPException, status
from pydantic import BaseModel, Field

from .auth import CurrentUser, current_user
from .config import Settings, get_settings
from .storage import ObjectStore, R2Store

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("citadel.api")

app = FastAPI(title="Citadel storage broker", version="1.0.0", docs_url=None, redoc_url=None, openapi_url=None)

_UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")


class ObjectKind(str, Enum):
    attachment = "attachment"
    backup = "backup"


@lru_cache
def _r2(settings_id: int) -> R2Store:  # cache per settings instance
    return R2Store(get_settings())


def get_store(settings: Settings = Depends(get_settings)) -> ObjectStore:
    if not settings.r2_configured:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Object storage is not configured")
    return _r2(id(settings))


def object_key(uid: str, kind: ObjectKind, object_id: str) -> str:
    if not _UUID.match(object_id):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "objectId must be a lowercase UUID")
    if not re.fullmatch(r"[A-Za-z0-9]{1,128}", uid):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unexpected user id")
    return f"users/{uid}/{kind.value}/{object_id}"


class UploadRequest(BaseModel):
    kind: ObjectKind
    objectId: str
    size: int = Field(gt=0)
    sha256: str


class ObjectRequest(BaseModel):
    kind: ObjectKind
    objectId: str


class PurgeRequest(BaseModel):
    confirm: bool


@app.get("/")
def health():
    return "Hi"


@app.get("/healthz")
def healthz(settings: Settings = Depends(get_settings)):
    return {"status": "ok", "storage": settings.r2_configured}


@app.post("/v1/storage/upload-url")
def upload_url(
    req: UploadRequest,
    user: CurrentUser = Depends(current_user),
    settings: Settings = Depends(get_settings),
    store: ObjectStore = Depends(get_store),
):
    limit = settings.max_attachment_bytes if req.kind is ObjectKind.attachment else settings.max_backup_bytes
    if req.size > limit:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Object too large")
    if not _SHA256.match(req.sha256):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "sha256 must be 64 lowercase hex chars")
    key = object_key(user.uid, req.kind, req.objectId)
    url, headers = store.presign_put(key, req.size, settings.url_ttl_seconds)
    log.info("upload grant uid=%s kind=%s size=%d", user.uid, req.kind.value, req.size)
    return {"url": url, "headers": headers, "expiresIn": settings.url_ttl_seconds}


@app.post("/v1/storage/download-url")
def download_url(
    req: ObjectRequest,
    user: CurrentUser = Depends(current_user),
    settings: Settings = Depends(get_settings),
    store: ObjectStore = Depends(get_store),
):
    key = object_key(user.uid, req.kind, req.objectId)
    if not store.exists(key):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Object not found")
    return {"url": store.presign_get(key, settings.url_ttl_seconds), "expiresIn": settings.url_ttl_seconds}


@app.post("/v1/storage/delete")
def delete_object(
    req: ObjectRequest,
    user: CurrentUser = Depends(current_user),
    store: ObjectStore = Depends(get_store),
):
    store.delete(object_key(user.uid, req.kind, req.objectId))
    log.info("delete uid=%s kind=%s", user.uid, req.kind.value)
    return {"deleted": True}


@app.post("/v1/account/purge-objects")
def purge_objects(
    req: PurgeRequest,
    user: CurrentUser = Depends(current_user),
    store: ObjectStore = Depends(get_store),
):
    """Deletes every object of the calling user (account deletion)."""
    if not req.confirm:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Confirmation required")
    count = store.delete_prefix(f"users/{user.uid}/")
    log.info("purge uid=%s objects=%d", user.uid, count)
    return {"deleted": count}
