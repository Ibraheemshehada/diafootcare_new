# DiaFootCare — Phase 2 Tracker: Online/Offline Modes, Auto-Sync & Web Dashboard

Living checklist for the phase defined in `DaiFootCare_Web_Master_Brief.md`.
Phase 1 (the fully on-device app) is closed — see [`OFFLINE_MODE_STATUS.md`](OFFLINE_MODE_STATUS.md).
Phase 1's clinical feature checklist lives in [`FEATURE_TRACKER.md`](FEATURE_TRACKER.md).

**Legend:** ✅ done · 🚧 in progress · ⚠️ partial/blocked · ⬜ not started

_Last updated: 2026-07-18_

---

## 🔖 RESUME HERE — session handoff (2026-07-18)

**State:** Phase 1 closed and declared. Phase 2 scaffolding begins now.

Done this session:
- Disabled the stray git repo that had been initialized over the **entire home directory**
  (`C:\Users\jawhara\.git` → `.git.disabled`). It had no remote and its 4 commits contained
  no source code — only `.idea/` config, `__MACOSX` zip junk, and submodule pointer bumps.
  The real repo has always been this one.
- Wrote `OFFLINE_MODE_STATUS.md` (offline capability declared complete, with evidence).
- Wrote this tracker.

- Built the web project as a **separate repo**: `daifootcare-web` (Laravel 12 + Vue 3),
  committed locally on `main`. **No GitHub remote yet** — create one and push.
  The API contract is documented in that repo's `README.md`.

This repo — the Flutter app — is **unchanged apart from these three docs**. No mobile
networking code has been written yet, deliberately: §A should not start until the API
contract is settled and open decision #1 (Firebase vs. Sanctum) is answered.

### ⬜ Immediate TODO
1. Create the GitHub remote for `daifootcare-web` and push (`gh` is not installed on this
   machine, so this is a manual step).
2. Answer open decision #1 (Firebase vs. Sanctum) — it blocks §A4 and shapes §A1.
3. Answer open decision #3 (consent) — it blocks shipping sync to real patients at all.
4. Only then start the mobile-side work in §A.

---

## A. Mobile app (this repo) — ⬜ not started

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

### A4. Auth ⬜
- ⬜ `AuthService` against Laravel Sanctum (login / register / logout)
- ⬜ Store the token in **secure storage** (not `shared_preferences`), attach to every request
- ⬜ Decide the relationship to the existing **Firebase auth** — running both is a real risk of two conflicting identity systems. Options: migrate fully to Sanctum, or keep Firebase for identity and exchange its token for a Sanctum token. **This needs an explicit decision before A4 starts.**
- ⬜ Preserve the offline **guest** path — a Mode B user must still be able to use the app with no account

### A5. Local sync queue ⬜
- ⬜ DB migration **v13**: add `local_uuid` (UUID v4, generated at capture time — *not* at upload) + `pending_sync` + `synced_at` to the scan/daily-log tables
- ⬜ Backfill `local_uuid` for existing rows on upgrade (existing installs must not break — the app auto-migrates via `onUpgrade`, no wipe)

### A6. Auto-sync service ⬜
- ⬜ `connectivity_plus` listener; on reconnect, batch pending rows (~20/request)
- ⬜ `POST /api/v1/wound-scans/sync`; on success set `pending_sync = false`, `synced_at = now()` for the returned `local_uuid`s; partial failures stay pending and retry
- ⬜ **Exponential backoff** (1s → 5s → 30s → 2min) so a flapping connection can't hammer the server
- ⬜ `workmanager` for background sync while the app is closed
- ⬜ Sync status indicator in the UI (pending count / last synced)

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

1. **Firebase vs. Sanctum identity.** Blocks A4. Two auth systems in one clinical app is a
   correctness and privacy hazard, not just tech debt.
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
