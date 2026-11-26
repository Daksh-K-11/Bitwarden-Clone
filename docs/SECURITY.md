# Citadel security model

Citadel is a zero-knowledge, end-to-end encrypted password and secrets manager.
This document describes what is protected, how, and — just as importantly —
what is **not** protected.

## 1. Threat model

| Adversary | Protected? |
|---|---|
| Cloud provider / server operator (Firebase, Cloudflare R2, broker API) reading vault data | **Yes** — only ciphertext and minimal sync metadata are ever uploaded. |
| Network attacker | **Yes** — TLS plus end-to-end encryption (HTTPS alone is *not* relied on). |
| Malicious server tampering with ciphertext (swap, move, replay, downgrade) | **Detected** — AAD binding, monotonic `seq`, envelope versioning, KDF bounds. |
| Stolen / lost locked phone | **Yes** — vault data needs the master password (or a hardware-released key). SQLCipher protects metadata at rest. |
| Malware with root on an *unlocked* device, or a compromised OS | **No** — no app can defend against this. |
| Someone who knows your master password | **No.** |
| You forgetting the master password | **No recovery** (see §9). |

## 2. Primitives (all from libsodium 1.0.22, audited, via FFI)

| Purpose | Primitive |
|---|---|
| Password KDF | Argon2id (`crypto_pwhash`, ALG_ARGON2ID13), 16-byte random salt per vault |
| Record encryption | XChaCha20-Poly1305-IETF, 192-bit random nonce per encryption |
| Subkeys | HKDF-SHA-256 expand (`crypto_kdf_hkdf_sha256`) with distinct contexts |
| Files / backups | secretstream XChaCha20-Poly1305 (64 KiB authenticated chunks, FINAL tag) |
| Device identity | Ed25519 (`crypto_sign`) |
| Key delivery to devices | X25519 sealed boxes (`crypto_box_seal`) |
| Randomness | `randombytes_buf` / `randombytes_uniform` (OS CSPRNG, unbiased) |

No primitive is implemented by hand. TOTP uses HMAC-SHA1/256/512 from
`package:crypto` (dart-lang) — TOTP itself is a protocol, not a cipher.

Keys live in `SecureKey` buffers (sodium_malloc: guard pages, mlock,
PROT_NOACCESS while idle, zeroed on dispose). Dart `String`s (e.g. a password
typed into a text field) cannot be wiped; this is a platform limitation.

### Argon2id parameters

Defaults to **64 MiB, 3 iterations** (measured ~420 ms on a Samsung M34).
Presets: 128 MiB/4, 256 MiB/4. OWASP minimums for Argon2id (m=19 MiB/t=2 or
m=46 MiB/t=1) are exceeded. Parameters loaded from storage or the cloud are
validated against hard bounds (ops 2–10, 19 MiB–1 GiB) so a tampered profile
can neither weaken derivation nor exhaust device memory.

## 3. Key hierarchy

```
master password ──Argon2id(salt, ops, mem)──▶ MK (32 B, never stored)
                                             └─HKDF "citadel/v1/kek"──▶ KEK (never stored)
                                                                          │ wraps
CSPRNG ──────────────────────────────────────────────────────────▶ VEK (32 B, stored only wrapped)
                                                                          │ HKDF
          ┌───────────────────┬────────────────────┬───────────────────┬──┴──────────────┐
      records key      attachment wrap key      backup key        conflict key
```

* Stored: `{vaultId, kdf params, salt, wrappedVek, keyGeneration}` (no secrets).
* **Change master password** — new salt, new KEK, re-wrap the same VEK. O(1); no
  item re-encryption. Other devices pick up the new wrapped VEK on next sync.
  Old backups still open with the password that was current when they were made.
* **Rotate vault key** (Settings › Rotate) — new VEK; every record re-encrypted,
  every attachment file key re-wrapped, `keyGeneration` incremented. Other
  devices detect the higher generation and require the master password.
  Biometric/PIN unlock is reset because those wrap the old VEK. Attachment
  *contents* keep their per-file keys (only the wrapping changes); if you
  believe file keys themselves leaked, re-upload those attachments.
* Firebase account password ≠ master password. Firebase identifies the account;
  the master password derives the key. Neither the master password, KEK nor
  VEK is ever sent anywhere.

## 4. Record format and AAD

Every encrypted value is an envelope `version(1) | alg(1) | nonce(24) | ct||tag`.
The two header bytes are part of the AAD (no algorithm/version confusion).
Records additionally bind `citadel:v1|record|<kind>|<vaultId>|<recordId>` as AAD,
and the decrypted JSON's `id` is re-checked. Consequences, all covered by tests:

