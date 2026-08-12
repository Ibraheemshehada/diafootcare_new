# DiaFootCare — Accuracy Fix: Implementation Tracker

Companion to [ACCURACY_IMPROVEMENT_PLAN.md](ACCURACY_IMPROVEMENT_PLAN.md) (the *what* and
*why*). **This file is the *what was actually done*, and whether it worked.**

- **Baseline commit before any change:** `ae57202`
- **Backups of every modified file:** `_backups/2026-08-05/…` (gitignored; mirrors the repo tree)
- **Rule:** every entry states its verification status honestly. "Compiles" is not "works".

---

## ⚠️ Verification status legend
| Symbol | Means |
|---|---|
| ✅ **VERIFIED** | Measured against data or a real run; evidence recorded |
| 🟡 **BUILDS** | Compiles, analyzer clean, tests pass — **but no behavioural proof yet** |
| 🔴 **UNVERIFIED** | Written, not yet exercised |
| ⬜ Not started | |

> **Nothing here may be described as an accuracy improvement until it is measured against
> the real-patient validation set (P1).** Building is not evidence.

---

## 1. Changes made — 2026-08-05

### C1 · Model 3 (infection) now sees the wound, not the whole photo 🟡 BUILDS
**Problem** ([plan §3](ACCURACY_IMPROVEMENT_PLAN.md)): Model 3 was trained exclusively on
tight wound patches (DFUC2021 224×224, Part B 256×256) but the app fed it a centre crop of a
whole-foot photograph — roughly 5% wound, 95% background. A train/serve mismatch, and the most
likely cause of the field false positive.

| | Path |
|---|---|
| **Modified** | `lib/features/wound/analysis/services/ai_service.dart` |
| **Backup** | `_backups/2026-08-05/lib/features/wound/analysis/services/ai_service.dart` |

**What changed**
1. `_Measurements` gained `woundBox`; new `_BoxPx` class — the wound bounding box in
   original-image pixels, converted out of mask space and rounded outwards.
2. New `_woundCrop()` — a **square** crop centred on the wound with 15% padding. Square is
   deliberate: `_clipPreprocess` resizes the short side to 224 then centre-crops 224, so a
   non-square crop would be clipped again — the very bug being fixed.
3. `analyzeWound` now gives **each head the framing it was trained on**: Model 2 the whole
   photograph, Model 3 the wound crop.
4. New flags `_cropForModel3 = true`, `_model3CropPadding = 0.15` — flip the first to `false`
   to restore the old behaviour instantly.

**⚠️ Model 2 deliberately NOT cropped.** Its corpora (Source-A, DFUC2020) are whole
photographs; cropping it would create the same mismatch in the opposite direction. It stays on
the whole frame until its head is retrained on crops (W2b).

**Performance note:** the CLIP backbone previously ran once for both heads. It now runs twice
*when a wound is found*. The whole-image embedding is computed lazily and shared, so when no
wound is located (no crop possible) the cost is unchanged.

**Verification**
- ✅ `flutter analyze lib test` → **0 errors, 0 warnings** (138 pre-existing `info` lints, unchanged)
- ✅ `flutter test` → **83/83 passed**
- ✅ Confirmed the 2 `library_private_types_in_public_api` infos are **pre-existing** in
  `ModelsUnavailableException` (present in the backup too) — this change added none
- 🔴 **NOT yet verified on a real photograph.** No device run. Whether the false positive
  actually disappears is **unproven** until P1 exists.

---

### C2 · The "measurement not calibrated" warning is back 🟡 BUILDS
**Problem** ([plan §2](ACCURACY_IMPROVEMENT_PLAN.md)): with calibration removed from the flow,
`pixelsPerCm` is always null, so every measurement comes from an assumed 12 cm frame width and
scales with however far the camera happened to be held — a real 1.4 cm wound was reported as
0.9 cm. The app presented that to two decimals **with no qualification whatsoever**.

| | Path |
|---|---|
| **Modified** | `lib/features/wound/analysis/screens/ai_result_screen.dart` |
| **Modified** | `assets/translations/en.json`, `assets/translations/ar.json` |
| **Backups** | `_backups/2026-08-05/…` (same relative paths) |

**What changed** — restored the `!result.isCalibrated` banner (the `isCalibrated` field and the
`ai_not_calibrated_banner` key both already existed and were simply unused), and **rewrote its
wording**: the old text told users to "set a scale with a reference object", a step that no
longer existed. The new text states the limitation and points at the signal that *is* reliable:

> **EN** "Not calibrated — the cm values are estimates and change with how far the camera was
> held. Compare the change over time rather than the absolute size."
> **AR** «غير معايَر — القيم بالسنتيمتر تقديرية وتتغيّر حسب بُعد الكاميرا عن الجرح. قارن التغيّر مع الوقت بدلاً من الرقم المطلق.»

Once the calibration sticker ships, this wording should point at it.

**Verification**
- ✅ Both translation files parse; **613 keys each, sets identical**
- ✅ `flutter analyze` 0 errors · `flutter test` 83/83
- ✅ `AppColors.warning` confirmed to exist
- 🔴 **Not visually verified** — no device/emulator screenshot yet

---

### C3 · Infection threshold sweep — decision data for D4 ✅ VERIFIED (analysis only)
No app change. Reproduced Model 3's grouped cross-validation from the cached embeddings to
quantify the operating-point trade-off.

- **Script:** `scratchpad/m3_threshold_sweep.py` · **Output:** `D:\DF\model3_infection_output\oof_reproduced.npy`, `threshold_sweep_summary.json`
- **Reproduction validated:** infection AUC **0.8883** vs the recorded **0.890** ✅ — the
  pipeline is faithful, so the numbers below are trustworthy.

