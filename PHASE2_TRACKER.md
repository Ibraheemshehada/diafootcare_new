# DiaFootCare — Phase 2 Tracker: Online/Offline Modes, Auto-Sync & Web Dashboard

Living checklist for the phase defined in `DaiFootCare_Web_Master_Brief.md`.
Phase 1 (the fully on-device app) is closed — see [`OFFLINE_MODE_STATUS.md`](OFFLINE_MODE_STATUS.md).
Phase 1's clinical feature checklist lives in [`FEATURE_TRACKER.md`](FEATURE_TRACKER.md).

**Legend:** ✅ done · 🚧 in progress · ⚠️ partial/blocked · ⬜ not started

_Last updated: 2026-07-18 (end of day)_

---

## 🔖 RESUME HERE — session handoff (2026-07-18, end of day)

**State:** The app and the dashboard are connected end to end. A record written on the
phone reaches the server, survives the app being closed, and shows up in the dashboard.
Firebase is gone. Both repos are pushed.

**Verified on a real device, not assumed:** the emulator's own `device_uuid`
(`f787a3e3-…`) exists as a row on the server; consent accepted on the phone arrived as
`version=2, locale=en, covers_prior=1`; a background WorkManager job uploaded 600 queued
events with the app not in the foreground.

### ⛔ Start here tomorrow — the one real defect left

**Repositories do not set `local_uuid` when they insert a row.** The sync path
compensates (it generates and persists one before upload), but the contract in
`daifootcare-web/README.md` says the id is generated **at capture time**, and that is the
robust place for it.

This mattered today. Because the id was missing, sync generated one on the fly and wrote
it back with `WHERE rowid = ?` — but `db.query()` returns only declared columns, so
`rowid` was never selected, the update matched nothing, and the id was never stored. Every
pass then re-sent the same record under a **new** id. Result: **38,172 rows on the server
representing 53 real events**, one uploaded 2,292 times, and a pending count that never
reached zero.

Fixed (rowid is now selected explicitly, and a row whose id cannot be persisted is skipped
rather than sent), duplicates cleaned up, and verified: two further sync passes added
**zero** rows. But the underlying gap remains — set `local_uuid` at insert in each
repository and the compensation can be deleted.

⚠️ **A correction to carry forward:** an earlier note in this file said engagement events
were "dominating the system" at 23,000/day. That was measuring the bug above, not real
volume. The daily rollups built in response are still worth keeping on their own merits,
but do not plan instrumentation around those figures — they were never real.

### ⬜ Next up, in order

1. **Set `local_uuid` at insert** in the repositories (above). Small, and removes a
   compensating mechanism from the sync path.
2. **Mode A / Mode B onboarding (§A1)** — still the largest untouched piece of the brief.
   Nothing depends on it, and nothing else in §A can start cleanly until the mode choice
   exists.
3. **iOS.** Background sync is Android-only by design (see §A6). If iOS is in scope for the
   study, that is a planning decision, not a coding one — `BGTaskScheduler` is
   opportunistic and makes no delivery guarantee.
4. **Wound images** — deliberately not uploaded (owner: "not required now"). `image_path`
   exists in the schema when it is wanted; it needs a storage / encryption-at-rest /
   retention decision first.

### 🧨 Blocking decisions that are still open

- **Consent is mandatory to use the app.** Implemented as asked, but requiring consent as a
  condition of access is the part an ethics board is most likely to reject — and it would
  be rejected *after* six months of collection. The defensible split is: sync-to-provide-
  care required, research use separately declinable. **Unresolved.**
- **Model hosting for Mode B** (~208 MB per offline install). Blocks §A2.
- **Model-version parity** between Mode A and Mode B results.

### 🪤 Gotchas found today (so they are not rediscovered)

- **`adb force-stop` disables background sync.** WorkManager logs
  `Application was force-stopped, rescheduling` and defers work until the app is next
  opened. That is documented Android behaviour, not a bug — but it also means a
  participant who force-stops the app silently stops contributing data.
- Android clamps periodic work to **15 minutes minimum**; asking for less is ignored.
- The background entry point needs `@pragma('vm:entry-point')`. Without it the release
  tree-shaker deletes it and the task silently never runs while passing every debug test.
- `cmd jobscheduler run` needs `-n androidx.work.systemjobscheduler` — WorkManager jobs are
  namespaced on Android 14+.
- Reading the device DB: `adb shell cat` corrupts binary. Use
  `run-as <pkg> sh -c 'base64 databases/diafoot.db'` and decode.
- The Pixel_4_API_36 emulator died **three times** today. Relaunch with `-no-snapshot-load`.
- The dev server is single-threaded (`artisan serve`); concurrent sync batches produce
  connection aborts that look like app bugs but are not.

