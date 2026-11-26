# Setup & development

## Repository layout

```
frontend/   Flutter app (Android/iOS) - package `citadel`
backend/    FastAPI R2 presign broker (runs from ../venv)
firebase/   Firestore rules, indexes, emulator rules tests
scripts/    run_device.ps1, run_backend.ps1
docs/       SECURITY.md, ARCHITECTURE.md, SETUP.md
venv/       Python virtualenv for the backend
```

## 1. Toolchain (Windows)

* Flutter 3.50+ (Dart 3.12+). Android SDK + NDK 28.
* **Git for Windows** (provides `bash`) and GNU **make** — required because the
  `sodium` package compiles libsodium from source for Android. The NDK ships a
  usable make at `<sdk>\ndk\<ver>\prebuilt\windows-x86_64\bin\make.exe`;
  `scripts\run_device.ps1` puts it and `C:\Program Files\Git\bin` on PATH.
  (A plain `bash` on PATH that points at WSL does **not** work.)
* First Android build compiles libsodium per ABI (~5 min each); later builds reuse it.
* Host-side `flutter test` additionally needs **Visual Studio 2022 Build Tools**
  (MSBuild ≥ 17.8) to build libsodium for Windows. Without it, run the suite on
  the phone instead: `.\scripts\run_device.ps1 -Tests`.
* If Gradle downloads time out, keep `GRADLE_OPTS=-Djava.net.preferIPv4Stack=true`
  (set by the script).

## 2. Run on your phone

Wireless debugging is preferred, USB is the fallback:

```powershell
# Phone: Settings > Developer options > Wireless debugging > note ip:port
.\scripts\run_device.ps1 -Wireless 192.168.29.19:41099
# or just plug in USB:
.\scripts\run_device.ps1
```

Without Firebase configured the app runs in **offline mode**: everything works
on the device, cloud sign-in/sync are hidden.

## 3. Enable the cloud (Firebase)

1. Create a Firebase project. Enable **Authentication › Email/Password** and
   **Cloud Firestore** (production mode).
2. Register the Android app with package name **`app.citadel.vault`**.
3. Generate `lib/firebase_options.dart`:
   ```powershell
   dart pub global activate flutterfire_cli
   npm install -g firebase-tools; firebase login
   cd frontend; flutterfire configure --project=<project-id> --platforms=android,ios
   ```
4. Deploy rules and indexes:
   ```powershell
   cd firebase; copy .firebaserc.example .firebaserc   # set your project id
   npm install; npx firebase deploy --only firestore:rules,firestore:indexes
   ```
5. **App Check** (recommended): register Play Integrity for the Android app. For
   debug builds, copy the debug token printed in logcat (`DebugAppCheckProvider`)
   into the console. Turn on enforcement for Firestore once both work.
6. Test the rules locally at any time: `cd firebase; npm run test:rules`.

## 4. Attachments & cloud backups (Cloudflare R2)

1. Create an R2 bucket (e.g. `citadel-vault`), keep it **private** (no public
   access, no r2.dev URL).
2. Add a lifecycle rule: *abort incomplete multipart uploads after 1 day*.
3. Create an R2 API token: **Object Read & Write**, scoped to that bucket only.
4. Configure CORS only if you add a web client (the mobile app needs none).
5. Configure and start the broker:
   ```powershell
   copy backend\.env.example backend\.env      # fill in R2 + Firebase values
   # service account: Firebase console > Project settings > Service accounts
   .\scripts\run_backend.ps1                    # prints http://<lan-ip>:8000
   .\scripts\run_device.ps1 -ApiUrl http://<lan-ip>:8000
   ```
   Debug builds allow cleartext HTTP to reach the broker on your LAN; release
   builds are HTTPS-only. Deploy the broker behind TLS (Cloud Run, Fly.io, a VPS
   with Caddy) and build with `-ApiUrl https://…`.
6. Backend tests: `venv\Scripts\python -m pytest backend`.

## 5. Tests

| Suite | Command | Covers |
|---|---|---|
| Dart (on device) | `.\scripts\run_device.ps1 -Tests` | crypto/AAD/tamper/rotation, RFC 6238 vectors, generators, import/export, archive integrity, two-device sync (conflicts, tombstones, idempotency, rollback, revocation) |
| Dart (host) | `cd frontend; flutter test` | same — needs VS 2022 Build Tools |
| Firestore rules | `cd firebase; npm run test:rules` | access control, schema, revisions, revocation, key rollback |
| Broker | `venv\Scripts\python -m pytest backend` | auth, scoping, traversal, size caps, App Check, rate limit, purge |

## 6. Release checklist

* Real signing config in `android/app/build.gradle.kts` (currently debug-signed).
* `flutter build appbundle --release --obfuscate --split-debug-info=build/symbols`.
* App Check enforcement on; broker `REQUIRE_APP_CHECK=true`.
* Firestore budget alerts; R2 usage alerts (see ARCHITECTURE.md › Cost).