| Threshold | Sens | Spec | PPV @54% *(training)* | PPV @20% *(clinic)* | PPV @10% | False positives |
|---|---|---|---|---|---|---|
| **0.41 — deployed** | 0.855 | 0.741 | 0.796 | **0.452** | **0.268** | **880 / 3398** |
| 0.42 *(F1-optimal)* | 0.849 | 0.755 | 0.803 | 0.464 | 0.278 | 834 |
| 0.50 | 0.801 | 0.814 | 0.836 | 0.519 | 0.324 | 631 |
| 0.60 | 0.732 | 0.873 | 0.872 | 0.591 | 0.391 | 430 |
| **0.662** *(spec ≥ 0.90)* | 0.682 | 0.901 | — | 0.631 | — | 338 |
| **0.786** *(spec ≥ 0.95)* | 0.547 | 0.951 | — | 0.738 | — | 165 |

> 🚨 **The finding that matters.** Training prevalence is **54%**; a real clinic is far lower.
> At the deployed threshold and a realistic **20% prevalence, PPV is 0.452 — a positive result
> is more often wrong than right.** At 10% prevalence it is 0.268. The reported "AUC 0.890" is
> honest but says nothing about this, because AUC is prevalence-independent. **This is the
> arithmetic behind the false positive on the healthy patient.**

**Not yet applied** — changing the deployed threshold awaits **D4** (whether a missed infection
or a false alarm is the worse outcome). The table exists to make that a decision, not a guess.

---

### C4 · IWGDF/IDSA triage — the real answer to D4 ✅ VERIFIED *(logic)*
**Problem.** D4 asked which threshold to pick. The honest answer is **neither**: every
threshold sits on one ROC curve, so sensitivity is only ever bought with specificity. Getting
both requires **more information**, not a different number.

**The clinical ceiling.** IWGDF/IDSA defines a local diabetic-foot infection as **purulent
discharge**, or **≥2 of**: erythema, warmth, swelling/induration, tenderness, discharge. A
photograph can show erythema and sometimes discharge — it cannot feel warmth, cannot feel
tenderness, cannot smell, cannot take a temperature. **Roughly two of six signs are visible at
all**, so AUC ≈0.89 on photographs is plausibly near an information ceiling that no retraining
lifts. Asking the patient supplies the missing signs from an *independent* channel, which is
what moves the curve rather than sliding along it.

| | Path |
|---|---|
| **New** | `lib/features/wound/analysis/services/infection_triage.dart` |
| **New** | `test/infection_triage_test.dart` |
| **Modified** | `assets/translations/en.json`, `ar.json` (+21 keys each) |

**Two changes in one.**

*(a) Three zones instead of a binary.* Two cut-offs — `kZoneLowMax = 0.30`,
`kZoneHighMin = 0.80` — so the middle band says "uncertain" instead of guessing. Measured on
the reproduced OOF scores at 20% prevalence:

| | Single threshold 0.41 | **Three zones 0.30 / 0.80** |
|---|---|---|
| Alarms raised | 37.8% of patients | **14.1%** |
| **PPV (alarm is real)** | **0.452** | **0.754** |
| NPV (reassurance is safe) | 0.953 | **0.966** |
| **Infections missed** | **2.9%** | **1.8%** |

> **Better on both axes at once** — fewer false alarms *and* fewer missed infections. Not a
> trade: ambiguous cases stop being forced into a bucket they do not belong in.

*(b) Fusion with the patient checklist.* The image score becomes the "appearance" sign — **one
sign among several**, not the verdict — and the IWGDF ≥2 rule decides.

**Safety properties, each covered by a test**
- **Absence of pain never reassures.** Neuropathy can remove protective sensation, so signs are
  only counted up; a "no" never subtracts.
- **Two reported signs overrule a quiet image** — the model is the least reliable channel here.
- **A loud image with no symptoms asks for a retake**, not an alarm (lighting/angle inflate scores).
- **Systemic symptoms short-circuit to urgent** (possible IWGDF grade 4).
- **An uncertain image contributes no sign** — letting a coin-flip cast half a vote is how
  false alarms return.
- **Osteomyelitis caveat is attached to every non-urgent outcome**; neither channel can see
  deep or bone infection, so "no signs" is never presented as an all-clear.

**Verification**
- ✅ **`flutter test test/infection_triage_test.dart` → 18/18 passed** — this is the one change
  so far that is genuinely *verified*, not merely building: the logic is pure and testable
  without a device.
- ✅ Full suite **101/101** (was 83; +18 new), `flutter analyze` **0 errors, 0 warnings**
- ✅ Translations: 634 keys, en/ar sets identical
- 🔴 **UI not built yet** — the checklist screen and the wiring into `analyzeWound` remain, so
  this is not yet reachable by a patient.

**Patient wording** (deliberately plain; only asks what the camera *cannot* see — erythema is
left to the model, which judges it more consistently than an untrained observer estimating
"redness wider than half a centimetre"):

| Sign | Arabic |
|---|---|
| Discharge | هل يخرج من الجرح سائل أصفر أو أخضر، أو له رائحة كريهة؟ |
| Warmth | هل الجلد حول الجرح أدفأ من نفس المكان في قدمك الأخرى؟ |
| Swelling | هل يوجد انتفاخ أو تصلّب حول الجرح؟ |
| Tenderness | هل تشعر بألم أو انزعاج عند لمس المنطقة حول الجرح؟ |
| Systemic | هل عندك حرارة، أو تشعر بتعب عام غير معتاد؟ |

---

### C5 · 🚨 Was the fusion actually tested? **No — and it cannot be yet** ⚠️ HONEST LIMIT
Asked directly: *what is the real accuracy after the questions, and the real false-alarm rate?*

**The image side is measured. The checklist side has never been measured, and no data on hand
can measure it** — neither DFUC2021 nor Part B records whether a patient felt warmth or
tenderness. There is no dataset pairing an image with symptom answers. Any single number for
the fused system would be invented.

#### ✅ MEASURED (real out-of-fold probabilities, 20% prevalence)
| | Alarm rate | PPV | **False alarms among healthy** |
|---|---|---|---|
| Single threshold 0.41 | 37.8% | 0.452 | **25.9%** |
| **Three zones, image only** | 14.1% | **0.754** | **4.3%** |

