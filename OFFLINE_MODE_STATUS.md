# Offline Mode — Status: ✅ COMPLETE (this repo)

_Declared: 2026-07-18 · Repo: `Ibraheemshehada/diafootcare_new` · Branch: `main`_

This file records that **the offline (on-device) capability of DiaFootCare is finished
in this repository**. It is the baseline the next phase builds on — see
[`PHASE2_TRACKER.md`](PHASE2_TRACKER.md) for the online/offline mode-selection,
auto-sync, and web-dashboard work that follows.

---

## What "offline" means here — and what it does not

**✅ Complete: the entire clinical pipeline runs on-device with no network.**

| Capability | Offline? | Evidence |
|---|---|---|
| AI analysis (3 models) | ✅ Fully on-device | 4 TFLite files bundled in `assets/models/` (~208 MB), loaded by `AiService.init()`; no inference request ever leaves the device |
| Wound capture + calibration | ✅ | `camera` / `image_picker`, px↔cm scale computed locally |
| Data storage | ✅ | `sqflite` / `drift`, schema **v12**, local DB only |
| History, healing-trend chart | ✅ | `computeTrend()` over the local DB |
| Glucose, medication, self-care, QoL, appointments | ✅ | All persisted to the local DB (v5–v9) |
| Education content | ✅ | Static, compiled into the app |
| Reminders + notifications | ✅ | `flutter_local_notifications` + `android_alarm_manager_plus`, scheduled locally |
| Export (PDF / CSV / Excel) | ✅ | Generated on-device, shared via the system share sheet |
| Analytics / usability instrumentation | ✅ | Local-only (`analytics_events`); nothing is transmitted |
| Accessibility (TalkBack, contrast, 2× text) | ✅ | Android-verified, 11/11 criteria |

**⚠️ Not offline — the only network dependencies in the app today:**

- `firebase_auth` — login / sign-up / password change. **Guest login (`is_guest`) is the
  offline entry path** and opens straight to Home, so a user with no connectivity can
  still use every clinical feature above.
- `firebase_messaging`, `cloud_functions` — push notifications only; not on any
  clinical path.

Network call sites are confined to: `lib/app.dart`, `lib/core/services/auth_services.dart`,
and the auth/profile/home viewmodels.

---

## Bundled models

| File | Size | Role |
|---|---|---|
| `model1_wound_fp16.tflite` | 12.4 MB | Segmentation → length/width/area |
| `clip_backbone_fp16.tflite` | 175.8 MB | Shared CLIP feature extractor |
| `tissue_head.tflite` | 20.2 MB | Tissue classification |
| `infection_ischaemia_head.tflite` | 0.27 MB | Infection / ischaemia → DFU risk badge |

Total **≈ 208 MB**, tracked in **Git LFS**. If the working tree shows 134-byte pointer
files, run `git lfs checkout`.

> This bundle size is precisely the motivation for Phase 2's **Mode A (Online)** — it lets a
> user skip the ~200 MB download and call a server API instead. **Mode B (Offline)** keeps
> exactly the behaviour documented above, with the models fetched on demand via a
> resumable download rather than shipped inside the APK.

---

## Verification state at the time of this declaration

- `flutter analyze lib test` → **0 errors**
- `flutter test` → **23/23 pass** (12 SUS + 11 trend)
- §1–§8 device-QA'd in Arabic RTL + dark mode; Issue #1 (glucose render assert) confirmed fixed
- Accessibility **11/11 on Android** (TalkBack verified, contrast measured, 2.0× text scaling clean)

## Known open items carried into Phase 2

These do **not** block the offline declaration, but are tracked so they are not lost:

1. **iOS VoiceOver + multi-device sweep** — only Pixel 4 / API 36 has been used; TalkBack is
   verified on Android, VoiceOver has not been checked.
2. **Inference runs on the main isolate** (~2.8 s on the emulator). Models now preload when
   the camera opens, so the alarming hang is gone, but moving `.run()` to
   `IsolateInterpreter` is still the fix for a fully smooth spinner. The 4 call sites are in
   `ai_service.dart`.
3. **Happy-path measurement not yet captured on real hardware.** `0.0 × 0.0 cm` results on the
   emulator were traced to the synthetic room scene containing no wound — not a model
   failure. A real wound photo on a physical device is still needed to confirm non-zero
   measurements.
4. `dart format` divergence — the repo is not dart-formatted (89 of 117 files would change).

See `FEATURE_TRACKER.md` for the full detail behind each.
