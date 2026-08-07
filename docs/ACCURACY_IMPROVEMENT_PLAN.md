# DiaFootCare — Clinical Accuracy Improvement Plan

**Status: PLANNING + Phase A under way.** This is a living working document for the
discussion → decision → execution cycle. Planning happens here first; implementation
follows only the decisions recorded in §7.
**What has actually been built, and whether it works, lives in
[IMPLEMENTATION_TRACKER.md](IMPLEMENTATION_TRACKER.md).**

- **Opened:** 2026-08-05
- **Trigger:** first real-patient field test produced clinically wrong output
- **Owner:** Ibraheem
- **Rule:** nothing gets implemented until its row in §7 says `DECIDED`.

---

## 1. Field evidence (what actually went wrong)

| Observation | Ground truth | App output | Error |
|---|---|---|---|
| Wound length, real patient | **1.4 cm** | **0.9 cm** | −36% (×0.64) |
| Infection status, healthy patient | no infection | **"Infection Detected"** | false positive |
| Tissue classification | — | unreliable / over-firing | see §4 |

This is a **systematic** failure, not noise. §2–§4 identify the causes; each was verified
against the source, not assumed.

---

## 2. ROOT CAUSE #1 — Measurement scale is a hard-coded guess ⚠️ *the smoking gun*