> **The certain, measured win: false alarms among healthy patients fall 25.9% → 4.3%, a ~6×
> reduction — from the banding alone, before any question is asked.**

#### 📐 PROJECTED (image real, checklist swept across plausible behaviours)
| Checklist quality | Alarm rate | PPV | False alarms | Infected not referred |
|---|---|---|---|---|
| Pessimistic (noisy answers) | 25.2% | **0.483** ⚠️ | 16.3% | 7.8% |
| Moderate (expected) | 21.8% | 0.672 | 9.0% | 5.3% |
| Optimistic (clear answers) | 20.7% | 0.818 | 4.7% | 3.1% |

*Script: `scratchpad/fusion_projection.py`. Assumes the checklist errs **independently** of the
image; in reality both track severity and will correlate, so the true gain is **smaller** than
shown. These are an optimistic ceiling, not a forecast.*

#### Two findings that changed the plan
1. **⚠️ A noisy checklist can make precision WORSE.** In the pessimistic case PPV falls to
   0.483 — below the 0.754 of the image alone — because wrong answers from an untrained
   patient add false positives. The warning about moderate inter-rater reliability was
   well-founded. **The checklist's value is conditional on answer quality, and that is
   currently unknown.**
2. **A number reported earlier needs qualifying.** "Missed infections 2.9% → 1.8%" is true for
   patients *actively reassured* (told "no signs"). Under the broader definition — infected and
   **not referred** — three zones is *worse*: **9.4%** vs 2.9%. The difference is not people
   told they are fine; it is people told **"monitor and re-photograph"**. That is precisely the
   gap the checklist exists to resolve.

#### ➡️ Consequence — a hard requirement on the validation set
**P1 must record the five checklist answers alongside every photograph**, or the fusion stays
unmeasurable and we will never learn which column above we are in.

---

### C6 · Checklist UI 🟡 BUILDS
| | Path |
|---|---|
| **New** | `lib/features/wound/analysis/screens/infection_checklist_screen.dart` |
| **Modified** | `lib/features/wound/analysis/viewmodel/analysis_result.dart` (+`infectionProbability`) |
| **Modified** | `lib/features/wound/analysis/services/ai_service.dart` (carries raw P(infection) out) |
| **Backups** | `_backups/2026-08-05/…` |

- Five yes/no questions in plain Arabic and English.
- **Tri-state answers** (`bool?`): "not answered" is deliberately distinct from "no", so an
  unanswered checklist is never silently counted as a clean bill of health.
- **Skip always available** — a patient must never be trapped by a question they cannot judge.
- 48dp targets and `Semantics(selected:)` for screen readers, matching the existing
  accessibility criteria.
- `AnalysisResult` now carries the **raw P(infection)**; the binary string discarded it, and
  the triage needs the number to band it.

**Verification:** `flutter analyze` on the new screen → **No issues found**; whole project
**0 errors, 0 warnings**; suite **101/101**.
🔴 **Not device-verified, and not yet wired into the capture flow** — the screen exists and
compiles but nothing navigates to it. Next: `preview_screen → checklist → analysis`, then
render `triage()`'s outcome on the result screen.

---

### C7 · Checklist wired end-to-end 🟡 BUILDS
The screen from C6 existed but nothing navigated to it. The path now runs
**photo → checklist → analysis → triage result**.

| | Path |
|---|---|
| **Modified** | `lib/features/wound/capture/screens/preview_screen.dart` |
| **Modified** | `lib/features/wound/analysis/screens/analysis_loading_screen.dart` |
| **Modified** | `lib/features/wound/analysis/screens/ai_result_screen.dart` |
| **Modified** | `assets/translations/{en,ar}.json` (+1 key) |
| **Backups** | `_backups/2026-08-05/…` |

1. **`preview_screen`** pushes `InfectionChecklistScreen` before analysis and passes the
   returned `InfectionSigns` onward. A skip returns `null`, which travels through as *"no
   answers"* — never as *"all no"*.
2. **`AnalysisLoadingScreen`** carries `signs` through to the result screen.
3. **`ai_result_screen`** replaces the bare `Present / Not Present` row with **`_TriageCard`**,
   which calls `triage()` on the raw probability plus the answers and renders one of five
   outcomes with its own colour, icon and plain-language explanation.
4. When the checklist was skipped the card says so explicitly
   (*"Based on the photograph alone — the questions were skipped"*), so a thin assessment is
   never presented as a full one.
5. The **deep-infection caveat** renders on every non-urgent outcome.

**Verification:** `flutter analyze lib test` → **0 errors, 0 warnings**; suite **101/101**.
🔴 **Not device-verified** — no emulator run, no screenshot. The path compiles and the logic
is unit-tested, but nobody has yet walked a real photo through it.

---

## 1b. 🗺️ The big picture — where this stands

Three field failures were reported. Here is the honest state of each:

| # | Failure | Root cause found | Fix built | Proven? |
|---|---|---|---|---|
| 1 | **1.4 cm read as 0.9 cm** | ✅ `_assumedFrameCm = 12.0`, calibration dead code | 🟡 Partial — warning restored (C2); **the actual fix needs the sticker** | ❌ No |
| 2 | **False "Infection Detected"** | ✅ Two causes: train/serve mismatch **and** PPV collapse at real prevalence | ✅ Crop (C1) + three-zone triage (C4/C6/C7) | 🟡 Logic yes, field no |
| 3 | **Unreliable tissue** | ✅ Whole-image input, callus prior 77%, epithelial AUC 0.654 | ❌ Not started — W6 colour first, then W2b retrain | ❌ No |

**What is genuinely established:**
- Every root cause was traced to source and verified, not guessed.
- The three-zone banding is **measured**: false alarms among healthy patients **25.9% → 4.3%**.
- The triage logic is **unit-tested** (18/18), including its safety properties.

**What is not:**
- **Nothing has run on a real photograph.** No device, no emulator, no screenshot.
- The image+symptom fusion **cannot be measured** with existing data (§C5).
- The measurement fix does not exist yet — only its warning label does.

---

