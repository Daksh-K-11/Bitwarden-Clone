# Citadel

An end-to-end encrypted password & secrets manager (Flutter), inspired by
Bitwarden's feature set with its own architecture and design.

* **Zero-knowledge crypto** — Argon2id → KEK → random vault key; XChaCha20-Poly1305
  per record with AAD binding; HKDF subkeys; libsodium only.
* **Local-first + cloud sync** — SQLCipher cache/outbox, conflict-aware encrypted
  sync over Firestore, attachments/backups in Cloudflare R2 via a presign broker.
* **15 item types** (logins, cards, identities, SSH keys, API keys, recovery codes,
  Wi-Fi, databases, licences, passports, driving licences, bank accounts, crypto
  wallets, notes, custom) + custom fields, folders (nested), tags, favourites,
  archive, 30-day trash, password history, attachments.
* **Authenticator** (RFC 6238, SHA-1/256/512, QR scan, Steam), **generators**
  (password / EFF passphrase / username), **security dashboard** (weak, reused,
  old, missing 2FA, HIBP k-anonymity breach check).
* **Hardware-bound biometric unlock**, app PIN, auto-lock, clipboard auto-clear,
  screenshot blocking, encrypted backups, Bitwarden JSON/CSV import.

Start here: [docs/SETUP.md](docs/SETUP.md) · [docs/SECURITY.md](docs/SECURITY.md) ·
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

```powershell
.\scripts\run_device.ps1            # build & run on your phone (wireless first, USB fallback)
.\scripts\run_device.ps1 -Tests     # run the test suite on the phone
```