### What the code does
[`ai_service.dart:66`](../lib/features/wound/analysis/services/ai_service.dart#L66)
```dart
static const double _assumedFrameCm = 12.0;
```
[`ai_service.dart:341`](../lib/features/wound/analysis/services/ai_service.dart#L341)
```dart
final ppc = pixelsPerCm ?? (max(origW, origH) / _assumedFrameCm);
```

`pixelsPerCm` is **always `null`** in production: the reference-object calibration screen
was removed from the flow in Round 5, and
[`preview_screen.dart:129`](../lib/features/wound/capture/screens/preview_screen.dart#L129)
constructs `AnalysisLoadingScreen(imagePath: imagePath)` with no scale argument.
`ScaleCalibrationScreen` still exists but **nothing calls it** — it is dead code.

### Therefore the reported size reduces to
```
length_cm  =  (wound_pixels_along_axis / long_edge_pixels) × 12
           =  fraction_of_frame × 12 cm
```
**The app assumes every photograph's long edge spans exactly 12 cm — regardless of how
far the phone was held.** Camera distance is never measured, so it cannot be corrected for.

### This explains the field error exactly
The true frame span was `12 × (1.4 / 0.9) = 18.7 cm` — the patient was photographed
~56% farther away than the built-in assumption. The reported value was not "a bit off";
it was *the right pixel measurement multiplied by the wrong constant*.

> **Model 1 is probably innocent.** Segmentation Dice is 0.873 and the pixel geometry
> (PCA/minAreaRect) is sound. The defect is the pixel→cm constant.

### Severity: area is worse than length
Length/width scale **linearly** with the distance error; **area scales quadratically**:
`0.64² = 0.41` → the area was under-reported by ~59%. Since the healing trend is driven by
area, a patient who photographs from a varying distance gets a **fabricated healing curve**.

### The physics we must implement
```
frame_long_cm = 2 × D × tan(FOV_long / 2)      D = camera-to-wound distance
length_cm     = fraction_of_frame × frame_long_cm
```
The current code is correct **only** when `2·D·tan(FOV/2) = 12 cm`. Both `D` and `FOV`
must become *measured* quantities.

---

## 3. ROOT CAUSE #2 — Models 2 & 3 never see the wound

[`ai_service.dart:596-608`](../lib/features/wound/analysis/services/ai_service.dart#L596)
```dart
/// CLIP preprocessing: resize shorter side to 224, center-crop 224 ...
final scale = 224 / min(src.width, src.height);
final x0 = ((rz.width - 224) / 2).round();     // ← CENTRE of the whole photo
```

Both the tissue head and the infection head consume a **centre crop of the entire
photograph**. Model 1 computes a precise wound mask and bounding box — and it is
**never used to crop the input for Models 2/3**.

Consequences:
- If the wound is off-centre, it may be **partially or entirely outside** the 224 crop.
- Most of the 512-d CLIP embedding describes skin, floor, socks, lighting — not wound tissue.
- The classifiers are effectively reasoning about *the photo*, not *the wound*.

### 🚨 The decisive detail: Model 3 was trained on wound CROPS, not whole photos

Verified by measuring the actual training images on disk:

| Model | Training corpus | Image size | What it really is |
|---|---|---|---|
| **3** (infection) | DFUC2021 (5,955) | **224 × 224** | 🔴 **tight wound patches** |
| **3** (infection) | Part B / DFUNet (1,447) | **256 × 256** | 🔴 **tight wound patches** |
| 2 (tissue) | Source-A (366) | 672×1396, 1141×2431 … | whole photographs |
| 2 (tissue) | DFUC2020 (810) | 640 × 480 | whole photographs |

**Model 3 has never seen a whole foot in its life.** It was trained exclusively on close-up
patches where the wound fills the frame. In production the app hands it a centre crop of a
whole-foot photograph — perhaps 5% wound, 95% skin, floor and background.

> **We are asking it a question about an image unlike anything it was trained on.**
> The reported AUC 0.890 is *honest for wound patches* — it simply does not describe the
> input the app currently supplies. This is a **train/serve mismatch**, and it is the most
> probable cause of the false "Infection Detected" on a healthy patient.

**Consequence for the plan — this is good news:**

| Model | Fix | Retraining? |
|---|---|---|
| **3** (infection) | **Crop to the wound before CLIP** — restores the training distribution | ❌ **None. App-side code only.** |
| **2** (tissue) | Trained on whole images, so cropping *would* create a mismatch → must retrain the head on crops | ✅ Small head only (automated, minutes) |

Model 3's fix therefore moves from Phase B to **Phase A, at zero training cost**.

---

## 4. ROOT CAUSE #3 — Operating points and class priors are mis-set

### Infection false positive
| Factor | Value | Effect |
|---|---|---|
| Deployed threshold | **0.41** (tuned for best **F1**) | favours recall over precision |
| Specificity at that point | **0.728** | **27% of healthy wounds are flagged** |
| Training prevalence | 4,004 / 7,402 = **54% positive** | real clinics are far lower |
| Domain | DFUC2021 clinical close-ups | vs. home phone photo |

**Base-rate mismatch:** a model trained at 54% prevalence, deployed into a population where
true infection prevalence may be 10–20%, suffers a collapse in positive predictive value.
Combined with spec 0.728, a false "Infection Detected" on a healthy patient is *expected
behaviour*, not a bug in the weights.

The UI also states the result as a **binary claim** ("Infection Detected", `Present`) at
[`ai_service.dart:580-592`](../lib/features/wound/analysis/services/ai_service.dart#L580) —
false certainty on a 0.73-specificity signal.

### Tissue classification
Per-class, at the deployed thresholds (our validated re-computation):

| Class | AUC | Sens | Spec | Verdict |
|---|---|---|---|---|
| epithelial | **0.654** | 0.409 | 0.789 | near-chance — **not clinically usable** |
| granulation | 0.878 | 0.784 | 0.805 | acceptable |
| necrosis | 0.910 | 0.712 | 0.927 | good |
| callus | 0.741 | 0.950 | **0.318** | **fires on 68% of non-callus wounds** |
| slough | 0.924 | 0.705 | 0.930 | good |

- **Callus** was positive in 281/366 = **77%** of training images → the model learned
  "callus is almost always present". Its 0.318 specificity is a prior artifact.
- **Epithelial** at AUC 0.654 is barely above chance.
- CLIP is a *generic semantic* encoder. Tissue discrimination is a **local colour/texture**
  problem; a global semantic embedding is the wrong inductive bias.
- Labels are **image-level present/absent** — the model cannot say *how much* of the wound
  bed is granulation vs. slough, which is what clinicians actually grade.

---

## 5. Workstreams and options

### W1 — Metric scale ✅ **DECIDED: printed reference sticker + live capture gating**

#### The decision
A **printed circular sticker of known physical size**, placed on intact skin beside the
wound, is the scale reference. The live camera preview detects it and drives a **green-light
capture gate**. **AR (ARCore / ARKit) is rejected for this phase.**

#### Why AR was rejected

| | AR depth | **Reference sticker** |
|---|---|---|
| Device coverage | ARKit basic = iPhone 6s+, but **precise LiDAR = "Pro" models only (12 Pro+)**; ARCore needs per-model certification and **excludes many budget Androids** | ✅ **100% — any device with a camera** |
| Accuracy on a **curved** foot | 🔴 weak without LiDAR: plane-fitting assumes a flat surface, and a foot is not one | ✅ ±2–5%, measured *at the wound* |
| Green-light UX | ✅ | ✅ **identical** |
| Tilt detection | ✅ | ✅ **free, from the ellipse** |
| Dev cost | 🔴 two native platform integrations | 🟢 one image-processing path |

The study population (often elderly, mixed budget handsets) is exactly the group AR coverage
fails. A sticker is also the established convention in clinical wound photography.

#### The physics — and why **no camera intrinsics are needed**
The sticker's true diameter `S_cm` is known. If it measures `S_px` in the image:

```
pixelsPerCm = S_px / S_cm
length_cm   = wound_axis_px / pixelsPerCm
```

This is a **pure ratio**. No focal length, no FOV, no EXIF, no distance estimate, no platform
channel — and it stays correct at *any* distance. It removes `_assumedFrameCm` entirely.

#### 🎁 Tilt comes free from the same sticker
A circle photographed off-axis projects to an ellipse:

```
cos(tilt) = minor_axis / major_axis
```

So one circular sticker yields **scale + distance + tilt** from a single detection. Use the
**major** axis for `pixelsPerCm` (it is the un-foreshortened diameter).

#### 🏭 Industry benchmark — this approach is the commercial standard
Reviewed how shipping wound-care products solve the same problem:

| Product | Method | What we take from it |
|---|---|---|
| **Swift Skin and Wound** (market leader) | FDA-cleared **"HealX calibrant"** sticker beside the wound, calibrating **scale *and colour***; its segmentation network is trained to detect the sticker itself | ✅ Confirms the decision · 🌈 **Colour calibration — adopt (see W6)** |
| **imitoMeasure** | **QR marker** placed level with the wound; **the app refuses to capture until the code is recognised** | ✅ Settles **D2 — hard block** |
| Digital planimetry (reference standard) | Two rulers on opposite sides of the wound | Two markers reveal non-coplanarity — kept as an optional cross-check |
| **Planimator** | Phone tilt sensors correct camera angle, no marker | ⚠️ See limitation below |

> **Why the sensor-only route is weaker than ours.** An accelerometer measures the phone's
> tilt **relative to gravity — not relative to the wound surface**, and a foot is rarely
> horizontal. A phone held perfectly level above a foot tilted 25° still yields a 25° oblique
> shot (~10% error) that the sensor cannot see. Our circular marker measures tilt **relative to
> the plane it is stuck to — the wound plane** — which is the quantity that actually matters.
> Separately, **sensors alone can never recover absolute scale**: gravity gives orientation,
> not distance.

#### Sticker specification (→ decision D3)
**One printed label performing three jobs**, with independent cross-checks:

```
┌──────────────────────────────────┐
│   ◎◎◎◎        ⬜ ⬛ 🟥 🟨        │
│   ring        colour patches     │
│   Ø20 mm      white/grey/red/yellow │
│   ├─── 20.0 mm ───┤   v1 · 100%  │
└──────────────────────────────────┘
```

| Feature | Spec | Job |
|---|---|---|
| **Annulus (ring)** | outer **Ø 20.00 mm**, inner Ø 12.00 mm, saturated cyan on white | **Primary scale + tilt.** A ring beats a solid disc: two edges instead of one (double the fitting constraints) and specular glare in the centre cannot destroy it |
| **Colour patches** | white · mid-grey · red · yellow, 6 mm squares | **White balance + colour correction** → feeds W6 |
| **Scale bar** | printed line of exactly 20.0 mm, labelled | Lets anyone verify print scale with a ruler |
| **Optional QR** | encodes size + batch id | Metadata only — *not* required for measurement |

**Why the ring is the measurement primitive, not a QR:** a QR needs ≈21 modules × ~3 px each
≈ 63 px to decode, i.e. ~2.5–3 cm of physical label at a 30–40 cm working distance. An ellipse
fit is stable from ~40 px. Making measurement depend on QR decoding would force a much larger
label onto a small, curved foot. The ring measures; the QR, if present, only labels.

**Detection:** HSV threshold on the cyan hue → contour → `fitEllipse`, on a downscaled preview
frame. Cyan is chosen because it **does not occur in skin or wound tissue** (red/brown/yellow).

**Sizes:** standard **Ø20 mm**; a **Ø15 mm** variant in a second hue for toes and tight,
strongly curved sites. The app infers which is which from the hue.

**Supply:** A4 adhesive sheets (~24 labels), single-use, issued with the instruction card.

> ⚠️ **The one critical print rule:** print at **100% / "Actual size"** — never "Fit to page".
> A 5% print-scale error propagates 1:1 into every measurement. Each sheet carries a 100 mm
> verification bar to be checked with a ruler before the sheet is used.

#### Cross-validation layers (redundancy that actually helps)
Combining methods only helps when their **failure modes are independent**:

| Layer | Measures | Fails when | Caught by |
|---|---|---|---|
| 1. Ring ellipse | scale + tilt vs. wound plane | marker not coplanar with wound | layer 3 / accelerometer |
| 2. Inner/outer edge agreement | scale, independently | glare, partial occlusion | disagreement > 5% → reject frame |
| 3. Accelerometer | gross device orientation | foot not horizontal | layer 1 |
| 4. *(optional)* second marker | surface curvature | — | size ratio ≠ 1 → warn |

**Rule: if two independent estimates disagree by more than 5%, reject the frame and ask for a
retake.** Agreement between independent measurements is stronger evidence than any single one.

#### 🩺 Placement rules (clinical safety — mandatory)
- **Never on the wound bed.** Only on **intact skin**, adjacent to the wound.
- **Single-use**, clean, discarded after the photograph.
- **As close to the wound as possible and at a similar surface height** — the sticker defines
  the reference plane. A sticker on the floor while the wound is on the instep introduces a
  depth difference and therefore a scale error.

#### W1a — The green-light capture gate
Evaluate on each preview frame; the shutter stays disabled until **all** conditions pass:

| # | Condition | Source | Failure message |
|---|---|---|---|
| 1 | Sticker visible | detector | «ضع الملصق بجانب الجرح» |
| 2 | `S_px` within target band → correct distance | sticker size | «اقترب» / «ابتعد» |
| 3 | `minor/major ≥ 0.95` → tilt ≲ 18° | ellipse ratio | «امسك الكاميرا بشكل مستقيم» |
| 4 | Low gyro motion | `sensors_plus` | «ثبّت يدك» |
| 5 | Sharp (Laplacian variance) & adequate light | frame stats | «الصورة غير واضحة» |

All green → green ring + auto-capture (or enable the shutter — see D2).

#### Integration — the plumbing already exists
`AiService.analyzeWound(..., double? pixelsPerCm)` and `AnalysisLoadingScreen.pixelsPerCm`
are **already implemented**; they are simply never supplied. The work is to compute
`pixelsPerCm` from the detected sticker and pass it through
[`preview_screen.dart:129`](../lib/features/wound/capture/screens/preview_screen.dart#L129).
`ScaleCalibrationScreen` can be revived as the manual fallback when auto-detection fails.

### W2a — Crop the input for Model 3 (fixes §3, **no retraining**)
Use Model 1's mask bounding box (+ ~15% padding) as the CLIP input for the **infection**
head, restoring the 224×224-patch distribution it was trained on. Pure app-side change.

### W2b — Retrain Model 2's head on wound crops (fixes §3 for tissue)
Model 2 *was* trained on whole photographs, so it must be retrained to accept crops:
1. Run Model 1 over the Source-A + DFUC2020 corpora → masks (DFUC2020 already ships boxes)
2. Crop to bbox + 15% padding — **identical geometry to the app's runtime crop**
3. Re-extract CLIP embeddings on the crops *(GPU, ~20–30 min)*
4. Retrain the per-class SVMs *(~4 min — measured)* and re-tune thresholds
5. Export new `tissue_head.tflite`

Data already exists in `D:\DF`; **no new labelling required**. Mask QC is optional for the
first pass — cross-validated metrics against the current baseline reveal bad crops.

### W3 — Re-tune operating points and priors (fixes §4, no retraining)
- Move infection off the F1-optimal point to a **specificity target** (e.g. spec ≥ 0.90),
  accepting lower sensitivity — appropriate when a false alarm sends a healthy patient to a clinic.
- Apply **prior/prevalence correction** to convert training-prevalence probabilities into
  deployment-prevalence probabilities.
- Fix the **callus prior** (spec 0.318).
- Ships as JSON metadata changes (`*_meta.json`) — **no model retraining**.

### W4 — Honest output language (safety, cheap)
Replace binary claims with graded, uncertainty-aware wording; show the probability and the
threshold; suppress or flag classes below a usability bar (**epithelial, AUC 0.654**).

### W6 — 🌈 Colour calibration (new — may fix much of §4's tissue problem for free)
Adopted from Swift's calibrant. **Tissue classification is fundamentally a colour judgement:**
granulation = red, slough = yellow, necrosis = black, epithelial = pink. Yet the same wound
photographed on a different handset, or under tungsten vs. daylight vs. fluorescent light,
produces materially different RGB values — so the classifier is fed a moving target.

The label's white/grey patches provide a **known reference**: measure how the white patch has
been rendered, derive the illuminant, and white-balance the whole frame before it reaches CLIP.

- **Cost:** low — sample the patch means, apply a per-channel gain (or a 3×3 correction matrix).
- **No retraining required** to try it.
- **Why it may matter more than expected:** part of Model 2's weakness (callus spec 0.318,
  epithelial AUC 0.654) may be device/illuminant colour variance rather than model capacity.
  Worth measuring **before** committing to W2b's retrain.
- **Bonus:** normalising colour also makes the *training* corpus more consistent if the same
  correction is applied there.

> Verification: run the current tissue head on the validation set with and without colour
> correction. If metrics improve, the gain was free.

### W5 — Real-patient validation set 🔴 *blocking for verification*
Without ground truth we cannot prove any fix works. Minimum viable set: **20–30 wounds**,
each photographed **with a ruler/sticker in frame** at 2–3 distances, plus a clinician's
measurement and infection/tissue assessment. This becomes the regression suite for every
change below.

---

## 6. Recommended sequencing

| Phase | Contents | Retraining? | Manual work? | Why |
|---|---|---|---|---|
| **A** | W1 sticker + gate · **W2a Model-3 crop** · W3 thresholds · W4 wording | ❌ **None** | ❌ code only | Fixes the scale error and the infection mismatch — the two field failures — at zero training cost |
| **B** | W2b retrain Model 2's head on crops → re-tune its thresholds | ✅ small head only | ❌ scripted | Real gain for tissue |
| **C** | Per-pixel tissue labels, colour/texture features, encoder replacement | ✅ Yes | ✅ **annotation** | Longer-horizon quality — deferred |

**No neural network is retrained in Phase A or B.** Only Model 2's small SVM head is refitted
(minutes). Model 1's segmentation network and the CLIP backbone are untouched throughout.

---

## 6b. ✅ Prerequisites — what is needed before implementation starts

### 🔴 Blocking (work cannot be *verified* without these)
| # | Item | Who | Detail |
|---|---|---|---|
| P1 | **Validation set** | 🧑‍⚕️ clinical | **20–30 real wounds.** Each photographed with **both the sticker and a ruler in frame**, from **2–3 different distances**, plus the clinician's tape measurement and their infection / tissue assessment. This is the regression suite for *every* change. |
| P2 | **Sticker specification signed off** | decision D3 | Diameter, colour, shape — must be fixed *before* the detector is written, since the detector is tuned to it |
| P3 | **Stickers physically printed** | logistics | Sheets + a patient instruction card |

### 🟡 Needed soon, not blocking
| # | Item | Detail |
|---|---|---|
| P4 | Answers to D2, D4, D5, D6 | Gate strictness, infection operating point, tissue retrain, epithelial handling |
| P5 | Test handsets | 2–3 real devices spanning the study's range, for preview-detector tuning |
| P6 | Ethics / protocol check | Confirm that placing an adhesive marker on skin adjacent to a wound is covered by the study protocol |

### 🟢 Can start immediately (no prerequisite)
- **W2a** — cropping the Model 3 input. Self-contained, no training, no sticker dependency.
- **W3** — threshold re-tuning from the cached embeddings already on disk.
- **W4** — output wording.
- The sticker **detector** can be prototyped as soon as P2 is agreed.

> **Sequencing rule:** coding may begin before P1 exists — but **no accuracy improvement may
> be claimed, documented, or shipped until it is measured against the validation set.**

---

## 7. Decision log (append-only)

| # | Question | Decision | Date |
|---|---|---|---|
| **D1** | Scale strategy | ✅ **DECIDED — printed reference sticker + live green-light capture gate. AR (ARCore/ARKit) rejected**: LiDAR is Pro-only, ARCore excludes budget Androids, and plane-fitting is weak on a curved foot. The sticker works on 100% of devices, needs no camera intrinsics, and yields tilt for free. | 2026-08-05 |
| **D2** | Gate: block the shutter or warn only? | ✅ **DECIDED — hard block.** No capture without a valid marker reading, following imitoMeasure. Guarantees every stored photograph carries calibration data | 2026-08-05 |
| **D3** | Sticker specification | ✅ **DECIDED — one label, three functions:** cyan **annulus Ø20.00 mm** (outer) / Ø12 mm (inner) as the measurement primitive · **white/grey/red/yellow colour patches** for W6 · printed **20 mm scale bar** for print verification · optional QR for batch metadata. Ø15 mm second-hue variant for toes. Ring chosen over QR-as-primary because an ellipse fits from ~40 px whereas a QR needs ~63 px | 2026-08-05 |
| **D8** | Adopt colour calibration (W6)? | ✅ **DECIDED — yes, and evaluate it *before* W2b.** May recover tissue accuracy with no retraining | 2026-08-05 |
| **D4** | Infection operating point | ✅ **ANSWERED — the question is rejected.** No single threshold works: every point on one ROC curve trades sensitivity for specificity. Replaced by **three zones (0.30 / 0.80) + the IWGDF/IDSA patient checklist**, which adds an independent information channel instead of sliding along the curve. At 20% prevalence: alarm PPV **0.45 → 0.75** AND missed infections **2.9% → 1.8%** — better on both axes. Implemented and tested in `infection_triage.dart` (18/18); see [IMPLEMENTATION_TRACKER.md](IMPLEMENTATION_TRACKER.md) §C4 | 2026-08-05 |
| **D5** | Retrain on wound crops | ✅ **Model 3 — no retraining needed** (crop at inference restores its training distribution). 🟡 **Model 2 — retraining its small head required**; confirm go-ahead | 2026-08-05 |
| **D6** | Drop `epithelial` from the UI? | ⬜ *pending* — AUC 0.654 is near-chance | |
| **D7** | Who collects the validation set, and when? | ⬜ *pending* — **blocking (P1)** | |

## 8. Open questions for the discussion
1. **Distance band** — what working distance is realistic for a patient photographing their
   own foot? (This sets the target band and whether macro focus is viable.)
2. **Reference object** — is asking the patient to place a coin/sticker acceptable in the
   study protocol, or must capture stay fully hands-off?
3. **Device fleet** — which phones will the study actually use? (Determines whether ARCore/
   ARKit depth is available at all.)
4. **Clinical tolerance** — what measurement error is acceptable? ±5%? ±10%?
5. **Sensitivity vs. specificity** — for this study, is a missed infection or a false alarm
   the worse outcome?

---

## 9. Discussion notes
*(append dated notes from each planning conversation)*

**2026-08-05 — Session 1.** Field test showed 1.4 cm measured as 0.9 cm, plus a false
infection positive on a healthy patient and unreliable tissue output. Investigation traced
the measurement error to the hard-coded `_assumedFrameCm = 12.0` constant with calibration
removed from the flow (§2, verified in source). Also found Models 2/3 run on a centre crop of
the whole photo rather than the wound (§3), and that the infection threshold is F1-optimal at
specificity 0.728 against a 54%-prevalence training set (§4). Proposed distance-gated capture
as the scale fix. No code changed. Awaiting decisions D1–D7.

**2026-08-05 — Session 2. Two outcomes.**

*(a) A correction that improves the plan.* Session 1 assumed Models 2 and 3 were both trained
on whole photographs, and therefore that cropping required retraining. Measuring the training
images on disk disproved this for Model 3: DFUC2021 is **224×224** and Part B is **256×256** —
**tight wound patches**. Model 3 has never seen a whole foot. Its field false-positive is a
**train/serve mismatch**, and the fix is an app-side crop with **no retraining** (§3). Model 2
*is* whole-image trained, so only its small head needs refitting.

*(b) D1 decided — reference sticker, AR rejected.* Reviewed device coverage: ARKit needs
iPhone 6s+ but precise **LiDAR is Pro-only**, ARCore requires per-model certification and
excludes many budget Androids — precisely the handsets this study population carries. AR also
degrades on a **curved** foot because it fits planes. The decisive realisation: **the green-light
UX does not require AR at all.** A sticker of known size gives distance directly from its
apparent pixel size, and a *circular* sticker additionally yields tilt from its ellipse ratio
(`cos θ = minor/major`) — scale, distance and tilt from one detection, on every device, with
**no camera intrinsics**. Also noted: `pixelsPerCm` is already plumbed through `AiService` and
`AnalysisLoadingScreen`; it is simply never supplied.

*Documentation follow-up:* the research documentation reports Model 3 AUC 0.890 without stating
that it was measured on **wound patches**. That qualification must be added — the figure does
not describe the app's current whole-photo input.

Next: answers to D2, D3 (sticker spec), D4, D6, D7 → then Phase A implementation.

**2026-08-05 — Session 3. Benchmarked against shipping products; three decisions closed.**

Reviewed how commercial wound-care apps solve the same problem. **The decision is validated:
Swift Skin and Wound — the market leader — uses exactly this approach** (an FDA-cleared printed
calibrant beside the wound). We are not inventing an unusual solution.

Three things adopted from that review:
1. **🌈 Colour calibration (new W6).** Swift's calibrant corrects *colour as well as scale*.
   Tissue classification is a colour judgement, and handset/illuminant variance may explain a
   real share of Model 2's weakness. Adding white/grey patches to the same label may recover
   accuracy **with no retraining** — so it is to be evaluated *before* committing to W2b.
2. **D2 settled — hard block.** imitoMeasure refuses to capture until its marker is recognised;
   this guarantees no uncalibrated photograph ever enters the record.
3. **D3 settled.** A ring (annulus) is the measurement primitive rather than a QR: an ellipse
   fits reliably from ~40 px whereas a QR needs ~63 px to decode, which would force a much
   larger label onto a small curved foot. The QR is demoted to optional metadata.

**Sensor-only approaches (Planimator) were considered and rejected** for a physical reason: an
accelerometer measures tilt against **gravity**, not against the **wound plane**, and a foot is
rarely horizontal — a level phone over a foot tilted 25° still produces a ~10% error the sensor
cannot detect. A marker stuck to the wound plane measures the angle that actually matters. And
sensors alone can never supply absolute scale.

**Cross-validation principle recorded:** redundancy only helps when failure modes are
independent, so the layers were chosen to cover each other (ring ↔ accelerometer ↔ inner/outer
edge agreement), with a **>5% disagreement ⇒ reject the frame** rule.

Next: label artwork produced for printing → then Phase A implementation. Still open: D4, D6, D7.