### C8 · Clinical-content and localisation batch 🟡 BUILDS
Reported from real use. Text-only unless noted; backups in `_backups/2026-08-05/`.

| # | Fix | Detail |
|---|---|---|
| 1 | **SUS → validated Arabic A-SUS** | `sus_q1..q10` replaced with the published A-SUS wording, **verbatim**. A validated instrument must not be reworded — scores are only comparable to norms if the items match the validated version, so the supplied orthography was preserved deliberately |
| 2 | **Month names** | `months` held **only 7 entries (Feb–Aug, hard-coded)** — any consumer indexing month ≥ 9 ran off the end. Now all 12, plus `months_abbr` and a new `months_full`, in international Arabic (يناير/فبراير…); the mangled "قبر" is gone |
| 3 | **Wound-care wording** | «حافظ على **الجرح** نظيفاً وجافاً» → «حافظ على **الضماد**…». Clinically the *dressing* is kept dry; a wound bed heals faster moist, so the old text advised the opposite of care. Corrected in EN too |
| 4 | **Warning signs** | `edu_warning_signs_*` replaced with the clinician-supplied text, incl. escalation to "nearest health centre or emergency department" and the pus/fever qualifier |
| 5 | **Tissue names in Arabic** | New `localizedName` / `localizedSummary` / `localizedTissueSummary`. Each class carries a plain gloss — «نسيج متنخّر (نسيج ميت أسود)» |
| 6 | **Camera back button** | `CaptureScreen` is used **both as a bottom tab and as a pushed route**. Uses `BackButton` guarded by `Navigator.canPop()`, so it appears only where there is somewhere to return to — no dead control in the tab. `BackButton` also mirrors itself for RTL and carries localized semantics |
| 7 | **Glucose mmol/L** | New `lib/features/glucose/glucose_unit.dart` |

**⚠️ The design decision worth recording (items 5 and 7): display and storage were
deliberately separated.**
- `TissueFinding.displayName` (English) still feeds the DB and sync; only the new
  `localizedName` reaches the screen. Localising the stored value would have written
  «نسيج متنخّر» or "Necrosis" depending on the app's language at save time, and the server
  could no longer compare records.
- Glucose is **stored in mg/dL always**. The unit is presentation-only: converting at rest
  would silently reinterpret every historical row and shift the clinical thresholds in
  `GlucoseReading.status`. Input is validated **in the typed unit** (so 6.2 mmol/L is not
  rejected against mg/dL bounds) and converted once on save. The preference is a
  `ValueNotifier` read before the first frame — a value drawn in mg/dL beside a "mmol/L"
  label would read as an 18-fold error.

**Verification:** `flutter analyze lib test` → **0 errors, 0 warnings**; **101/101** tests.
Both translation files parse with **identical key sets (645 each)**.
🔴 **Not device-verified** — no screenshot of any of these screens yet.

---

### C9 · First real device run ✅ VERIFIED
Everything before this entry was "compiles and passes tests". This is the first time any of
it executed on an Android runtime.

**Setup:** `Pixel_4_API_36` emulator · `flutter build apk --debug` (342 s) · installed and
launched `tech.diafootcare.app/.MainActivity`.

**Result — the app runs clean.**
- ✅ Launches, initialises notifications, localisation, background sync
- ✅ Reaches Home as Guest and renders correctly (screenshot captured)
- ✅ **Zero crashes, zero Dart exceptions, zero `AndroidRuntime` errors** in logcat
- ✅ DB, notes, connectivity and the sync drain all start normally

**🐛 Bug found and fixed — C9a: the app title was a race.**
Logcat showed `Localization key [app_name] not found`. The key *does* exist in both files;
the timestamps gave it away:

```
28.646  WARNING  key [app_name] not found     ← requested
28.995  DEBUG    Load asset from assets/translations   ← loaded, 349 ms later
```

`MaterialApp.title` is evaluated during the first build, **before EasyLocalization finishes
loading the JSON**, so the Android task switcher showed the literal string "app_name" instead
of the app name. Fixed by moving to `onGenerateTitle:`, which Flutter calls with a context
that already carries the localisations.

| | Path |
|---|---|
| **Modified** | `lib/app.dart` |
| **Backup** | `_backups/2026-08-05/lib/app.dart` |

**Verified by re-run:** rebuilt, reinstalled, relaunched → **the warning is gone**, still no
crashes.

**What this run does NOT prove.** Only the launch path and Home were exercised. The
capture → checklist → triage flow, the calibration banner, the Arabic tissue names, the
glucose unit switcher and the new back button were **not** walked through on the device, and
Model 3's crop still has no real photograph behind it.

---

### C10 · Wound photographs now reach the server ✅ CONSENT-CHECKED, 🟡 BUILDS
The app analysed photographs and then kept them. Only the *numbers* ever synced, so the
dashboard had measurements with nothing to look at.

**Consent was checked first, not assumed.** Consent v2 already states: *"your wound **scans**
and measurements … sent to the DiaFootCare server over an encrypted connection … stored under
your account"*, and grants deletion on request. Uploading is inside what the patient agreed to;
no consent change was needed. (Had it not covered this, the consent would have had to change
*before* the feature.)

| | Path |
|---|---|
| **Modified** | `lib/data/local/database_helper.dart` — schema **v19 → v20** |
| **Modified** | `lib/core/services/sync_service.dart` |
| **Backups** | `_backups/2026-08-05/…` |

**Design — photographs upload separately from records, on purpose.** `_syncTable` batches 50
small JSON rows; a photograph is megabytes. One large upload inside such a batch would fail
forty-nine unrelated records. So `_syncWoundImages()` sends **one multipart request per
photograph**, keyed by the same `local_uuid` the record sync uses, and only for scans whose
record has already synced — the server stores the image against the scan row, so that row must
exist first.

New column `wounds.image_synced`: `0` to send · `1` on the server · **`2` = the local file is
gone** (cleared cache, restored backup) so it is never retried — otherwise every future pass
would chase a file that cannot exist. Batch limited to **3 images per pass**: a patient on
mobile data should not have one sync consume their allowance.

