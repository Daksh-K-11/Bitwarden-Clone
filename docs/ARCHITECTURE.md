# Architecture

## Layers (feature-first)

```
lib/
  app/            composition root: bootstrap, providers, router, theme, auto-lock, shared widgets
  core/
    crypto/       libsodium facade, envelope format, AAD, KDF params, key hierarchy   (no I/O)
    db/           Drift schema on SQLCipher
    storage/      OS secure storage
    platform/     Dart side of the Android security channel (Keystore biometrics, clipboard, FLAG_SECURE)
    clipboard/    auto-clearing clipboard
    cloud/        provider-neutral interfaces + Firebase/Firestore/R2 implementations
    config/       settings model, filesystem layout
  features/
    session/      lock state machine, unlock methods (password / biometric / PIN)
    account/      sign-up/in, vault setup, password change, key rotation, logout, deletion
    vault/        domain (item templates, models) · data (codec, repository) · application (controller, search) · presentation
    totp/ generator/ security_health/ folders/ attachments/ backup/ sync/ devices/ settings/ onboarding/
```

* **Domain** (`vault/domain`): 15 item types defined declaratively as field
  templates (`FieldSpec`: kind, sensitive, searchable, warnings). One generic
  editor and one detail view render every type; adding a type is a data change.
  Every item also has custom fields (8 types, reorderable), notes, URLs, TOTP,
  attachments, tags, folder, favourite, archive, trash and password history.
* **Data**: `RecordCodec` turns models into AAD-bound ciphertext; `VaultRepository`
  persists ciphertext locally and marks rows dirty. It never touches the network.
* **Application**: Riverpod `Notifier`s. `VaultController` owns the decrypted
  snapshot + in-memory search index while unlocked and rebuilds empty on lock.
* **Cloud**: `AuthRepository`, `RemoteVaultStore`, `ObjectStorage` interfaces.
  Firebase/R2 are implementations selected at bootstrap; with no config the
  unavailable implementations are used and the app is offline-only.
* State management: Riverpod 3 with hand-written providers. (`riverpod_generator`
  could not be used: its analyzer requirement conflicts with `drift_dev`.)

## Local-first data flow

```
UI ─▶ VaultController ─▶ VaultRepository ─▶ SQLCipher (dirty=1)
                                   └─ changes stream ─▶ SyncController (debounced) ─▶ SyncEngine ─▶ Firestore
```

All reads, searches and edits are local and work offline. The cloud is the
synchronisation source of truth; the local DB is an encrypted cache + outbox.

## Sync protocol

* `users/{uid}/records/{id}`: `{kind, v, payload(bytes), rev, deleted, kg, createdAt, updatedAt(server), deviceId}`
* **Push**: for each dirty row, a transaction reads the server doc and writes
  `rev = base+1` only if the server is still at `base` (also enforced by rules).
  Lost responses are recognised on retry (same device + same ciphertext at
  `base+1` → already applied). Dirty rows coalesce repeated offline edits.
* **Pull**: query ordered by `(updatedAt, documentId)` after the stored cursor,
  300 per page. Remote records are authenticated (decrypted) before acceptance.
* **Conflicts** (local dirty, remote advanced):
  * items edited on both sides → remote applied, local copy stored encrypted in
    `sync_conflicts`; user picks *keep mine / keep theirs / keep both*;
  * edited here, deleted there → edit wins (data-preserving);
  * deleted here, edited there → edited version restored;
  * folders/tags → last writer by encrypted `updatedAt`.
* **Rollback/replay**: remote item with lower encrypted `seq` than local is rejected.
* **Key changes**: password change elsewhere → new wrapped VEK adopted; key
  rotation elsewhere (`keyGeneration` up) → lock and require master password.
* **Device state**: revoked → wipe local data and sign out. Missing device record
  → re-register (rules require it for writes).
* Triggers: unlock, 3 s after edits, connectivity regained, app resume,
  pull-to-refresh, every 15 min in the foreground. No realtime listeners.

## Attachments

Random per-file key → secretstream → `attachments/<id>.bin` (atomic rename) →
SHA-256 recorded → upload to R2 via presigned PUT when online. Metadata and the
wrapped file key live inside the encrypted item. Downloads are verified
(SHA-256, then per-chunk authentication) before display. Deletions are queued
and performed against R2 on the next sync.

## Cost & scalability (Firestore / R2)

Approximate per-operation costs, useful for watching free-tier quotas
(Spark: 50k reads, 20k writes, 20k deletes per day, 1 GiB stored; R2 free tier:
10 GB-month storage, 1M Class A and 10M Class B ops per month, free egress):

| Action | Firestore | R2 |
|---|---|---|
| Sync with no changes | 2 reads (device + keys) + 1 query read | – |
| Pull N changed records | N reads (min 1 per query) | – |
| Push one edit | 1 transaction read + 1 write + 1 rules `get` (device check) | – |
| Device "last active" | ≤1 write / hour | – |
| Add attachment | (item edit) | 1 Class A (PUT) |
| Open attachment on another device | – | 1 Class B (GET) |
| Daily cloud backup | 1 write | 1 Class A, size of vault |

Design choices that keep this low: one `records` collection (one incremental
query instead of three), debounced pushes, no snapshot listeners, Firestore cache
disabled (no duplicate reads on restart), `payload` excluded from indexing,
throttled device heartbeats, tombstones instead of re-scans.

Keep each payload < 1 MB (rules cap it at 1,000,000 bytes); large content
belongs in attachments.

## Swapping providers

The crypto layer is independent of Firebase (AAD uses the vault id, not the
Firebase uid), so moving to another backend means implementing
`RemoteVaultStore` / `AuthRepository` / `ObjectStorage`; users' ciphertext can
be copied as-is without re-encryption.