### ✅ Done this session

- **Firebase removed entirely** (14 files). Identity now comes from the same server that
  stores the records — `ApiClient` (dio), `AuthService`, `DeviceService`, Sanctum token in
  the platform keystore, OTP password reset replacing the Cloud Function.
- **Sync queue** (schema v14): `local_uuid` / `pending_sync` / `synced_at` on every
  syncable table, batches of 50, partial-failure safe, exponential backoff.
- **Background sync** via WorkManager (Android), constrained to connected + battery-not-low.
- **Sync indicator** in the app header, bound to `pendingCount` / `syncing`.
- **Guest participation**: anonymous sessions keyed to `device_uuid`, claimable into a real
  account in place, so a guest's history survives registering.
- **Daily engagement rollups** (schema v15) — aggregation, not sampling, because every
  figure the study computes is a COUNT/SUM/DISTINCT and a rollup reproduces those exactly.
- **Web**: 7 new pages (Alerts, Appointments, Medications, Device detail, Sync monitor,
  Users & roles, Export), light/dark theming, validated data-viz charts, landing page with
  real app screenshots.

## A. Mobile app (this repo) — 🚧 auth and sync done; modes not started

### A1. First-run mode selection ⬜
- ⬜ Onboarding screen on first launch: **Mode A (Online)** vs **Mode B (Offline)**
- ⬜ Persist the choice (`shared_preferences`), surface it in Profile so it can be changed later
- ⬜ EN/AR localization + RTL for the new screen
- ⬜ Accessibility parity with the rest of the app (48dp targets, semantics labels, 2× text scaling)

### A2. Mode B — resumable model download ⬜
- ⬜ Move the 4 TFLite files **out of `assets/`** so the base APK drops from ~208 MB
- ⬜ Host the models; download on demand with **HTTP range requests** so a broken connection resumes rather than restarting
- ⬜ Progress UI (per-file + overall), pause/resume, integrity check (checksum) before first use
- ⬜ Point `AiService.init()` at the downloaded files instead of the asset bundle
- ⬜ Handle the "user chose Offline but download incomplete" state gracefully

> ⚠️ **Do not start A2 before A1 is settled.** Unbundling the models changes how *every*
> inference path resolves its model file, and the app is currently correct offline.
> Regressing that is worse than a large APK.

### A3. Mode A — server-backed inference ⬜
- ⬜ API client (`dio`) with a retry interceptor
- ⬜ Upload image → receive segmentation / tissue / infection results in the same shape `AiService` returns today, so the result screen is unchanged
- ⬜ Graceful degradation when the network drops mid-analysis

### A4. Auth ✅ done
- ✅ `AuthService` against Laravel Sanctum (login / register / logout / session restore)
- ✅ Token in the platform keystore via `flutter_secure_storage`, attached by an interceptor;
  a 401 clears it
- ✅ **Firebase removed entirely.** Decision: replace, not bridge — identity now comes from
  the same server that stores the clinical records, so a login and its data cannot disagree
  about who the patient is
- ✅ Guest path preserved and improved: an anonymous session is now a real server-side
  participant keyed to `device_uuid`, claimable into a named account **in place** so the
  history survives registering
- ✅ OTP password reset replacing the Firebase Cloud Function (hashed codes, TTL, attempt
  cap, enumeration-safe response); changing a password requires the current one
- ⚠️ Reset emails need SMTP configured — `MAIL_MAILER=log` in development writes the code to
  `storage/logs` instead of sending it

### A5. Local sync queue ✅ done
- ✅ Schema **v14**: `local_uuid` + `pending_sync` + `synced_at` on every syncable table
- ✅ Existing rows backfilled and queued, so history predating the queue still uploads
- ✅ `notes` deliberately excluded — free text is the most sensitive thing a patient writes
  and nothing in the study needs it
- ⚠️ **Repositories still do not set `local_uuid` at insert** — see RESUME HERE. The sync
  path compensates, but the contract says capture time and that is the robust place

### A6. Auto-sync service ✅ done
- ✅ `connectivity_plus` listener; batches of 50 per table
- ✅ Only rows the server acknowledges are marked synced; the rest stay queued and retry,
  which is what makes partial failure safe
- ✅ Exponential backoff (1s → 10min); a 429 backs off hard rather than counting as a failed
  record
- ✅ Drains on launch, on reconnect, every 15 min while pending, and on app pause
- ✅ **Background sync** via WorkManager while the app is closed — Android only, constrained
  to connected + battery-not-low
- ✅ Sync status in the app header (`pendingCount` / `syncing`), tap to sync now
- ⬜ iOS background execution — `BGTaskScheduler` is opportunistic and guarantees nothing;
  a scope decision, not a coding one
- ⬜ Wound **images** are not uploaded (owner: not required now)