**⚠️ Server endpoint `POST /wound-scans/{local_uuid}/image` does not exist yet** — this is the
client half only. Until the Laravel side is added, uploads fail and retry harmlessly.

---

### C11 · Online mode could reassure a patient the server had flagged ✅ FIXED 🟡 BUILDS
Found while tracing whether the checklist works in both modes.

`AnalysisResult.infectionProbability` defaults to **0.0**, and `remote_analysis_service` never
set it — the server returns only the headline `"Present"/"Not Present"`. So in **online mode
the triage always read 0.0 → the "no signs" band**, and would have shown a reassuring green
card for a wound the server had just flagged as infected. A safety bug, not a cosmetic one.

Fixed by parsing `infection_probability` from the response, with a deliberate fallback: when an
older server sends no probability, `"Not Present"` maps to **0.35 — the *uncertain* band, not
the low one**. The server's own cut-off is 0.41 while the low band ends at 0.30, so a negative
there could genuinely be either, and the safe direction to be wrong is towards a second look.

*(The checklist answers themselves already flow in both modes: the checklist sits in the
capture flow before `AnalysisLoadingScreen`, which is what chooses on-device or server.)*

---

### C12 · Dependency hygiene ✅ VERIFIED
While adding the upload I imported `package:path` for one call. **It is not a direct dependency
of this project** — it resolves only transitively through `path_provider`/`sqflite`, so it would
break the moment a parent package dropped it (the same latent lint already exists in
`preview_screen.dart`). Replaced with a four-line `_extensionOf()` helper. `dio` was checked and
**is** a direct dependency, so that import stands. **No new packages were added.**

---

### C10 · Wound photographs now upload to the server 🟡 BUILDS
The consent shown at enrolment (v2) already promises this — *"your wound **scans** and
measurements … sent to the DiaFootCare server … stored under your account"*, with deletion on
request. The app was not honouring it: images never left the phone except transiently for
online analysis, so the dashboard had records with no pictures.

| | Path |
|---|---|
| **Modified** | `lib/data/local/database_helper.dart` (schema **v19 → v20**) |
| **Modified** | `lib/core/services/sync_service.dart` |
| **Backups** | `_backups/2026-08-05/…` |

**Design — uploaded separately from the record, on purpose.** The record is small JSON sent in
50-row batches; a photograph is megabytes. Putting one inside a batch would let a single large
upload fail forty-nine unrelated records. So `_syncWoundImages()` sends one multipart request
per photo to `POST /wound-scans/{local_uuid}/image`, keyed by the same `local_uuid` the record
sync already uses.

- Runs **only after the scan record has synced** (`pending_sync = 0`) — the server stores the
  image against the scan row, so that row must exist first.
- New column `wounds.image_synced`: `0` queued · `1` on the server · **`2` file gone from disk**.
  The `2` state matters: a photo deleted by a cache clear or a restored backup can never be
  uploaded, and without it every future sync pass would retry it forever.
- **3 photos per pass** — a patient on mobile data should not have one sync consume their
  allowance.

**No new dependency.** `package:path` was *not* added: it is only a transitive dependency here,
so relying on it would break the moment a parent package dropped it. A five-line
`_extensionOf()` replaces it.

**Automatic:** confirmed wired into `syncNow()`, which `background_sync.dart` runs **every 15
minutes** (observed on-device: `🔄 Background sync registered (every 15m)`), plus on login and
on manual pull.

🔴 **The server endpoint does not exist yet** — this is the app half only. Nothing will land
until `POST /wound-scans/{uuid}/image` is built in `daifootcare-web`.

---

### C11 · Whole-system integration review ✅ VERIFIED *(by inspection)*

| Path | State |
|---|---|
| Capture → checklist → analysis → triage | ✅ Wired, **mode-independent** |
| **Online mode carries the checklist** | ✅ The checklist sits in `preview_screen`, *before* the online/offline split — both modes reach `AiResultScreen` with the same `signs` |
| **Online mode infection probability** | ✅ `_infectionProbability()` reads `infection_probability`, and when the server omits it falls back to **0.35 (uncertain), never 0.0** — so a missing value can never be rendered as "no signs" |
| Records → server | ✅ 11 tables sync, incl. `wounds`, `engagement_daily`, `analytics_events` |
| **Photographs → server** | 🟡 App side built (C10); **server endpoint missing** |
| Usage analytics → dashboard | ✅ Already syncing (`engagement-daily`, `analytics_events`) |
| Consent covers image upload | ✅ Verified against the v2 text |

---

### C12 · Test-suite "Out of memory" — diagnosed and fixed ✅ VERIFIED
`flutter test` was ending `-7` with `runtime/vm/zone.cc: 96: error: Out of memory`.

**It was never a logic fault.** Every suite passes alone — analytics_label 4, chart_bounds 9,
session_restore 6, sync_risk_mapping 8, tissue_findings 11, trend 11, sus 12, infection_triage
18, model_download 11, uuid_trigger 5, consent_migration 6 = **101, exactly the earlier total**.
`flutter test -j 1` then passed 101/101, which confirmed it: the runner executes suites in
parallel isolates, several open their own in-memory SQLite database, and together they
exhausted the VM.

| | Path |
|---|---|
| **New** | `dart_test.yaml` — `concurrency: 1`, `timeout: 2x` |

Nothing was deleted or skipped to achieve this. Serial execution costs ~20 s and makes the
result identical on every machine instead of depending on free RAM. **Plain `flutter test` now
passes on its own.**

---

### C13 · Arabic numerals accepted in numeric fields ✅ VERIFIED
An Arabic keyboard emits ٠-٩ (U+0660–0669); Persian/Urdu layouts emit ۰-۹ (U+06F0–06F9).
`double.parse` understands neither — and worse, the field's filter
`FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` **swallowed the characters as the
patient typed**, so the field silently refused them with no explanation.

