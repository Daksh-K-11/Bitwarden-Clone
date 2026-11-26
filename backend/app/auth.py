"""Firebase ID-token (and optional App Check) verification.

The broker never sees vault data or the master password - only the user's
Firebase identity, which scopes every object key to `users/{uid}/...`.
"""

from __future__ import annotations

import logging
import threading
import time
from dataclasses import dataclass

from fastapi import Depends, Header, HTTPException, status

from .config import Settings, get_settings

log = logging.getLogger("citadel.auth")

_firebase_lock = threading.Lock()
_firebase_ready = False


def _ensure_firebase(settings: Settings) -> None:
    global _firebase_ready
    if _firebase_ready:
        return
    with _firebase_lock:
        if _firebase_ready:
            return
        import firebase_admin

        options = {"projectId": settings.firebase_project_id} if settings.firebase_project_id else None
        firebase_admin.initialize_app(options=options)
        _firebase_ready = True


@dataclass(frozen=True)
class CurrentUser:
    uid: str
    email_verified: bool


class TokenVerifier:
    """Verifies Firebase ID tokens. Replaced by a fake in tests."""

    def __init__(self, settings: Settings):
        self.settings = settings

    def verify_id_token(self, token: str) -> CurrentUser:
        _ensure_firebase(self.settings)
        from firebase_admin import auth

        try:
            # check_revoked=True: tokens of signed-out/disabled users or users
            # whose sessions were revoked are refused.
            claims = auth.verify_id_token(token, check_revoked=True)
        except Exception as exc:  # noqa: BLE001 - never echo token details
            log.info("id token rejected: %s", type(exc).__name__)
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired credentials") from None
        return CurrentUser(uid=claims["uid"], email_verified=bool(claims.get("email_verified")))

    def verify_app_check(self, token: str) -> None:
        _ensure_firebase(self.settings)
        from firebase_admin import app_check

        try:
            app_check.verify_token(token)
        except Exception as exc:  # noqa: BLE001
            log.info("app check rejected: %s", type(exc).__name__)
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "App verification failed") from None


def get_verifier(settings: Settings = Depends(get_settings)) -> TokenVerifier:
    return TokenVerifier(settings)


class RateLimiter:
    """Tiny in-memory sliding-window limiter (per process). Put a real
    edge rate limit (Cloudflare / API gateway) in front in production."""

    def __init__(self) -> None:
        self._hits: dict[str, list[float]] = {}
        self._lock = threading.Lock()

    def check(self, key: str, limit: int) -> None:
        now = time.monotonic()
        with self._lock:
            hits = [t for t in self._hits.get(key, []) if now - t < 60]
            if len(hits) >= limit:
                raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "Too many requests")
            hits.append(now)
            self._hits[key] = hits


rate_limiter = RateLimiter()


def current_user(
    authorization: str | None = Header(default=None),
    x_firebase_appcheck: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
    verifier: TokenVerifier = Depends(get_verifier),
) -> CurrentUser:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    user = verifier.verify_id_token(authorization.removeprefix("Bearer ").strip())
    if settings.require_email_verified and not user.email_verified:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Email address not verified")
    if settings.require_app_check:
        if not x_firebase_appcheck:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing App Check token")
        verifier.verify_app_check(x_firebase_appcheck)
    rate_limiter.check(user.uid, settings.rate_limit_per_minute)
    return user