* ciphertext moved to another record id, kind or vault → authentication failure;
* any flipped bit → failure; truncated files/backups → failure;
* a server replaying an *older* valid ciphertext under a new revision is rejected
  via the encrypted monotonic `seq` counter (rollback protection).

What the server can see: record ids (random UUIDs), kind (item/folder/tag),
revision numbers, timestamps, ciphertext sizes, device ids, and the number of
records. Names, URLs, usernames, item types, folders, tags, favourites, trash
state, attachment names/types/sizes are all inside the ciphertext.

## 5. Local storage

* **SQLCipher 4.x** (raw 256-bit key, `cipher_memory_security=ON`,
  `secure_delete=ON`, `temp_store=MEMORY`, WAL pages are encrypted too). The app
  refuses to start on a SQLite build without SQLCipher. The DB key is random per
  install and kept in Keystore-backed secure storage, independent of the VEK, so
  ciphertext can sync while the vault is locked — every sensitive record inside
  is additionally VEK-encrypted.
* `flutter_secure_storage` (Android: AES-GCM, Keystore-wrapped key) holds the
  wrapped VEK material, DB key, PIN/biometric blobs and device identity keys,
  with `resetOnError: false` (the plugin default would silently wipe storage on a
  Keystore error — catastrophic for a vault).
* `android:allowBackup=false` + data-extraction rules: app data is excluded from
  Google cloud backup and device-to-device transfer.
* Decrypted attachment previews are held **in memory**; the only plaintext
  directory (`cache/citadel_previews`) is overwritten and deleted on lock and
  on start. Plaintext exports are written straight to the location you pick via
  the system file dialog and never staged in a temp file.
* The search index exists only in memory while unlocked and never includes
  passwords, card numbers/CVVs, private keys, recovery phrases, TOTP secrets,
  hidden custom fields, or (unless enabled) notes.

## 6. Unlock methods

* **Master password** — always available. Exponential back-off after 5 failures
  (persisted across restarts) on top of Argon2id cost.
* **Biometrics / device credential (Android)** — an AES-256-GCM key in the
  Android Keystore (StrongBox when present) created with
  `setUserAuthenticationRequired(true)`, per-use authentication and
  `setInvalidatedByBiometricEnrollment(true)`. The VEK is wrapped by it and the
  OS only performs the decryption inside a successful `BiometricPrompt` bound to
  a `CryptoObject`. Biometrics therefore *release a key*; patching the app to skip
  the prompt yields nothing. Re-enrolling a fingerprint invalidates the key.
  Only Class 3 ("strong") biometrics can do this — many Samsung face-unlock
  implementations are Class 2 and will not be offered.
* **App PIN** — VEK wrapped by Argon2id(PIN, device salt). The blob never leaves
  the device and is deleted after 5 wrong PINs. A 4–6 digit PIN is low-entropy:
  its protection relies on the blob staying inside Keystore-backed storage.
* `local_auth` is used as an extra *UX gate* (re-prompt items, card details,
  revoking devices) on top of an already-unlocked vault.

Auto-lock: inactivity timeout, lock on background (optional), manual lock.
On lock: all keys disposed (zeroed), decrypted vault/search index dropped,
clipboard cleared if it still holds our value, preview files wiped, breach-check
cache cleared. `FLAG_SECURE` blocks screenshots and the recent-apps thumbnail
(on by default in release builds; debug builds default it off for development).

## 7. Clipboard

Only the requested field is copied. On Android 13+ copies carry
`EXTRA_IS_SENSITIVE`, hiding the value from the clipboard preview overlay.
After the timeout (default 30 s, configurable, can be disabled) the app compares
a SHA-256 of the current clipboard with what it copied and clears **only if it
still matches** — your own copies from other apps are never wiped.
Platform limits: Android 10+ forbids clipboard reads while the app is in the
background, so the check is retried when you return; if the process is killed,
the timer dies (Android 13+ auto-clears the clipboard after ~1 hour). iOS shows
a "pasted from" banner on every read, so on iOS the app clears at the timeout
only if it never left the foreground since copying. Clipboard contents are never
logged or persisted.

## 8. Cloud, sync and devices

* Firestore stores encrypted records under `users/{uid}/…`; security rules
  (`firebase/firestore.rules`, emulator-tested) enforce owner-only access,
  verified email, strict schemas and sizes, server-side revision increments
  (`rev == old + 1`), immutable `kind`/`createdAt`, no key-generation rollback,
  one-way device revocation, and **record writes only from registered,
  non-revoked devices**. Everything else is denied.
* Firestore's own offline cache is disabled; the SQLCipher DB is the offline store.
* R2 objects (attachments, backups) are encrypted before upload. The app never
  holds R2 credentials: the FastAPI broker verifies the Firebase ID token
  (`check_revoked=True`, verified email, optional App Check), derives the object
  key `users/{uid}/{kind}/{uuid}` itself, and returns a presigned URL valid for
  5 minutes for exactly one object, with Content-Length in the signature.