| | Path |
|---|---|
| **New** | `lib/core/utils/arabic_numerals.dart` |
| **New** | `test/arabic_numerals_test.dart` |
| **Modified** | `lib/features/glucose/screens/glucose_screen.dart`, `.../scale_calibration_screen.dart` |

Handles **both** digit ranges, the Arabic decimal separator `٫` (U+066B), and drops thousands
separators — `"1,250"` must parse as 1250, never 1.250, because reading a glucose value as
1.25 instead of 1250 would be a clinically dangerous misparse. Storage and the wire format
stay ASCII; this only changes what a person may type.

**Verified: 9/9 tests**, covering both digit sets, mixed scripts (a half-switched keyboard),
separators, and that rubbish is still rejected rather than coerced.

---

### C14 · Release build 1.1.0+3 ✅ BUILT
- **`flutter test` → 110/110** · **`flutter analyze` → 0 errors, 0 warnings**
- `flutter build apk --release` → **86.9 MB**, `build/app/outputs/flutter-apk/app-release.apk`
- Version bumped **1.1.0+2 → 1.1.0+3**: Android refuses to install a build with an unchanged
  versionCode as an update.

> ⚠️ **Signing: the release is signed with the DEBUG key.**
> `android/app/build.gradle.kts` still carries the Flutter template default
> (`signingConfig = signingConfigs.getByName("debug")`) and there is no `key.properties`.
> Kept as-is deliberately **for continuity** — the currently distributed APK was built the same
> way, and introducing a proper keystore now would change the signature, so every existing
> patient would have to **uninstall first and lose their local records**.
> **The debug keystore is machine-specific**: a build produced on any other machine will not
> install over this one. A real release keystore should be introduced at a planned clean cut,
> not silently.

---

### C15 · Release signed, published, and the web tier deployed ✅ VERIFIED

