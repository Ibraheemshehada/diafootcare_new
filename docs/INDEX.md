# DiaFootCare — documentation index

One page for: **where the report is**, **what changed in every version**, and
**how the repositories fit together**.

---

## Which file do I open?

> ### → [`DaiFootCare_Full_Documentation.pdf`](DaiFootCare_Full_Documentation.pdf)
>
> **That is the report.** Version 1.2 · 31 August 2026 · 24 pages. If you were
> sent here to read or review the documentation, open that file and ignore
> everything else on this page.

The other copies exist for specific reasons and are **not** alternative reports:

| If you are… | Open | Not |
|---|---|---|
| reading, reviewing, printing, or sending it to someone | the **PDF** | anything else |
| editing the report | the **HTML** — the PDF is generated from it | the PDF or the Word file; those edits are lost at the next render |
| a reviewer who must use track-changes | the **Word** edition | — |
| looking for the equations only | [MEASUREMENT_METHOD.md](MEASUREMENT_METHOD.md) | — |
| looking for what changed and when | [§2 Version history](#2-version-history) | — |

All three carry the same content. They are one report in three formats, not
three documents.

Everything linked here is in this repository unless the link points elsewhere.
Datasets, patient photographs and raw model binaries are deliberately **not**
stored in any DiaFootCare repository.

---

## 1. The report

The full research documentation exists in three formats. They carry the same
content; they are not three documents.

| Format | File | Use it for |
|---|---|---|
| **PDF** | [`DaiFootCare_Full_Documentation.pdf`](DaiFootCare_Full_Documentation.pdf) | **Reading and sharing.** 24 pages, page furniture, fixed layout. This is the one to send. |
| **HTML** | [`DaiFootCare_Full_Documentation.html`](DaiFootCare_Full_Documentation.html) | **The source.** The PDF is rendered from it; edits belong here. |
| **Word** | [`DaiFootCare_Full_Documentation.docx`](DaiFootCare_Full_Documentation.docx) | Where a reviewer requires `.docx` (track-changes, comments). |

> **The HTML is authoritative.** The PDF is generated from it (§5), so an edit
> made only to the PDF or the Word file is lost at the next render. The Word
> edition is maintained in parallel and must be updated alongside the HTML.

**Current edition:** Version 1.2 · 31 August 2026 · app build 1.2.2 (6)

### Supporting documents

| Document | What it covers |
|---|---|
| [MEASUREMENT_METHOD](MEASUREMENT_METHOD.md) | **The equations.** Calibration label, ring detection, scale, viewing angle, wound dimensions and area, label exclusion, triage rule, unit conversion, measured accuracy |
| [DESIGN_MODIFICATION_LOG](DESIGN_MODIFICATION_LOG.md) | Development rounds, feature changes, model evolution, schema history |
| [ACCURACY_IMPROVEMENT_PLAN](ACCURACY_IMPROVEMENT_PLAN.md) | The accuracy investigation that led to calibration |
| [MODEL1_RETRAINING](MODEL1_RETRAINING.md) | The clinical fine-tune and its acceptance criteria |
| [Models Documentation](DaiFootCare_Models_Documentation.pdf) | Focused AI-models technical reference |
| [System Documentation](DaiFootCare_System_Documentation.html) | App, API and dashboard integration; deployment |

---

## 2. Version history

Each row links to the exact code at that version. `Round` refers to the
development round described in the [design log](DESIGN_MODIFICATION_LOG.md#2-development-rounds--features-added--changed).

| Version | Round | Dates | What changed |
|---|---|---|---|
| **1.0.0+1** | R1 | 2025-10-31 → 11-01 | Initial prototype: Model 1 wound analysis, history, export, reminders |
| **1.1.0+2** | R2–R5 | 2026-07-02 → 07-30 | Three-model on-device pipeline, offline/online modes, sync, clinical suite, iOS-ready |
| *(docs)* | R6 | 2026-07 → 08 | Research documentation and model-metric verification; no app-code change |
| **1.1.0+3** | R7 | 2026-08-05 → 08-06 | Model 3 receives the wound crop; IWGDF/IDSA triage replaces a single threshold; photograph upload; Arabic numerals |
| **1.2.0+4** | R8 | 2026-08-08 → 08-19 | **Calibration label**: measurements in real centimetres; Model 1 v1.2 clinical fine-tune; capture declined beyond 40°; measurement overlay |
| **1.2.1+5** | R9 | 2026-08-19 → 08-20 | Scale and tilt now reach the server; iOS camera format corrected; admin analysis bench |
| **1.2.2+6** | R10 | 2026-08-20 → 08-29 | Clinical wording for tissue types; perfusion caveat on every result; glucose unit selectable with conversion; read-aloud voice selection |

Build numbers are `major.minor.patch+build`. The local database schema advanced
independently from **v1 → v22**; see [design log §4](DESIGN_MODIFICATION_LOG.md#4-data-layer--schema-evolution).

### Following a change

| Question | Where to look |
|---|---|
| What changed in a file, ever | `github.com/Ibraheemshehada/diafootcare_new/commits/main/<path>` |
| What changed between two points | `.../compare/<from>...<to>` — e.g. [`f8640af...main`](https://github.com/Ibraheemshehada/diafootcare_new/compare/f8640af...main) covers the calibration work |
| Why a line is the way it is | `git blame`, or the commit message that introduced it |
| What the report used to say | [History of the PDF](https://github.com/Ibraheemshehada/diafootcare_new/commits/main/docs/DaiFootCare_Full_Documentation.pdf) · [of the Word edition](https://github.com/Ibraheemshehada/diafootcare_new/commits/main/docs/DaiFootCare_Full_Documentation.docx) |

`.docx` and `.pdf` are binary: GitHub stores every version and you can download
any of them, but it will not show a line-by-line diff. For that, read the
Markdown documents, which hold the same substance.

---

## 3. Released builds

The Android application is distributed from the project's own site, not from an
app store.

| | |
|---|---|
| Current build | `https://diafootcare.tech/downloads/diafootcare-latest.apk` |
| Version manifest | `https://diafootcare.tech/downloads/version.json` |
| Previous builds | kept as `diafootcare-prev-<YYYYMMDD-HHMM>.apk` in the same directory |

Each release is published only after the build has been installed and launched,
and the published file's SHA-256 is verified against the tested one.

---

## 4. How the project fits together

**Five repositories, one system.** The mobile app is this repository; the models
were trained in another; the server, API and dashboard are a third.

```
                       ┌──────────────────────────┐
     patient's phone   │   diafootcare_new        │  Flutter app
                       │   (this repository)      │  3 models on device
                       └───────────┬──────────────┘
                                   │  HTTPS: scans, photographs,
                                   │  overlays, calibration
                                   ▼
                       ┌──────────────────────────┐
      clinician's      │   daifootcare-web        │  Laravel API
      browser  ───────►│   Laravel · Vue · Python │  Vue 3 dashboard
                       │                          │  Python inference
                       └───────────┬──────────────┘
                                   │  serves the model bundle
                                   │  and the APK
                                   ▼
                         phones download models
                         on first use (~200 MB)

              ┌──────────────┐        ┌──────────────────┐
              │  DF          │        │  dfuc-annotator  │
              │  training    │        │  tissue labelling│
              │  notebooks   │        │  tool            │
              └──────┬───────┘        └────────┬─────────┘
                     │  exported .tflite       │  labels
                     └────────────┬────────────┘
                                  ▼
                        models shipped via the server
```

| Repository | Role | Stack |
|---|---|---|
| **[diafootcare_new](https://github.com/Ibraheemshehada/diafootcare_new)** — this one | Mobile app, current (Oct 2025 →) | Flutter |
| [daifootcare-web](https://github.com/Ibraheemshehada/daifootcare-web) | Laravel API, Vue 3 dashboard, Python inference (monorepo) | Laravel · Vue · Python |
| [DF](https://github.com/Ibraheemshehada/DF) | Model training and experiments | Jupyter |
| [dfuc-annotator](https://github.com/Ibraheemshehada/dfuc-annotator) | Tissue-label annotation tool | HTML/JS |
| [diafootcare](https://github.com/Ibraheemshehada/diafootcare) · [diafootcarev2](https://github.com/Ibraheemshehada/diafootcarev2) | Earlier prototypes, kept for history | Flutter |

### What lives outside version control, and why

| | Where | Why |
|---|---|---|
| Patient photographs, clinical measurements | `D:\DF\clinical_validation\` | Identifiable clinical data. Never committed. |
| Model binaries (`.tflite`) | Served from the VPS | Too large for the repository's LFS budget; the app downloads them on first use |
| Training datasets | `D:\DF\` | Licensed third-party corpora (FUSeg, DFUC, Medetec, DFUTissue) |
| Server addresses and credentials | The server, and nowhere else | Never in a committed file |

---

## 5. Regenerating the report

The PDF is rendered from the HTML; page furniture is stamped afterwards.

```bash
cd docs
CHROME="/c/Program Files/Google/Chrome/Application/chrome.exe"
ABS=$(python -c "import pathlib;print(pathlib.Path('DaiFootCare_Full_Documentation.html').resolve().as_uri())")
"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$(pwd -W)/_raw.pdf" "$ABS"
python stamp_pdf.py _raw.pdf DaiFootCare_Full_Documentation.pdf \
  "DaiFootCare · Full Research Documentation" \
  "Model Development, Training and Evaluation · v1.2" \
  "DaiFootCare — Full Research Documentation" \
  "On-Device Deep Learning for Diabetic-Foot-Ulcer Assessment (v1.2)"
rm _raw.pdf
```

Requires Google Chrome and `pymupdf`. Arguments 5 and 6 set the PDF's own title
and subject; without them the metadata defaults to the Models Documentation's,
which is how one edition was once published under another's name.

When the version changes, four places carry it: the HTML title block, the Word
title block, and the two version arguments above. Figure and table numbers are
continuous across the document — check the highest existing number before adding
one.
