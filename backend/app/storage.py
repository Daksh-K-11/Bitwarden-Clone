"""Cloudflare R2 access (S3-compatible API) behind a small interface so the
object store can be swapped without touching the API layer."""

from __future__ import annotations

from typing import Protocol

from .config import Settings


class ObjectStore(Protocol):
    def presign_put(self, key: str, size: int, ttl: int) -> tuple[str, dict[str, str]]: ...
    def presign_get(self, key: str, ttl: int) -> str: ...
    def exists(self, key: str) -> bool: ...
    def delete(self, key: str) -> None: ...
    def delete_prefix(self, prefix: str) -> int: ...


class R2Store:
    def __init__(self, settings: Settings):
        import boto3
        from botocore.config import Config

        self.bucket = settings.r2_bucket
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.r2_endpoint,
            aws_access_key_id=settings.r2_access_key_id,
            aws_secret_access_key=settings.r2_secret_access_key,
            region_name="auto",
            config=Config(signature_version="s3v4", retries={"max_attempts": 3, "mode": "standard"}),
        )

    def presign_put(self, key: str, size: int, ttl: int) -> tuple[str, dict[str, str]]:
        # Content-Length and Content-Type are part of the signature, so the
        # client cannot upload more than the size it declared.
        headers = {"Content-Type": "application/octet-stream"}
        url = self.client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": self.bucket,
                "Key": key,
                "ContentLength": size,
                "ContentType": headers["Content-Type"],
            },
            ExpiresIn=ttl,
            HttpMethod="PUT",
        )
        return url, headers

    def presign_get(self, key: str, ttl: int) -> str:
        return self.client.generate_presigned_url(
            "get_object", Params={"Bucket": self.bucket, "Key": key}, ExpiresIn=ttl, HttpMethod="GET"
        )

    def exists(self, key: str) -> bool:
        from botocore.exceptions import ClientError

        try:
            self.client.head_object(Bucket=self.bucket, Key=key)
            return True
        except ClientError:
            return False

    def delete(self, key: str) -> None:
        self.client.delete_object(Bucket=self.bucket, Key=key)

    def delete_prefix(self, prefix: str) -> int:
        deleted = 0
        paginator = self.client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=self.bucket, Prefix=prefix):
            keys = [{"Key": o["Key"]} for o in page.get("Contents", [])]
            for i in range(0, len(keys), 1000):
                chunk = keys[i : i + 1000]
                self.client.delete_objects(Bucket=self.bucket, Delete={"Objects": chunk, "Quiet": True})
                deleted += len(chunk)
        # Abort any unfinished multipart uploads under the prefix.
        uploads = self.client.list_multipart_uploads(Bucket=self.bucket, Prefix=prefix).get("Uploads", [])
        for u in uploads:
            self.client.abort_multipart_upload(Bucket=self.bucket, Key=u["Key"], UploadId=u["UploadId"])
        return deleted
