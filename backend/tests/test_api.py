"""Broker API tests with fake auth and a fake object store (no network)."""

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app import main
from app.auth import CurrentUser, TokenVerifier, get_verifier, rate_limiter
from app.config import Settings, get_settings

OID = "123e4567-e89b-42d3-a456-426614174000"
SHA = "a" * 64


class FakeVerifier(TokenVerifier):
    def __init__(self):
        pass

    def verify_id_token(self, token):
        if token == "alice":
            return CurrentUser("aliceUid", True)
        if token == "unverified":
            return CurrentUser("bobUid", False)
        raise HTTPException(401, "bad")

    def verify_app_check(self, token):
        if token != "ok":
            raise HTTPException(401, "bad app check")


class FakeStore:
    def __init__(self):
        self.objects = {f"users/aliceUid/attachment/{OID}", f"users/eveUid/attachment/{OID}"}
        self.deleted = []

    def presign_put(self, key, size, ttl):
        return f"https://r2.example/{key}?sig&len={size}", {"Content-Type": "application/octet-stream"}

    def presign_get(self, key, ttl):
        return f"https://r2.example/{key}?sig"

    def exists(self, key):
        return key in self.objects

    def delete(self, key):
        self.deleted.append(key)

    def delete_prefix(self, prefix):
        hit = [k for k in self.objects if k.startswith(prefix)]
        self.deleted.extend(hit)
        return len(hit)


@pytest.fixture
def ctx():
    store = FakeStore()
    settings = Settings(r2_account_id="x", r2_access_key_id="x", r2_secret_access_key="x", max_attachment_bytes=1000)
    main.app.dependency_overrides[get_settings] = lambda: settings
    main.app.dependency_overrides[get_verifier] = lambda: FakeVerifier()
    main.app.dependency_overrides[main.get_store] = lambda: store
    rate_limiter._hits.clear()
    yield TestClient(main.app), store, settings
    main.app.dependency_overrides.clear()


H = {"Authorization": "Bearer alice"}


def test_root_health_unchanged(ctx):
    client, _, _ = ctx
    assert client.get("/").json() == "Hi"


def test_requires_auth(ctx):
    client, _, _ = ctx
    assert client.post("/v1/storage/upload-url", json={}).status_code in (401, 422)
    r = client.post("/v1/storage/upload-url", json={"kind": "attachment", "objectId": OID, "size": 10, "sha256": SHA})
    assert r.status_code == 401
    r = client.post("/v1/storage/upload-url", headers={"Authorization": "Bearer nope"},
                    json={"kind": "attachment", "objectId": OID, "size": 10, "sha256": SHA})
    assert r.status_code == 401


def test_unverified_email_rejected(ctx):
    client, _, _ = ctx
    r = client.post("/v1/storage/upload-url", headers={"Authorization": "Bearer unverified"},
                    json={"kind": "attachment", "objectId": OID, "size": 10, "sha256": SHA})
    assert r.status_code == 403


def test_upload_key_is_scoped_to_caller(ctx):
    client, _, _ = ctx
    r = client.post("/v1/storage/upload-url", headers=H, json={"kind": "attachment", "objectId": OID, "size": 10, "sha256": SHA})
    assert r.status_code == 200
    assert f"users/aliceUid/attachment/{OID}" in r.json()["url"]


@pytest.mark.parametrize("oid", ["../eveUid/attachment/x", "ABC", OID.upper(), f"{OID}/../../x"])
def test_path_traversal_rejected(ctx, oid):
    client, _, _ = ctx
    r = client.post("/v1/storage/download-url", headers=H, json={"kind": "attachment", "objectId": oid})
    assert r.status_code == 422


def test_size_limit_and_checksum_format(ctx):
    client, _, _ = ctx
    r = client.post("/v1/storage/upload-url", headers=H, json={"kind": "attachment", "objectId": OID, "size": 5000, "sha256": SHA})
    assert r.status_code == 413
    r = client.post("/v1/storage/upload-url", headers=H, json={"kind": "attachment", "objectId": OID, "size": 10, "sha256": "zz"})
    assert r.status_code == 422


def test_download_only_own_objects(ctx):
    client, _, _ = ctx
    r = client.post("/v1/storage/download-url", headers=H, json={"kind": "attachment", "objectId": OID})
    assert r.status_code == 200 and "users/aliceUid/" in r.json()["url"]
    r = client.post("/v1/storage/download-url", headers=H, json={"kind": "backup", "objectId": OID})
    assert r.status_code == 404


def test_purge_only_touches_caller(ctx):
    client, store, _ = ctx
    assert client.post("/v1/account/purge-objects", headers=H, json={"confirm": False}).status_code == 400
    r = client.post("/v1/account/purge-objects", headers=H, json={"confirm": True})
    assert r.json()["deleted"] == 1
    assert all(k.startswith("users/aliceUid/") for k in store.deleted)


def test_app_check_enforced_when_enabled(ctx):
    client, _, settings = ctx
    settings.require_app_check = True
    body = {"kind": "attachment", "objectId": OID, "size": 10, "sha256": SHA}
    assert client.post("/v1/storage/upload-url", headers=H, json=body).status_code == 401
    assert client.post("/v1/storage/upload-url", headers={**H, "X-Firebase-AppCheck": "bad"}, json=body).status_code == 401
    assert client.post("/v1/storage/upload-url", headers={**H, "X-Firebase-AppCheck": "ok"}, json=body).status_code == 200


def test_rate_limit(ctx):
    client, _, settings = ctx
    settings.rate_limit_per_minute = 3
    body = {"kind": "attachment", "objectId": OID}
    codes = [client.post("/v1/storage/download-url", headers=H, json=body).status_code for _ in range(5)]
    assert codes[:3] == [200, 200, 200] and codes[3:] == [429, 429]
