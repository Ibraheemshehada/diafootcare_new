# DiaFootCare — Prototype / Design-Modification Log

**Version history and features added or changed between development rounds.**

This log records how the DiaFootCare prototype evolved across iterative rounds: the
mobile application, the three on-device AI models, the data layer, and the supporting
web/API tier. It is the single chronological source for *what changed, when, and why*.
Every entry is traceable to a commit on `main` (the repository history) or to the
detailed trackers and research documentation linked at the bottom.

- **App package:** `tech.diafootcare.app` (Android + iOS)
- **Current version:** `1.1.0+2`
- **Repository:** `github.com/Ibraheemshehada/diafootcare_new`
- **Release status:** internal/clinical-team testing — **not yet released to end users**
- **History span:** 2025-10-31 → 2026-08-03 · 90 commits on `main`

### Repository lineage
This repository (`diafootcare_new`) is the **third iteration** of the DiaFootCare mobile
app. The first two prototypes — [`diafootcare`](https://github.com/Ibraheemshehada/diafootcare)
(v1, Aug 2025) and [`diafootcarev2`](https://github.com/Ibraheemshehada/diafootcarev2)
(v2, Aug–Oct 2025) — were rebuilt into this one, the active codebase since 2025-10-31.
Sibling repositories: model training in [`DF`](https://github.com/Ibraheemshehada/DF)
(notebooks), tissue labelling in [`dfuc-annotator`](https://github.com/Ibraheemshehada/dfuc-annotator),
and the web / server tier — a Laravel API + Vue 3 dashboard + Python inference monorepo — in
[`daifootcare-web`](https://github.com/Ibraheemshehada/daifootcare-web). Full map in the [README](../README.md).

---

## 1. Application version history

| Version | Round(s) | Dates | Headline |
|---|---|---|---|
| **1.0.0+1** | R1 | 2025-10-31 → 2025-11-01 | Initial prototype: Model 1 wound analysis, history, export, reminders |
| **1.1.0+2** | R2–R5 | 2026-07-02 → 2026-07-30 | 3-model on-device pipeline, offline/online modes, sync, clinical suite, iOS-ready |
| *(docs)* | R6 | 2026-07 → 2026-08 | Research documentation + full model-metric verification (no app-code change) |
| **1.1.0+3** | R7 | 2026-08-05 → 2026-08-06 | Accuracy investigation: Model 3 wound-crop + IWGDF triage, image upload, Arabic input |
| **1.2.0+4** | R8 | 2026-08-08 → 2026-08-19 | Calibration ring: real centimetres, retrained Model 1, capture-angle block, overlay image |
| **1.2.1+5** | R9 | 2026-08-19 → 2026-08-20 | Scale and tilt reach the server; iOS camera format; admin analysis bench |
| **1.2.2+6** | R10 | 2026-08-20 → 2026-08-29 | Clinical wording, perfusion caveat, glucose unit choice, read-aloud voice selection |

Build numbers follow `major.minor.patch+build`. The local database schema advanced
independently from **v1 → v22** across these rounds (see §4).

---

## 2. Development rounds — features added / changed

### Round 1 — Initial prototype  ·  2025-10-31 → 2025-11-01  ·  `v1.0.0`
The first working app: capture a wound, measure it on-device, store and chart it.

**Added**
- **Model 1 (segmentation + measurement)** wired into the app with local SQLite storage and an auto-refreshing history screen.
- Wound capture screen (full-width preview, tips dialog) with ProGuard rules so the TFLite runtime survives release minification.
- Reminder notifications with a backup-timer fallback for Android reliability.
- Profile photo capture/selection; "What's New Today" home widget (next reminder + last-week progress).
- Data export in **PDF / CSV / Excel**; real progress chart with week-over-week comparison; notifications screen; change-password.

### Round 2 — Clinical feature expansion  ·  2026-07-02 → 2026-07-09  ·  toward `v1.1`
The app grew from a single wound tool into a diabetic-foot self-management suite, and the **second AI model** landed.

**Added — AI**
- **Model 2 (tissue classification)** integrated into the app (`add model2 to the app`, 2026-07-02).
- Tissue result reports **every tissue type found**, not one winning label (multi-label surfacing).

**Added — clinical modules**
- Glucose monitoring 🩸, medication management 💊, self-care / daily check-ins.
- Home health **dashboard** with a DFU-status hero (risk badge derived from infection/ischaemia).
- Appointments & alerts, patient-reported outcomes / **QoL "My Well-being"**, education & pharmacist support, engagement/usage analytics.
- Wound **depth entry** (manual) and **Arabic localization** (RTL); guest login.

**Added — quality / accessibility**
- **System Usability Scale (SUS)** with a participant declaration + usability instrumentation.
- Accessibility pass: **WCAG AA** contrast, text scaling, TalkBack semantics, dialog-based (not SnackBar) save/error UX, **voice assistant** (`flutter_tts`, Arabic `ar-xa`).
- Daily / Weekly / Monthly trend charts; portrait-orientation lock; AI-model **preload** on camera open (removed the model-load freeze).

**Changed / fixed**
- "No wound detected" dialog instead of a `0×0` result; fixed the analysis-result crash on zero-area wounds; dark-theme fixes.

### Round 3 — Offline-first foundation (Phase 1 close)  ·  2026-07-18
The app was rebranded and given an offline-first identity + sync backbone. *(Phase 1 closed — see [OFFLINE_MODE_STATUS.md](../OFFLINE_MODE_STATUS.md).)*

**Added**
- Real branding: launcher icon + name **"DiaFootCare"**.
- **DiaFootCare API replaces Firebase** as the identity provider; **versioned data-sharing consent** replaces the on-device-only consent.
- **Offline-first sync queue** + background sync (records upload while the app is closed); in-app sync-state indicator; daily engagement-event rollup.

**Changed / fixed**
- `local_uuid` assigned by a **SQLite trigger at insert** (not by convention); fixed sync never marking records as sent (which re-uploaded them forever); signed-in patients no longer locked out when offline.

### Round 4 — Online / Offline modes & model delivery (Phase 2–3)  ·  2026-07-19 → 2026-07-20
The defining architectural round: the user chooses a mode, and the models are delivered rather than bundled. *(See [PHASE2_TRACKER.md](../PHASE2_TRACKER.md) · [PHASE3_TRACKER.md](../PHASE3_TRACKER.md).)*

**Added**
- **First-run online/offline mode choice**; the app reports the *real* active mode.
- **Resumable, verified model download** of the ~208 MB analysis bundle; `AiService` loads the downloaded files and **falls back to bundled assets**.
- **Online mode** routes inference to the server, with mode-stable labels.
- Analyse an **existing photo** / gallery picker, not only a fresh capture.

**Changed / removed**
- **Models removed from the APK** (unbundled) — the download bundle is now the delivery channel.
- Photo-upload-with-consent was added then **reverted** (kept the privacy guarantee simpler).
- Sync corrected to **report ischaemia and stop inventing infection**, and to record the real source.

### Round 5 — iOS / TestFlight hardening & 1.1.0 release  ·  2026-07-21 → 2026-07-30  ·  `v1.1.0+2`
Production hardening, measurement cleanup, and iOS readiness. *(See [IOS_TRACKER.md](../IOS_TRACKER.md).)*

**Added / changed**
- Settled **bundle identifier `tech.diafootcare.app`** on both platforms; removed the dead Firebase config; pinned Flutter with **fvm**; made the iOS project **archivable for TestFlight**.
- Defaulted to the **production API** (not the emulator loopback); stopped rejecting the manifest's own JSON metadata; performance: lazy tab build, non-blocking launch / permission / logout.
- **Removed wound depth & scale calibration** from the capture flow — a 2-D photo cannot recover true depth or absolute scale; measurement is now length / width / **true segmented area** with a relative-area healing trend.
- **Added true wound area** (segmented cm², persisted); Settings → Terms fix; **bumped to `1.1.0+2`**; code-review pass (incl. the `_calculateArea → _areaMm2` rename build-fix).

### Round 6 — Research documentation & model-metric verification  ·  2026-07 → 2026-08  *(current)*
No application-code change; the models and app were documented and their metrics independently **re-computed and validated**.

**Added / changed**
- Authored the **Full / Models / System** research documentation (editable HTML → stamped PDF pipeline, see [build_pdf.md](build_pdf.md)).
- Corrected Model 1 throughout to the deployed **384 px v1.1** (FUSeg-primary, Dice **0.873**) — an earlier draft described the superseded 320 px model.
- Built and filled the **performance-metric table** (Dice, accuracy, sensitivity, specificity) for all three models; sensitivity/specificity **computed and validated** by reproducing each model's evaluation (Model 1 per-pixel on FUSeg; Model 2 CLIP-SVM out-of-fold; Model 3 grouped CV).
- **Verified dataset counts** against the actual artefacts: Model 2 gold set **366 + 810 = 1,176**; Model 3 **5,955 + 1,447 = 7,402**.
- Added this **design-modification log** and reorganised the repository README as the project hub.

### Round 7 — Accuracy investigation and clinical triage · 2026-08-05 → 2026-08-06 · `v1.1.0+3`
Triggered by three failures observed on a **real patient**, not by a backlog: a 1.4 cm wound
measured as **0.9 cm**, a false **"Infection Detected"** on a healthy patient, and unreliable
tissue results. Every cause was traced to source before anything was changed
([ACCURACY_IMPROVEMENT_PLAN](ACCURACY_IMPROVEMENT_PLAN.md) · [IMPLEMENTATION_TRACKER](IMPLEMENTATION_TRACKER.md)).

**Model 3 — infection: the input was wrong, and the question was wrong**
- **Train/serve mismatch found.** Model 3 was trained *exclusively* on tight wound patches
  (DFUC2021 224×224, Part B 256×256) and had **never seen a whole foot**, yet the app fed it a
  centre crop of a whole-foot photograph — ~5% wound, 95% background. It now receives the crop
  Model 1 locates. **No retraining needed.**
- **The threshold was never the answer.** Every threshold sits on one ROC curve, so sensitivity
  is only bought with specificity; at clinic prevalence the deployed 0.41 cut-off has **PPV
  0.45** — wrong more often than right. Getting both needs *more information*.
- **Five IWGDF/IDSA questions added** — only the signs a camera cannot capture (warmth,
  tenderness, smell, swelling, systemic upset). Combined with a three-band image score
  (<0.30 / 0.30–0.80 / >0.80). Measured on the reproduced CV: **false alarms among healthy
  patients 25.9% → 4.3%**.
- **Two contradictory verdicts fixed** — the badge said "Infection detected" while the card
  below said "no signs", for one wound ([investigation](CONTRADICTORY_VERDICT_INVESTIGATION.md)).

**Model 2 — tissue: unchanged, and deliberately so.** It was trained on *whole* photographs,
so cropping it would create the same mismatch in the opposite direction. It stays on the whole
frame until its head is retrained on crops.

**Model 1 — measurement: diagnosed, not yet fixed.** Without a scale reference the centimetres
come from a hard-coded `_assumedFrameCm = 12.0` and scale with camera distance — the whole of
the 1.4 → 0.9 error. The warning saying so is restored; **the real fix needs the printed
calibration sticker** (Ø20 mm cyan annulus + colour patches + ArUco/QR), which is designed and
awaiting printing. Deferred by decision until the labels exist.

**App — other changes**
- Wound photographs now **upload to the server** (schema **v19 → v20**, resumable, 3 per pass)
- **Arabic numerals** (٠-٩ and ۰-۹) accepted in numeric fields — an Arabic keyboard's digits
  were previously filtered away as the patient typed
- Tissue names shown **in Arabic** (display only; storage stays English so records stay comparable)
- Validated **Arabic A-SUS** wording replaces the previous translation
- Camera screen can be **backed out of**; months fixed (12 international names, was a 7-item slice)
- **Release signing key created** — existing installs must reinstall once
- `dart_test.yaml` pins test concurrency to 1: parallel in-memory SQLite suites were aborting
  the Dart VM with "Out of memory"

**Web tier — deployed**
- `POST/GET /wound-scans/{uuid}/image` — photographs stored on the **private** disk, streamed
  through an authorising endpoint, 404 (not 403) for the unauthorised
- Photographs in the **scan feed** and, newly, in the **patient record** with a scan viewer
- **iOS TestFlight link** on the landing page
- All VPS identifiers purged from the repo and its history

**Known and carried forward:** nothing above is verified on a device beyond the launch path;
sync is **upload-only** (a reinstalled patient opens an empty app); unauthenticated API requests
return 500 instead of 401. **The iOS voice-assistant fix is *not* in this build** — it is
scheduled for the next one.

### Round 8 — Calibration, and measuring the right thing · 2026-08-08 → 2026-08-19 · `v1.2.0+4`
The deferred fix from Round 7. A printed label with a **2.0 cm cyan annulus** (1.5 cm magenta on
the compact label) gives the photograph a scale, so `pixelsPerCm = major_px / ring_cm` — a pure
ratio needing no camera intrinsics, which is what lets one label work across every phone in a
study. Full derivation, including why the *major* axis survives tilt, in
[MEASUREMENT_METHOD](MEASUREMENT_METHOD.md).

**Measured on real patients, at two hospitals, against clinicians' tape.**
- Calibration itself is accurate to **±1.8–5%**. The residual error is segmentation, not scale.
- Tilt is not a detail: mean error **18.1%** at ≤30°, **39.6%** at 30–40°, **55.8%** past 40°
  (r = +0.479). Ten of 26 clinic photographs were past 40°.

**Guided capture.** The camera reads the ring live, shows the angle in degrees, and **will not
take the photograph past 40°**. Telling a patient afterwards is telling them to undress the
wound again, and nobody does. A missing label leaves the shutter enabled on purpose — the check
is blind then, and some clinics photograph without the label; those scans are recorded as
estimates.

**Label design.** An annulus: the central aperture is the decisive detection test, and solid
circular regions are excluded by it. Circular geometry: the projection of a circle yields the
scale and the viewing angle from the same contour, which fiducial markers do not. Two diameters
(2.0 cm cyan, 1.5 cm magenta for confined sites), with **hue determining the assumed diameter**,
so the hue bands are widely separated. A printed ruler for clinician verification. Full
specification in [MEASUREMENT_METHOD §2](MEASUREMENT_METHOD.md#2-the-calibration-label).

**Label exclusion from the wound mask.** Two independent mechanisms: clinical fine-tuning of
Model 1, and a model-independent post-processing guard keyed on the label's white substrate.
Chromatic separation is not viable — ink fraction within granulation spans 0.37–0.60,
overlapping the printed range. **The deployed model segments no calibration label in the
evaluation set: 0 of 42.**

**Model 1 v1.2 (deployed).** Fine-tuned on the Kaggle platform from the v1.1 weights, encoder
frozen, on 31 clinical wounds with 61 manually delineated reference outlines. Manual delineation
was selected as the training target on measured grounds: 9.6–11.8% error against clinician tape,
with ±5.8% test–retest agreement against ±15.0% for automatic masks. Mean error against tape
**13.3% → 12.7%**; held-out Dice clinical 0.803 → **0.869**, FUSeg 0.854 → **0.861**.

**The overlay image.** Every result now carries a rendered image of *what the model measured* —
red mask, green ring ellipse. Before it existed, a clinician could not tell a correct
measurement from one taken off the printed label. Stored, synced, and shown on the dashboard.

**Two bugs found only by running on a device**
- `RegExp(r'[/\]')` in the sync path — an unterminated character class that threw on **every**
  image upload. No wound photograph had ever reached the server, for the life of the feature.
- `CREATE TABLE wounds` had never been updated when columns arrived by migration, so a **fresh
  install** could not save a scan at all (`no column infectionProbability`). Every upgrading
  device — that is, every developer's phone — was fine. `PRAGMA user_version` said 22 in both
  cases. A schema-parity test now compares a fresh database against a migrated one.

Schema **v19 → v22**: `overlayPath`, `pixelsPerCm`, `tiltDeg`.

---

### Round 9 — The joint between phone and server · 2026-08-19 → 2026-08-20 · `v1.2.1+5`
**The calibration never left the phone.** `wound_scans` had held `pixels_per_cm`, `tilt_deg` and
`is_calibrated` since the overlay shipped, and the dashboard had badges built to read them.
Nothing wrote them: the sync endpoint did not accept the fields and the app did not send them.
Every scan a patient took arrived with a blank scale and a blank tilt, and the badges were
decoration. Each side was complete on its own; only the joint was missing, and nothing had ever
crossed it in a test. `integration_test/sync_to_server_test.dart` now walks sign-up → device
registration → scan → sync → photograph → overlay against a **local** server.

**iOS live guidance was dead on arrival.** The capture screen requested `ImageFormatGroup.yuv420`
unconditionally. iOS accepts it and returns a **two-plane** biplanar buffer; Android returns
three. The frame reader needs three and returns null otherwise, so every iOS frame would have
been dropped — no ring, no angle, no guidance — while the shutter stayed enabled, because "no
label in view" is treated as "cannot judge". The feature would have looked present and done
nothing. iOS now gets `bgra8888`.

**An admin analysis bench** (`/analysis-probe`, admin only). Checking what the models make of a
photograph used to mean creating a patient, installing the app and taking a scan — which then
sat in the study's own data as a real measurement of a real person. The bench forwards one
upload to the sidecar and shows the answer, **persisting nothing**: no scan, no patient, no
engagement event, no stored file. Asserted by test rather than trusted.

---

### Round 10 — Wording the clinicians asked for · 2026-08-20 → 2026-08-29 · `v1.2.2+6`
**Tissue names in Arabic now say what the tissue looks like**, not what it is called.
«نسيج متنخّر» is correct and means nothing to a patient reading it over their own foot;
«نسيج أسود ميت» is the thing they can see. All five classes changed.

**The perfusion caveat, on every result** — including "Adequate", especially "Adequate". The
model reads colour and texture; it does not palpate a pulse, run a Doppler or take an ankle
pressure. A reassuring word about a foot that is actually ischaemic is the most dangerous
sentence this screen can produce.

**Confidence figures came off the tissue card.** They read backwards in the clinic:
"Necrosis 36%" against a 60% threshold means the model did **not** find necrosis, and was read
as *some* necrosis. Thresholds are not uniform across classes (0.09–0.63), so the same
percentage means different things on different rows. Each class now shows **Found** or
**Not found**; the probabilities stay in the record and in the study data.

**The glucose unit** was a suffix inside the field and nothing else — to change it you left the
dialog, found a menu behind it, switched, and started again. It is now a visible choice above
the number, each option showing a typical reading ("e.g. 110" / "e.g. 6.1"), and switching
**converts what is already typed**: 110 mg/dL left as 110 mmol/L is not a survivable blood
sugar and would have been stored as one.

**Read-aloud failed silently and picked its own voice.** The service asked for `ar-SA`, a tag no
Android engine lists — Google ships Arabic as `ar` with voices named `ar-xa-x-ard-local`.
`isLanguageAvailable` answered true anyway, because Android matches loosely, and the engine then
chose for itself; and when no voice existed the button flickered and said nothing. Voices are
now ranked and set explicitly (locale, then reported quality, then installed over streaming —
this app is used offline), and a failure tells the patient to install a voice.

**A test that failed on working code.** The first infection assertion looked for
"See a clinician" while the screen says "Please see your clinician". Assertions now compare
against the translated strings; one written from memory sends someone hunting a bug in the app.

---

## 3. AI model design evolution (the "prototype" of the intelligence)

Each model went through explicit design iterations; the **deployed** configuration is bold.

### Model 1 — Wound segmentation & measurement
| Iteration | Design | Data | Result |
|---|---|---|---|
| v1.0 | U-Net + MobileNetV2, **320 px** | DFUTissue crops (~75) | DFUTissue-crop test Dice 0.818 |
| **v1.1 (deployed)** | **384 px** U-Net + MobileNetV2 + **scSE** decoder attention; loss 0.5·BCE + Focal-Tversky; `val_dice` checkpointing; deep fine-tune; **8-view TTA** | **FUSeg** (810 tr + 200 val, primary) + DFUTissue (~93 ×4) + Medetec (~152) ≈ **1,270 precise** | **FUSeg val Dice 0.873** · Sens 0.892 · Spec 0.998 · ~12.4 MB fp16 |
| **v1.2 (deployed 2026-08-19)** | v1.1 fine-tuned on manually delineated clinical outlines; trained on Kaggle (P100), encoder frozen, clinical corpus mixed with the original training data | **31 clinical wounds**, 61 reference outlines, two hospitals | Clinical Dice 0.803 → **0.869** · FUSeg 0.854 → **0.861** · tape error 13.3% → **12.7%** · **0 of 42** labels segmented as wound |

> **Acceptance criterion.** Comparative error is evaluated over the intersection of wounds
> measurable by both versions (n = 11): 13.32% (v1.1) against 12.69% (v1.2). Wounds measurable
> only by v1.2 are reported separately and excluded from the paired mean.

> **Accuracy in context.** Hand-drawn outlines of the same wounds reach 9.6–11.8%, so 12.7% is
> near the ceiling this training target implies, not near a ruler. Repeatability: ±15.0% for the
> model, ±5.8% for a boundary drawn to a fixed rule. 31 wounds is short of the 30–50 target at
> which these percentages become a result rather than a reading.

### Model 2 — Tissue classification
| Iteration | Design | Result |
|---|---|---|
| From-scratch CNN | CNN trained on tissue crops | Never left chance — **rejected** |
| **Frozen CLIP + SVM (deployed)** | Frozen **CLIP ViT-B/32** (512-d) + per-class **RBF-SVM**, exported as TF ops ("SVM-as-TFLite"); single-label → **multi-label 5 classes** (fibrin dropped) | Gold set **1,176** (366 Source-A + 810 DFUC 2020) · **AUC 0.825 · F1 0.733 · Sens 0.775 · Spec 0.735** |

### Model 3 — Infection & ischaemia
| Iteration | Design | Result |
|---|---|---|
| **Shared CLIP + MLP (deployed)** | Reuses Model 2's frozen CLIP backbone + a small **MLP head** (4-class softmax) → **two derived binaries** P(infection)@0.41, P(ischaemia)@0.61; StratifiedGroupKFold(5) | **7,402** images (DFUC 2021 5,955 + Part B 1,447) · Infection **AUC 0.890 / Sens 0.878 / Spec 0.728** · Ischaemia **AUC 0.987 / Sens 0.862 / Spec 0.977** |

> One frozen CLIP backbone is loaded **once** and shared by Models 2 and 3, keeping the on-device footprint practical. Full methodology and the validated metric table are in the [Models Documentation](DaiFootCare_Models_Documentation.pdf) and [Full Documentation](DaiFootCare_Full_Documentation.pdf).

---

## 4. Data layer & schema evolution
The local SQLite schema migrated forward without data loss (guarded `onUpgrade` steps),
reaching **v19** (`DatabaseHelper.schemaVersion`). Key milestones:

- **v10** `analytics_events` · **v11** `sus_responses` (usability study) · **v12** `analytics_events.value`
- **v13** `consents` table + `sus_responses.consent_version` (versioned data-sharing consent)
- **v14–v15** offline-sync columns + `engagement_daily` rollup table (Round 3)
- **v16** `local_uuid` insert-trigger + backfill of missing ids (Round 4)
- **v17** `wounds.tissueFindings` (per-class multi-label tissue) · **v18** `wounds.analysedOn`
- **v19** `wounds.area` — true segmented area in cm² (Round 5); older rows stay NULL and fall back to length × width on read
- **v20** wound photographs upload to the server (Round 7)
- **v21–v22** `wounds.overlayPath`, `pixelsPerCm`, `tiltDeg` — what the model measured, and how it
  was scaled (Round 8)

> **A migration is only half a schema.** `CREATE TABLE wounds` was never updated as columns
> arrived by `ALTER`, so a **fresh install** got a table without `infectionProbability` or
> `image_synced`: every save failed and every sync pass threw, for new users only. Anyone
> upgrading — every developer's own phone — was fine, and `PRAGMA user_version` reported the
> current version in both cases. `test/schema_parity_test.dart` now walks the oldest shipped
> shape through every migration and compares it, column by column, against a freshly created
> database.

Every step is additive and guarded (a failed `ALTER` cannot block the database from opening), so existing installs auto-migrate with no wipe.

---

## 5. System tiers (context for the app rounds)
The mobile app is one of three tiers, added in Rounds 3–4:

- **Mobile app** — this repository (Flutter, on-device inference + online mode).
- **Web / server tier** — the [`daifootcare-web`](https://github.com/Ibraheemshehada/daifootcare-web) monorepo:
  - **API** — Laravel backend: identity, sync ingestion, model manifest/hosting.
  - **Dashboard** — Vue 3 clinician web dashboard: patient list, scans, detail.
  - **Inference service** — a Python/FastAPI service performs Mode-A (server) inference, since PHP has no TFLite runtime.

Deployment topology and the online/offline decision are documented in the [System Documentation](DaiFootCare_System_Documentation.html).

---

## 6. Related documents (how everything links together)
| Document | What it covers |
|---|---|
| [README](../README.md) | Project hub — overview, structure, links |
| [MEASUREMENT_METHOD](MEASUREMENT_METHOD.md) | **The equations** — ring calibration, tilt, PCA extents, area, triage rule, unit conversion, with the measured accuracy |
| [Full Documentation (PDF)](DaiFootCare_Full_Documentation.pdf) · [HTML](DaiFootCare_Full_Documentation.html) | Complete research doc: datasets, methodology, results, metric table |
| [Models Documentation (PDF)](DaiFootCare_Models_Documentation.pdf) | Focused AI-models technical reference |
| [System Documentation (HTML)](DaiFootCare_System_Documentation.html) | App + API + dashboard integration and deployment |
| [FEATURE_TRACKER](../FEATURE_TRACKER.md) | Round-2 clinical feature checklist & QA state |
| [PHASE2_TRACKER](../PHASE2_TRACKER.md) · [PHASE3_TRACKER](../PHASE3_TRACKER.md) | Rounds 3–4: modes, sync, model delivery |
| [IOS_TRACKER](../IOS_TRACKER.md) | Round-5 iOS / TestFlight readiness |
| [OFFLINE_MODE_STATUS](../OFFLINE_MODE_STATUS.md) | Phase-1 offline-capability declaration |
| [demo/DEMO_STORYBOARD](../demo/DEMO_STORYBOARD.md) | Screen-by-screen walkthrough (fictional demo data) |

---

*Maintenance: append a new round section (and a row to §1) at the end of each development cycle; keep the deployed model configuration in §3 in sync with the exported artefacts. Datasets and raw model binaries are intentionally **not** stored in this repository.*