* Each device has an Ed25519 identity and an X25519 key (secret halves in secure
  storage); the device record includes a self-signature proving key possession.

### Limits of revocation (important)

Revoking a device marks it revoked; the rules then refuse its record writes, and
the honest client wipes its local vault and signs out on its next sync.
However:

* a device that already downloaded and decrypted the vault **keeps whatever it
  has** if it never reconnects (or is malicious) — remote revocation cannot
  delete data from a device you no longer control;
* rules cannot yet stop a revoked device from *reading* ciphertext with its still
  valid Firebase session — it is useless without the VEK, but if that device
  also had the VEK, change your master password **and rotate the vault key**.
  Binding sessions to device keys (a backend-minted custom token carrying the
  device id, issued after an Ed25519 challenge) is the planned hardening.

## 9. Forgotten master password

There is **no recovery mechanism**, by design. Nobody — including the
operator — can derive your key. If you forget it:

* an *unlocked* device (or one with biometric/PIN unlock still valid) can still
  open the vault, export it, or set a new master password;
* otherwise all vault data, synced copies and vault-mode backups are permanently
  unreadable. Password-protected exports open with their own export password.

Resetting the Firebase *account* password only restores sign-in, not decryption.

## 10. Backups and exports

* `.citadel` archives: magic + header JSON + secretstream ciphertext of JSON
  lines (folders, tags, items, attachment chunks, `end` record). The stream key
  is `HKDF(baseKey, "citadel/v1/archive|" + SHA-256(header))`, so any header edit
  fails decryption; FINAL tag + `end` counts detect truncation.
* Vault-mode (automatic daily, manual, pre-destructive): restorable with the
  master password current at backup time, on any device.
* Password-mode (encrypted export, default export option): Argon2id(export password).
* Plaintext JSON/CSV exports require typing `EXPORT` after a warning.
  CSV cells starting with `= + - @` are quoted against spreadsheet formula injection.
* A safety backup is taken automatically before restore, empty-trash, folder
  deletion with items, and key rotation — the action aborts if it fails.
* Backups or exports you saved outside the app **cannot be deleted remotely**,
  including by account deletion.

## 11. Payment cards and CVV

Card numbers, CVVs and PINs are encrypted like everything else and require
device re-authentication to reveal or copy (configurable). CVV storage is **off by
default**: PCI DSS forbids merchants from storing card security codes after
authorisation, and keeping number + expiry + CVV together means anyone with your
unlocked vault can make card-not-present purchases. Enabling it shows that
warning. Storing a card PIN carries a similar warning (ATM fraud).

### Card autofill — investigated, not implemented

* Android: possible via a custom `AutofillService`. It would have to decrypt card
  data in a separate service context, ideally behind its own BiometricPrompt, and
  field detection on payment pages is unreliable. Chrome uses its own autofill for
  card fields unless the user switches Chrome to "autofill using another service".
* iOS: third-party apps cannot supply payment-card autofill (credential
  providers only cover passwords/passkeys).

Decision: not shipped in v1, to avoid weakening the security model with a
background decrypt path. Copy-with-re-auth covers the use case. The item model
already contains everything an AutofillService would need.

## 12. Breach checks (Have I Been Pwned)

Opt-in. SHA-1 computed locally; only the first 5 hex chars are sent to
`api.pwnedpasswords.com/range/…` with `Add-Padding: true`; suffixes are compared
locally; results are kept in memory only. The password, the full hash and the
matching suffix never leave the device. Nothing is changed automatically.

## 13. Logging, analytics, crash reports

No analytics or crash-reporting SDKs are included. The app logger is compiled
out of release builds and, by policy, only ever logs static text, record ids and
exception *types* — never values, keys, tokens, clipboard contents or ciphertext.
The broker logs uid, operation and object size only. No favicons are fetched
(that would leak which sites are in your vault); items use letter/type avatars.

## 14. Known limitations / roadmap

* Device-bound sessions for read-side revocation enforcement (§8).
* Background sync while the app is closed (WorkManager) — sync currently runs
  in the foreground (on unlock, after edits, on resume/connectivity, every 15 min).
* Tombstone garbage collection needs a scheduled job (e.g. a Cloud Function
  deleting tombstones older than 180 days); devices offline longer than that
  should do a full resync.
* iOS native biometric key binding (Keychain `.biometryCurrentSet` access
  control) is not implemented yet; iOS builds fall back to master password/PIN.
* Optional Google/Apple sign-in, multi-device enrollment by QR approval
  (X25519 sealed-box VEK hand-off), markdown notes.