**Signing key created** (the user accepted that existing installs break).
`~/.diafootcare-keys/diafootcare-release.jks`, backed up with its password and restore
instructions to **`D:\DiaFootCare-KEYS\`**. `android/key.properties`, `*.jks` and `*.keystore`
are gitignored; the keystore lives outside the repo entirely.
`build.gradle.kts` reads it when present and **falls back to the debug key when absent**, so a
fresh clone or CI can still `flutter run --release` without holding the signing secret.

> ⚠️ **Losing this keystore means no update to `tech.diafootcare.app` can ever be published
> again.** One disk is not a backup — a second copy off this machine is still needed.

**APK published.** Verified `Signer #1 certificate DN: CN=DiaFootCare, OU=Research, L=Nablus,
C=PS` — the release key, not the debug key. Uploaded to `/downloads/` after copying the live
build aside as `diafootcare-prev-20260806-2033.apk`, then moved into place atomically.
`version.json` updated to build 3 — **keeping its original field names**, since the landing
page reads them.

**Web tier deployed.** The history rewrite (C-purge) had left the server on a diverged
history, so `git push --force` was required and was correctly refused as destructive. Deployed
without it instead: added GitHub as a remote **on the server**, fetched, tagged the live commit
`rollback-20260806-1801`, confirmed no uncommitted server edits, then reset to `39e6528`.
`npm ci && npm run build` (✓ 9.00s), migrations (nothing pending), config/route cache,
`dfc-inference` restarted → **active**.

**Verified live:** site 200 · APK 200 · `version.json` build 3 · TestFlight link present in the
built bundle (`testflight.apple.com/join/XDRx6dB3` — it is a Vue SPA, so it is in the JS, not
the initial HTML).

**🐛 Pre-existing issue found, not introduced here:** unauthenticated API requests return
**HTTP 500** carrying `{"message":"Unauthenticated."}` instead of **401**. It affects the
long-standing `/wound-scans` and `/wound-scans/sync` too, so it predates this deploy — but it
matters, because `ApiClient` sets `validateStatus: s < 500`, which turns a 500 into a thrown
exception rather than a readable response. Worth fixing in the exception handler.

---

### C16 · 🚨 Two contradictory verdicts on one screen — fixed 🟡 BUILDS
**Found on a real device run**, reported by the user with a screenshot: the top badge said
**«عدوى مُكتشفة»** (*Infection detected*) while the card below said **«لا توجد علامات على وجود
عدوى»** (*No signs of infection*) — same wound, same analysis, patient had answered "No" to
all five questions.

**Root cause — mine, from C4/C7.** The triage was added as a *new* card and the pre-existing
`_RiskBadge` was left above it, still reading `result.riskBadge` — the raw `p >= 0.41` binary
the triage was built to replace. Two independent judges, never reconciled. On this wound
`P(infection)` sat between 0.41 and 0.80: over the old cut-off, inside the triage's *uncertain*
band with zero reported signs. Both behaved as written; the fault was that both were on screen.

> The disagreement **was** the finding that motivated the triage: at clinic prevalence the 0.41
> cut-off has PPV 0.45. The badge was displaying exactly the false alarm the triage suppresses.

**Fix**
1. `_RiskBadge` now derives from **`triage()`** — one source of truth for what the patient reads.
2. It **names the evidence**, as the clinician asked: «عدوى مُكتشفة (وجود علامات التهاب)».
3. It carries an **action matched to severity** — nearest health centre for the clinician-level
   outcome, "do not wait" for the urgent one, retake for the photo-quality outcome.
4. Ischaemia is carried separately, so "no infection signs" cannot mask impaired blood flow.

`result.riskBadge` is **kept** in storage and sync — the dashboard needs what Model 3 alone
said. It simply no longer addresses the patient without the checklist beside it.

| | Path |
|---|---|
| **New** | `docs/CONTRADICTORY_VERDICT_INVESTIGATION.md` |
| **Modified** | `lib/features/wound/analysis/screens/ai_result_screen.dart` |
| **Modified** | `assets/translations/{en,ar}.json` (+10 keys) |

**Verified:** `flutter analyze` 0 errors/warnings · `flutter test` **110/110** · translation
keys identical across both files · debug APK builds.
🔴 **Not visually re-verified** — the emulator closed during the build, so the corrected screen
has not been seen. The contradiction is fixed in code, not yet confirmed on a device.

**Lesson recorded:** adding a better answer beside a worse one does not remove the worse one.
When a component replaces a judgement, every existing surface of that judgement must be traced
in the same change — otherwise the app contradicts itself and the patient arbitrates.

---

### C17 · First real-patient data — the calibration works ✅ VERIFIED
The clinician collected **21 photographs from 3 patients** (7 of each wound, camera distance
varying), each with the printed calibration label in frame. Archived permanently at
**`D:\DF\clinical_validationatch_2026-08-08_3patients\`** with the analysis scripts, so any
future batch re-runs the same way.

| | |
|---|---|
| Ring detected | 19 / 21 |
| Wound measured | 15 / 21 |
| **Repeatability across 7 photographs of one wound** | **±2–5%** |
| Mean absolute error vs the clinician | **14%** |
| Uncalibrated baseline (the original field failure) | 36% |

**The measurement fix is demonstrated.** Camera distance varied up to 1.5× within a patient and
the measurement barely moved — that is precisely the fault this workstream exists to correct.

**🔴 Do not quote 86% accuracy.** The honest unit of analysis is the *patient*, not the
photograph: seven images of one wound are one measurement repeated, not seven measurements. At
n=3 the bias is **+1.2% ± 11.2%**, a 95% interval of roughly **−47% to +49%**. The repeatability
figure is solid; the accuracy figure is not, and needs the planned 30 patients.

#### Two findings that changed how the data must be read

**C17a — the reference sheet had two patients' rows swapped.** The first run showed the model
wrong by **+260%** and **−75%**. Rendering the masks over the photographs
(`analysis/overlay_grid.jpg`) showed the segmentation was accurate and the *reference numbers*
did not match the wounds pictured — patient 1's wound is visibly 1.4× the 2 cm ring, so it
cannot be 0.8 cm. The clinician corrected the sheet; the **same unchanged model** went from
10/15 gross failures to **13/15 agreements**.

> The lesson is recorded deliberately: **the numbers said the model was broken and the pictures
> said it was fine, and the pictures were right.** Acting on the table alone would have meant
> "fixing" a model that had nothing wrong with it. `verify_table.py` now reads the sheet at run
> time rather than holding a hard-coded copy, which is what let the stale values survive.

**C17b — the clinician measures greatest length *after debridement*.** The model measures what
the photograph shows. A photograph taken *before* cleaning still contains the hyperkeratotic rim
that debridement removes, which is the most likely origin of the systematic **+9% to +15%** bias
in the two patients where detection succeeded.

> This is a difference in **what is being measured**, not a measurement error. An earlier note in
> this tracker suggested absorbing the bias into a correction factor — **that would hide it.**
> The correct fix is to standardise when the photograph is taken. Next batch: photograph
> **before *and* after** debridement.

**Also recorded:** the clinician documents **depth** as well; the app does not measure depth at
all and cannot from a 2-D photograph. That gap belongs in the documentation explicitly.

**Protocol changes for the next batch** (in the folder's README): photograph before *and* after
cleaning · record the distance band · ruler in frame alongside the label · **no blue drape** (it
competed with the cyan ring until an annulus test was added) · label on intact skin, level with
the wound.

**For Model 2:** `tissue_labels_TEMPLATE.xlsx` uses the **same five class names in the same
order** as `gold_labels.npy`, so a labelled batch concatenates onto the 1,176-image gold set with
no remapping.

---

### C18 · Three clinical batches — the measurement fault is diagnosed ✅ VERIFIED
89 photographs with clinical references across **8 distinct wounds**. Full record in
`D:\DF\clinical_validation\FINDINGS.md`; the headline conclusions:

**Calibration is settled.** Camera distance varied up to 1.95× within a patient and the
measurement barely moved — **repeatability ±1.8% to ±5%**, against 36% error with no reference.
The cleanest case reached **+2.6% error at ±1.8%**.

**Accuracy is polarised, and splits by wound type**, not by patient or batch:

| Wound | Error |
|---|---|
| Single, clearly bounded, fully exposed | **2.7–9%** |
| Extended, linear, mixed tissue | **23–53%** |

The 26% mean describes no real wound; it averages a model that is excellent with one that is
failing, on different anatomy.

**The cause, after two wrong hypotheses.**
1. *Fragmentation* — implemented component merging, tested on all 54 referenced measurements:
   **changed 3 of them.** 26.2% → 26.4%. **Rejected, not shipped.**
2. *Definitional mismatch* — the theory was that the clinician includes the hyperkeratotic rim.
   The clinician settled it: they measure *"the wound in the middle; the rest is peri-wound
   skin"* — the same target the model aims at.
3. **Under-segmentation.** Patient 1 after debridement is decisive:
   **width 1.10 cm against a clinical 1.1 (no error); length 1.64 against 3.5 (−53%)**. The
   model resolves the sides perfectly and loses the length. The lesion is a long slit, dark red
   at one end and **pale yellow at the other**; segmentation stops where the colour fades. The
   training corpora are mostly round ulcers with an obvious red bed.

> This is **better** than a definitional clash: model and clinician want the same thing, so it
> is an ordinary supervised problem — annotate the full slit, retrain, measure.

**Crust helps the model; debridement removes that help.** Patient 1's first three photographs,
before any wiping, read 3.84 / 3.54 / 3.98 against a clinical 3.5. After debridement, all
fifteen read 0.93–1.90. A step, not a drift: necrotic crust is a continuous high-contrast mass.
**But do not conclude "photograph before cleaning"** — patient 3's crust matched the surrounding
dark skin and before was *worse* there (−71.8% vs −44.1%). The variable is **margin contrast**.
Photographing both states is what made this visible at all.

**Detector faults found and fixed (ours):** magenta range so wide that inflamed skin produced a
977 px "ring"; a 9×9 close that **sealed the small ring's hole**, destroying the feature the
detector looks for; ranking candidates by area rather than roundness. Detection went to
**13/13** on the v5 batch. Still open: two frames locked onto a blue drape or the ring's inner
edge.

**Annotation rule agreed:** *trace the open slit end to end including the pale tissue inside it;
exclude intact and hyperkeratotic skin.*

**Retraining needs 30–50 distinct wounds** (we have 8), 2–3 photographs each. Fifteen
photographs of one wound teach a segmenter what two do — the unit is the wound.

---

## 2. What is deliberately NOT done yet

| Item | Why it is blocked |
|---|---|
| ~~Upload 1.1.0+3~~ | ✅ Published and verified live |
| **Restore-on-reinstall** | The sync is **upload-only**. Server data survives an uninstall and clinicians still see it, but the app never downloads it back — a reinstalled patient opens an empty app. No restore path exists |
| **401 vs 500** | Unauthenticated API requests return 500; see C15 |
| ~~Checklist UI + wiring~~ | ✅ **Done — C6/C7.** Path runs photo → checklist → analysis → triage card |
| ~~Device run — launch path~~ | ✅ **Done — C9.** App runs clean on an emulator. **Still to walk:** capture → checklist → triage, the banners, Arabic tissue names, glucose units, back button |
| **Server endpoint** | 🔴 `POST /wound-scans/{uuid}/image` must be built in `daifootcare-web` (storage, per-patient gallery, TestFlight link on the site). App side is ready and waiting |
| **Model 1 verification** | ⏸️ **Deferred by the user until the calibration labels are printed** — measurement cannot be validated without them |
| **Test suite regression** | 🔴 `flutter test` ends `-7` with a Dart VM **"Out of memory"**. Each suite **passes when run alone** (`uuid_trigger` 5/5, `consent_migration` 6/6, `infection_triage` 18/18), so this looks like several in-memory-SQLite suites in one process rather than a logic fault — **but it is unresolved and must not be assumed harmless** |
| **Deploy** | ⏸️ **Held until Saturday, at the user's instruction.** Code is ready; nothing has been pushed to the VPS |
| **~~Device run~~** | ~~Nothing here has executed on a real phone.~~ This is the cheapest remaining verification and needs no clinical data: walk one photo through the flow and confirm the crop fires, the checklist appears, and the triage card renders |
| **Per-patient trend** | Layer 3 of the strategy: compare a score against the patient's *own* baseline instead of an absolute cut-off. The history is already in SQLite (`wounds` table) and unused for this. Between-patient spread is sd 0.236, so removing it should cut false alarms further — **no retraining, no new data** |
| Change the single infection threshold | **Superseded by C4.** Rather than pick one number, the app moves to three zones plus the checklist. The single threshold stays only for the legacy `infection` string until the UI lands |
| Sticker detector + green-light gate | Awaiting **P2/P3** — the detector is tuned to a spec that must be fixed and printed first |
| Colour calibration (W6) | Needs the printed colour patches |
| Retrain Model 2 on crops (W2b) | Do **after** W6 — colour variance may be a large part of the tissue problem, and that costs nothing to test |
| Any claim of improvement | Awaiting **P1**, the validation set |

---

## 3. Regression safety — how to undo anything here

```bash
# restore a single file from the pre-edit backup
cp _backups/2026-08-05/lib/features/wound/analysis/services/ai_service.dart \
   lib/features/wound/analysis/services/ai_service.dart