---

## B. Backend — Laravel API (separate repo) — ✅ scaffolded & verified

Repo: `daifootcare-web` (sibling folder, local `main`, **no GitHub remote yet**).

- ✅ Project scaffold — **Laravel 12**, not 11. Composer *refused* to install any 11.x
  release: v11.31.0–v11.55.0 are all covered by security advisories (incl. reflected XSS).
  Laravel 11 is past its security-patch window; shipping it under patient data was not an
  acceptable trade for matching the pinned version.
- ✅ Migrations + models: `patients`, `devices`, `wound_scans`, `sync_logs`, + `role`/`locale` on `users`
- ✅ Role gating: admin / doctor / patient (`EnsureUserIsClinician` middleware)
- ✅ Auth endpoints (register / login / logout / me) — Sanctum tokens
- ✅ Device endpoints (register, mode update, list)
- ✅ **Idempotent sync endpoint** — upsert on `local_uuid`; **verified**: the same batch sent
  twice produced 2 rows, not 4
- ✅ Dashboard stats endpoint
- ✅ Added two fields the brief omitted: `models_version` (Mode A and Mode B results are
  otherwise not comparable — open decision #4) and `source`
- ✅ Ten further tables + a generic `POST /sync/{type}` covering glucose, medications,
  medication-logs, self-care, qol, satisfaction, appointments, sus, engagement, consents
- ✅ Guest sessions (`/auth/guest`) and claim (`/auth/claim`)
- ✅ Password reset, profile/password endpoints
- ✅ `engagement_daily` rollups; SUS scored server-side from the raw items
- ⬜ Image upload — `image_path` exists in the schema but sync takes **metadata only**.
  Needs a storage / encryption-at-rest / retention decision first.
- ⬜ Queue jobs for image processing (blocked on the above)

**Security properties verified against a running server, not assumed:**
patient isolation (second patient reads `total: 0`) · patient token on clinician routes → `403` ·
device hijack → `409` · `"role":"admin"` in the register body → stored role stays `patient`.

## C. Dashboard — Vue 3 (separate repo) — ✅ scaffolded & verified

- ✅ Login page (Sanctum token flow) + route guards
- ✅ Dashboard: patient / device / scan / sync counts, animated cards (`motion-v`)
- ✅ Devices page: every install, last seen, mode, models-downloaded state
- ✅ Patients page + Scan Feed (newest first)
- ✅ **Skeleton loaders on every page** via a shared `useApiResource` composable, so no page
  can accidentally ship a bare "Loading…" string
- ✅ Full RTL + EN/AR (`vue-i18n`) — direction flips **and survives a reload**
- ✅ Design tokens defined once in `app.css`; risk colour is always paired with a text label,
  never the only signal
- ✅ Seven further pages: Alerts, Appointments, Medications, Device detail, Sync monitor,
  Users & roles (admin-only), Export
- ✅ Light / dark / follow-OS theming
- ✅ Charts built to the data-viz method — the brand cyan is deliberately not used for data
  marks (chroma 0.094, reads grey when plotted)
- ✅ Public landing page with real screenshots from the shipped app
- ⬜ Realtime updates (Reverb/Pusher) — optional in the brief, not started
- ⬜ Pagination controls (the API paginates; the UI currently renders page 1 only)

**Driven in Chromium (Playwright), 0 console errors:** guard redirect → login → stat tiles
showing live API numbers → all four pages → Arabic/RTL switch → reload → deep links →
mobile off-canvas drawer. That pass caught two real bugs, both fixed: the sidebar rendered
**off-viewport on desktop** (`ltr:-translate-x-full` beat `lg:translate-x-0` in the cascade
while `lg:ps-64` still reserved its space, making nav unreachable), and **icons were
invisible** until `@iconify-json/lucide` was installed.

---

## ⚠️ Open decisions (blocking — need an answer before the relevant work starts)

1. ~~**Firebase vs. Sanctum identity.**~~ **Resolved 2026-07-18:** Firebase removed
   entirely; Sanctum is the only identity system.
2. **Where are the models hosted, and who pays egress?** 208 MB per Offline-mode install
   is real bandwidth. Blocks A2.
3. **Patient data leaving the device.** Phase 1's guarantee was that nothing is transmitted —
   the analytics are explicitly local-only and the SUS participant declaration tells users
   their data is "on-device" and "not linked to medical data". Phase 2 syncs wound images and
   clinical records to a server, which **contradicts that declaration**. The consent text and
   privacy policy must be updated before any sync ships, and Mode B users need a clear choice
   about whether their data syncs at all.
4. **Inference parity between Mode A and Mode B.** If the server runs different model
   versions than a given install downloaded, two users get different results from the same
   photo. Needs a model-version field in the API contract.
