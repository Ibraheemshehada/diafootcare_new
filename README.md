# DiaFootCare

**On-device AI for diabetic-foot-ulcer (DFU) assessment.** A Flutter application that
photographs a wound and, entirely on the phone (or via an online mode), **segments and
measures** it, **classifies its tissue types**, and estimates **infection and ischaemia
risk** — then tracks healing over time and supports diabetic self-management.

- **Package:** `tech.diafootcare.app` (Android + iOS) · **Version:** `1.1.0+2`
- **Status:** internal / clinical-team testing — **not yet released to end users**
- **Doctoral research project** — all demo/dashboard screenshots use fictional data.

> ⚠️ Research prototype, not a medical device. Outputs are a monitoring aid, not a
> diagnosis. Datasets and raw model binaries are **not** stored in this repository.

---

## The three on-device models

| # | Model | Task | Approach | Deployed metric |
|---|---|---|---|---|
| 1 | **Segmentation** | wound mask → length / width / area | U-Net + MobileNetV2 + scSE, 384 px | FUSeg val **Dice 0.873** · Sens 0.892 · Spec 0.998 |
| 2 | **Tissue** | 5 tissue types present (multi-label) | frozen CLIP ViT-B/32 + RBF-SVM | **AUC 0.825 · F1 0.733** · Sens 0.775 · Spec 0.735 |
| 3 | **Infection & ischaemia** | risk badge | shared CLIP + MLP head | Infection **AUC 0.890** · Ischaemia **AUC 0.987** |

A single frozen CLIP backbone is loaded once and shared by Models 2 and 3. Full
methodology and the validated metric table are in the [documentation](#documentation).

---

## Key capabilities
- **Wound analysis:** capture or pick a photo → mask, measurement, tissue breakdown, risk badge, healing trend.
- **Offline & online modes:** a first-run choice — fully on-device inference, or server-backed inference with a downloadable model bundle.
- **Clinical suite:** glucose, medication, self-care, appointments, quality-of-life, education, engagement analytics.
- **Sync:** offline-first queue with background upload to the DiaFootCare API; clinician web dashboard.
- **Accessible & bilingual:** WCAG-AA pass, screen-reader semantics, voice assistant, English + Arabic (RTL).

---

## Repository structure
```
lib/                     Flutter app source (features, data, core services)
assets/models/           TFLite models (via Git LFS) + JSON metadata manifests
docs/                    Research & system documentation, figures, PDF build tooling
demo/                    Screen-by-screen storyboard + UI screenshots (fictional data)
test/ integration_test/  Widget, unit and integration tests
android/ ios/ web/ …     Platform projects
*_TRACKER.md             Per-round development trackers
```

## Documentation
| Document | Contents |
|---|---|
| **[Design-Modification Log](docs/DESIGN_MODIFICATION_LOG.md)** | **Version history & features changed between rounds (start here)** |
| **[Measurement Method](docs/MEASUREMENT_METHOD.md)** | **The equations** — the calibration label, how pixels become centimetres, tilt, area, triage, and the measured accuracy |
| [Full Documentation (PDF)](docs/DaiFootCare_Full_Documentation.pdf) · [HTML](docs/DaiFootCare_Full_Documentation.html) | Complete research doc: datasets, methodology, results, metric table |
| [Models Documentation (PDF)](docs/DaiFootCare_Models_Documentation.pdf) | Focused AI-models technical reference |
| [System Documentation (HTML)](docs/DaiFootCare_System_Documentation.html) | App + API + dashboard integration & deployment |
| [Demo storyboard](demo/DEMO_STORYBOARD.md) | Screen-by-screen walkthrough |
| Trackers | [Features](FEATURE_TRACKER.md) · [Phase 2](PHASE2_TRACKER.md) · [Phase 3](PHASE3_TRACKER.md) · [iOS](IOS_TRACKER.md) · [Offline status](OFFLINE_MODE_STATUS.md) |

---

## Getting started
```bash
fvm flutter pub get         # dependencies (Flutter version is pinned via fvm)
fvm flutter run             # run on a connected device / emulator
fvm flutter test            # widget + unit tests
```
Models are pulled through **Git LFS** — run `git lfs install` once, then `git lfs pull`.
In the app, models are otherwise delivered at runtime (offline bundle download or online mode).

## Project repositories & version lineage
This is the **third and current** iteration of the DiaFootCare mobile app — earlier
prototypes were rebuilt into this repository. The models, labelling tool, and web tier
live in sibling repositories.

| Repository | Role | Stack | Visibility |
|---|---|---|---|
| [diafootcare](https://github.com/Ibraheemshehada/diafootcare) | Mobile app — **v1**, first prototype (Aug 2025) | Flutter | public |
| [diafootcarev2](https://github.com/Ibraheemshehada/diafootcarev2) | Mobile app — **v2** (Aug–Oct 2025) | Flutter | public |
| **diafootcare_new** — *this repo* | Mobile app — **current** (Oct 2025 →) | Flutter | public |
| [DF](https://github.com/Ibraheemshehada/DF) | Model training & experiments (notebooks) | Jupyter | public |
| [dfuc-annotator](https://github.com/Ibraheemshehada/dfuc-annotator) | DFU tissue-label annotation tool | HTML/JS | public |
| [daifootcare-web](https://github.com/Ibraheemshehada/daifootcare-web) | Web tier — Laravel API + Vue 3 dashboard + Python inference (monorepo) | Laravel · Vue · Python | public |

*The v1 / v2 app repos are kept for history; active development is here. Datasets and raw
model binaries are not stored in any of these repositories.*

## System tiers
DiaFootCare is a mobile app (this repo) plus a **web / server tier** — a **Laravel API**,
a **Vue 3 clinician dashboard**, and a **Python inference service** (Mode-A, since PHP has no
TFLite runtime) — together in the
[daifootcare-web](https://github.com/Ibraheemshehada/daifootcare-web) monorepo.
Architecture and deployment are covered in the [System Documentation](docs/DaiFootCare_System_Documentation.html).

---
*Built with Flutter · TensorFlow Lite · CLIP. See the [Design-Modification Log](docs/DESIGN_MODIFICATION_LOG.md) for the full evolution.*
