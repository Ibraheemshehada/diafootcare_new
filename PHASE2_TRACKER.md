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

**Next:** the web project is being built as a **separate repo** (`daifootcare-web`,
Laravel 11 + Vue 3). This repo — the Flutter app — stays as-is until the API contract is
stable enough to code the mobile client against.

### ⬜ Immediate TODO
1. Build the Laravel 11 + Vue 3 dashboard skeleton (separate repo).
2. Lock the API contract (§3.2 of the brief) before writing any Flutter networking code.
3. Only then start the mobile-side work in §A below.

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

## B. Backend — Laravel 11 API (separate repo) — 🚧 in progress

- 🚧 Project scaffold (Laravel 11 + Sanctum + Vite + Vue 3 + Tailwind v4 + Nuxt UI v4)
- ⬜ Migrations + models: `users`, `patients`, `devices`, `wound_scans`, `sync_logs` (§3.1)
- ⬜ Role policies: admin / doctor / patient
- ⬜ Auth endpoints (register / login / logout)
- ⬜ Device endpoints (register, mode update)
- ⬜ **Idempotent sync endpoint** — `upsert` keyed on `local_uuid` so a re-sent batch never duplicates
- ⬜ Dashboard stats endpoint
- ⬜ Queue jobs for image/large-file processing

## C. Dashboard — Vue 3 (separate repo) — ⬜ not started

- ⬜ Login page (Sanctum token flow)
- ⬜ Dashboard: patient / device / scan counts, animated cards
- ⬜ Devices page: every install, last seen, mode, models-downloaded state
- ⬜ Patients + daily-logs feed (newest first)
- ⬜ **Skeleton loaders on every page** (`USkeleton`) — not a text "Loading…"
- ⬜ Full RTL + EN/AR via `vue-i18n`
- ⬜ Design tokens (colors / spacing / type) defined once, not ad-hoc per component

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