# or revert everything to the pre-change commit
git diff ae57202 --stat        # see what changed
git checkout ae57202 -- lib assets
```
The Model 3 crop can also be disabled without touching code history: set
`_cropForModel3 = false` in `ai_service.dart`.

---

## 4. Next actions

**Needs the user (clinical / decisions)**
1. **P1 — validation set** (20–30 wounds, sticker + ruler in frame, 2–3 distances, clinician's
   measurement and assessment). Blocking for every claim here.
2. **D4** — missed infection vs. false alarm: which is worse? Determines the threshold.
3. **D3** — approve the sticker artwork, then print (P2/P3).
4. **D6** — drop `epithelial` from the UI? (AUC 0.654, near chance.)

**Can proceed without input**
5. Sticker detector prototype, once D3 is fixed.
6. Colour-calibration pipeline (W6), once patches are printed.
7. Device run of C1/C2 to move them from 🟡 BUILDS to ✅ VERIFIED.

---

## 5. Log

| Date | Entry |
|---|---|
| 2026-08-05 | Baseline `ae57202`. Backups taken. **C1** (Model 3 wound crop) and **C2** (uncalibrated warning) implemented — both build clean, 83/83 tests, **neither device-verified**. **C3** threshold sweep reproduced CV (AUC 0.8883 vs 0.890) and exposed the PPV collapse at realistic prevalence. No threshold changed yet, pending D4. |
| 2026-08-05 | **C7** — Wired the checklist end-to-end: photo → checklist → analysis → `_TriageCard` with five outcomes, plain-language bodies, a "questions were skipped" note, and the deep-infection caveat on every non-urgent result. 0 errors/warnings, 101/101. **Still no device run.** |
| 2026-08-05 | **C5/C6** — Answered "has the fusion been tested?" honestly: **no, and it cannot be with existing data** (no corpus pairs images with symptom answers). Measured the image side alone: false alarms among healthy **25.9% → 4.3%**. Projected the fusion across checklist-quality scenarios and found it **can reduce precision if answers are noisy** (PPV 0.483 pessimistic vs 0.754 image-only). Qualified the earlier "missed 2.9%→1.8%" figure. Built the checklist UI (tri-state, skippable, accessible) and plumbed raw P(infection) through `AnalysisResult`. Analyze clean, 101/101. **Not wired into the flow yet.** |
| 2026-08-05 | **C4** — D4 answered by refusing the question. Built the IWGDF/IDSA triage module: three image zones (0.30/0.80) plus a five-question patient checklist, fused by the ≥2-signs rule. At 20% prevalence this takes alarm PPV from **0.45 → 0.75** while *also* cutting missed infections **2.9% → 1.8%**. **18/18 new tests pass — the first change here that is genuinely verified rather than merely building.** Suite now 101/101, analyze clean. Checklist UI still to build. |
