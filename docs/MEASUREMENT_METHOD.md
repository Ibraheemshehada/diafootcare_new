# How DiaFootCare turns a photograph into centimetres

**Repository:** `github.com/Ibraheemshehada/diafootcare_new`
**Last updated:** 2026-08-29 · app `1.2.2+6`

Every formula here is taken from the shipped code, not from a design note. The
file and line are given so each one can be checked against what actually runs:

| Step | Source |
|---|---|
| Ring detection and scale | `lib/features/wound/analysis/services/ring_detector.dart` |
| Wound extents and area | `lib/features/wound/analysis/services/ai_service.dart` |
| Infection triage | `lib/features/wound/analysis/services/infection_triage.dart` |
| Glucose units | `lib/features/glucose/glucose_unit.dart` |
| Server-side equivalents | `daifootcare-web/inference/ring.py`, `pipeline.py` |

---

## 1. Rationale

A photograph has no scale. The same ulcer is 400 pixels across from 20 cm away
and 200 pixels from 40 cm, and nothing in the image says which. Before
calibration the app assumed the wider side of the frame spanned a fixed
`_assumedFrameCm = 12.0`:

$$\text{px/cm} = \frac{\max(W_{px}, H_{px})}{12.0}$$

This remains the fallback when no reference is visible. Reported dimensions
then scale with the ratio of true to assumed camera distance; in one recorded
case a 1.4 cm wound was reported as 0.9 cm. Measurements obtained this way are
flagged as **not calibrated** in the interface and in the stored record.

A metric reference of known size within the field of view removes the
assumption.

---

## 2. The calibration label

![The DiaFootCare v5 calibration label, photographed in clinic](figures/fig_calibration_label.png)

*The label as printed and used, photographed beside a patient's wound. The cyan
annulus is the reference: outer diameter **2.0 cm**. The compact variant uses a
**1.5 cm magenta** annulus. Printed at 100% scale — the note on the card exists
because a printer set to "fit to page" silently rescales it and every
measurement taken with it is wrong by that factor.*

### 2.1 Design rationale

**Annulus.** The presence of a central aperture is the decisive discriminator in
detection (§2.4). Solid circular regions occurring in clinical photographs —
caps, coins, folded drapes, specular highlights — are excluded by this test
alone. A filled disc offers no equivalent signature.

**Circular geometry.** Under perspective projection a circle maps to an ellipse
whose major axis is unforeshortened, so a single detected contour yields both
the scale and the viewing angle (§3). Fiducial markers such as ArUco and QR were
evaluated and not adopted: they require decode-quality print and lighting, and
degrade discontinuously — they either resolve or return nothing.

**Two diameters.** The 2.0 cm cyan annulus is standard. A 1.5 cm magenta variant
is provided for small wounds and confined anatomical sites where the standard
mark cannot be positioned without contacting the wound bed. **Hue determines the
assumed physical diameter**, so the two hue bands are widely separated
(cyan 80–115, magenta 145–175) rather than adjacent, ensuring unambiguous
classification.

**Printed ruler.** Provided for clinician verification and for manual
measurement from the photograph. It is not used by the software.

**Colour patches** (white, grey, red, yellow). Reserved for white-balance and
colour normalisation. Not used by the current pipeline.

**Diameter selection.** 2.0 cm places the ring at 150–250 px in a 1200 px
photograph at typical handheld distance, so a one-pixel extent error contributes
approximately 0.5% to the scale, while remaining small enough to position beside
a digital ulcer.

**Print scale.** The card is printed at 100%. Rescaling by the print driver
invalidates the reference and is annotated on the card itself.

### 2.2 Detection

Work is done on the frame downscaled to 640 px wide, then scaled back. Pixels
are selected in HSV:

| Ring | Hue | Saturation | Value |
|---|---|---|---|
| Cyan (2.0 cm) | 80–115 | ≥ 60 | ≥ 40 |
| Magenta (1.5 cm) | 145–175 | ≥ 110 | ≥ 50 |

Hue is on OpenCV's 0–179 scale, saturation and value on 0–255. The mask is
opened (erode 3, dilate 3) then closed (dilate 2, erode 2), and
connected components are extracted. Each component is then put through four
acceptance tests.

### 2.3 Orientation and extents

For a component with $n$ pixels and centroid $(\bar{x}, \bar{y})$, the second
central moments are

$$\sigma_{xx} = \tfrac{1}{n}\sum (x_i-\bar{x})^2, \qquad
\sigma_{yy} = \tfrac{1}{n}\sum (y_i-\bar{y})^2, \qquad
\sigma_{xy} = \tfrac{1}{n}\sum (x_i-\bar{x})(y_i-\bar{y})$$

The principal axis is at

$$\theta = \tfrac{1}{2}\arctan\!\left(\frac{2\sigma_{xy}}{\sigma_{xx}-\sigma_{yy}}\right)$$

Every pixel is projected onto that axis and its perpendicular,

$$u_i = \Delta x_i\cos\theta + \Delta y_i\sin\theta, \qquad
v_i = -\Delta x_i\sin\theta + \Delta y_i\cos\theta$$

and the extents are the ranges, ordered so the major axis is the longer:

$$a = \max u - \min u, \qquad b = \max v - \min v$$
$$\text{major} = \max(a,b), \qquad \text{minor} = \min(a,b)$$

This is the projection extent along the principal axes — the same quantity
OpenCV's `minAreaRect` reports, computed directly.

### 2.4 Acceptance tests

**Roundness.** A circle projects to an ellipse under perspective, never to a
sliver:

$$r = \frac{\text{minor}}{\text{major}} \ge 0.5$$

**Frame share.** A ring photographed to be measured occupies a sane part of the
frame:

$$0.02 < \frac{\text{major}}{\max(W,H)} < 0.45$$

**Central aperture.** The primary discriminator. A disc of radius
$\max(2, 0.15\,\text{minor})$ centred on the centroid is sampled, and the
component is rejected if more than **23.5%** of that disc is ink. Solid regions
— drapes, caps, shadows — fail this test; an annulus passes it.

**Fill ratio.** An annulus covers part of its own ellipse; a disc covers all of
it:

$$0.12 < \frac{n}{\pi \cdot \frac{\text{major}}{2} \cdot \frac{\text{minor}}{2}} < 0.95$$

### 2.5 Ranking

$$\text{score} = r \cdot \min\!\left(1, \frac{n}{600}\right)$$

Ranking is by circularity rather than area: the calibration mark is the most
circular aperture-bearing region in the frame, and area-first ranking would
favour larger regions passing the filters incidentally. The area term suppresses
small spurious components only.

---

## 3. Scale and viewing angle

$$\boxed{\ \text{px/cm} = \frac{\text{major}_{px}}{d_{cm}}\ }
\qquad d_{cm} = 2.0 \ \text{(cyan)} \ \text{or}\ 1.5 \ \text{(magenta)}$$

This is a **pure ratio**. It needs no focal length, no sensor size, no camera
intrinsics and no calibration of the phone — which is what makes it work across
every device in a study without per-device setup.

The major axis is used for the scale. Under perspective a circle of diameter $d$
tilted by $\phi$ projects to an ellipse whose **minor** axis is foreshortened by
$\cos\phi$ while its **major** axis is not:

$$\text{major} = s\,d, \qquad \text{minor} = s\,d\cos\phi$$

So the scale survives tilt, and the tilt itself falls out of the same two
numbers:

$$\boxed{\ \phi = \arccos\!\left(\frac{\text{minor}}{\text{major}}\right)\ }$$

reported in degrees. Nothing extra is measured to obtain it.

### 3.1 Effect of inclination on measurement error

Measured across the clinical acquisition batches:

| Tilt band | Mean measurement error | n |
|---|---|---|
| ≤ 30° | **18.1%** | — |
| 30–40° | **39.6%** | — |
| > 40° | **55.8%** | — |

Correlation between tilt and error: **r = +0.479**.

These bands define the acquisition guard: the camera displays $\phi$ in real
time, warns between 30° and 40°, and **declines capture beyond 40°**. The live
preview and the post-capture check apply identical thresholds.

---

## 4. Wound measurement

### 4.1 Segmentation

Model 1 (U-Net, MobileNetV2 encoder with scSE attention, 384×384) produces a
probability map. Post-processing, in order:

1. **2-view TTA** — the horizontal flip is predicted too and the two maps
   averaged.
2. **Threshold** at 0.5. If nothing survives, fall back to $0.5 \times \max p$,
   so a faint but real wound is not lost.
3. **Morphology** — 5×5 open, then 5×5 close.
4. **Printed-label removal** — see §5.
5. **Largest connected component only.** One wound per photograph.

### 4.2 From mask pixels to centimetres

The mask is computed at model resolution and measured in original-image pixels,
with anisotropic scaling so a non-square photograph measures correctly:

$$s_x = \frac{W_{orig}}{w_{mask}}, \qquad s_y = \frac{H_{orig}}{h_{mask}}$$

Length and width use the **same PCA extent** as §2.3, applied to the wound mask:

$$\boxed{\ L = \frac{\text{major}_{px}}{\text{px/cm}}, \qquad
W = \frac{\text{minor}_{px}}{\text{px/cm}}\ }$$

This replaced an axis-aligned bounding box, which over-measures any wound lying
diagonally in the frame.

Area is the **true segmented pixel count**, not $L \times W$ and not an ellipse
estimate:

$$\boxed{\ A_{cm^2} = \frac{n_{mask}\; s_x s_y}{(\text{px/cm})^2}\ }$$

Area is the most sensitive of the three to healing, responding to change in all
directions rather than along a single axis.

### 4.3 Healing progress

$$\text{progress} = \operatorname{clamp}_{0}^{100}\!\left(
\frac{A_{baseline} - A_{now}}{A_{baseline}} \times 100 \right)$$

### 4.4 Measurement overlay

Each analysis renders an image showing the region that was measured: the
segmentation mask, and the detected reference annulus with its fitted ellipse.
The overlay is stored with the scan, synchronised to the server and displayed in
both the application and the clinical dashboard.

It exists so that a reported dimension can be assessed rather than only read. A
measurement taken from tissue and one taken from the printed label produce
identical-looking numbers; the overlay distinguishes them without requiring the
reviewer to reproduce the analysis. It is also the record of what the model
segmented at the time the scan was taken, which a later re-analysis with a
different model version cannot recover.

### 4.5 Null results

The model returns zero when no wound is segmented. Sub-millimetre extents are
treated identically, since no ulcer measures 0.4 mm across. The interface
therefore reports *no wound found* rather than "0.00 cm" whenever
$L \le 0.05$ cm or $W \le 0$: a numeric zero would be read as a healed wound.
This condition occurs on 6 of 157 clinical photographs.

---

## 5. Exclusion of the calibration label from the wound mask

Because the calibration label is deliberately placed inside the photographed
field, the segmentation stage must distinguish printed ink from tissue. Two
independent mechanisms are used, so that neither is a single point of failure.

### 5.1 Clinical fine-tuning

Model 1 was fine-tuned on a clinical corpus acquired under the study protocol:
**31 distinct wounds** across two hospitals, photographed with the calibration
label in frame, yielding **61 scored reference outlines**.

Reference boundaries were delineated manually to a fixed protocol — trace the
wound-bed margin, exclude callus and intact peri-wound skin, exclude the
calibration label. Manual delineation was selected as the training target on
measured grounds: against clinician tape measurement, manual boundaries achieve
**9.6–11.8%** error, and their test–retest agreement across repeat photographs
of the same wound is **±5.8%**, compared with **±15.0%** for automatic masks.
Repeatability is the governing property for a training target.

Outlines were screened before inclusion; any boundary deviating more than 20%
from the clinician's recorded measurement was re-delineated.

Training was performed on the Kaggle platform (NVIDIA P100), initialised from
the v1.1 weights, with the encoder frozen and the decoder and output head
trained on the clinical corpus mixed with the original training data to preserve
general performance.

### 5.2 Result

| Metric | v1.1 | v1.2 (deployed) |
|---|---|---|
| Calibration labels segmented as wound (n = 42) | 16 | **0** |
| Clinical held-out Dice | 0.803 | **0.869** |
| FUSeg validation Dice | 0.854 | **0.861** |
| Mean error vs clinician tape | 13.3% | **12.7%** |

**The deployed model segments no calibration label in the evaluation set
(0 of 42).** FUSeg validation Dice increased rather than decreased, confirming
that the clinical improvement was not obtained at the expense of general
segmentation performance.

### 5.3 Independent post-processing guard

A second, model-independent test is applied after segmentation. Chromatic
separation is not viable: measured ink fraction within granulation tissue spans
0.37–0.60, overlapping the printed range. The discriminating property is the
white substrate on which the label is printed.

For each candidate component a 4-pixel collar is sampled around its bounding box
and evaluated for paper:
## 6. Infection triage

Model 3 gives $p$ = P(infection) from the wound crop. It is **banded**, not
thresholded, because every threshold sits on one ROC curve and at clinic
prevalence the deployed 0.41 cut-off has **PPV 0.45** — wrong more often than
right.

$$\text{zone}(p) = \begin{cases}
\text{low} & p < 0.30\\
\text{uncertain} & 0.30 \le p \le 0.80\\
\text{high} & p > 0.80
\end{cases}$$

Five IWGDF/IDSA signs a camera cannot capture are collected from the patient:
purulent discharge, warmth, swelling, tenderness, systemic upset. The rule, in
order of precedence:

| # | Condition | Outcome |
|---|---|---|
| 1 | systemic upset | **urgent** |
| 2 | purulent discharge | **see clinician** |
| 3 | $\mathbb{1}[\text{zone}=\text{high}] + \text{local signs} \ge 2$ | **see clinician** |
| 4 | zone = high, nothing reported | **recheck photo** |
| 5 | exactly 1 sign, or zone = uncertain | **monitor** |
| 6 | otherwise | **no signs** |

Rules 1 and 2 are IWGDF/IDSA definitions, not thresholds we chose. Rule 3 is the
two-sign criterion for a local infection. An image in the uncertain band
contributes nothing to the count, since a score with no discriminative value
would otherwise inflate the total.

Measured on the reproduced cross-validation: **false alarms among healthy
patients 25.9% → 4.3%**.

"No signs" is never rendered as *normal*. A wound with no infection signs but
impaired perfusion shows the ischaemia warning instead, and a perfusion caveat
is shown under **every** blood-flow result including a reassuring one, because
this model reads colour and texture — it does not palpate a pulse, run a Doppler
or take an ankle pressure.

---

## 7. Glucose units

Stored canonically in mg/dL. The exact molar mass of glucose is 180.156 g/mol,
giving

$$\boxed{\ 1\ \text{mmol/L} = 18.0182\ \text{mg/dL}\ }$$

$$v_{mg/dL} = 18.0182\, v_{mmol/L}, \qquad
v_{mmol/L} = \frac{v_{mg/dL}}{18.0182}$$

Validation happens **in the unit the patient typed**, then converts — checking a
converted value against mg/dL bounds would reject an ordinary 6.2 mmol/L. The
plausible range is 20–600 mg/dL, converted into whichever unit is on screen.

Switching units converts what is already typed. Leaving the digits alone would
silently change their meaning: 110 entered as mg/dL becoming 110 mmol/L, which
is not a survivable blood sugar and would be stored as one.

---

## 8. Measurement accuracy

Evaluated on 31 distinct wounds acquired at two hospitals under the study
protocol, against clinician tape measurement.

| Condition | Mean error | Test–retest agreement |
|---|---|---|
| Model 1 v1.1 | 13.3% | ±15.0% |
| Model 1 v1.2 (deployed) | **12.7%** | — |
| Manual delineation, same wounds | 9.6–11.8% | ±5.8% |

Test–retest agreement is the spread between repeat photographs of the same
wound.

The calibration stage contributes **±1.8–5%**; the residual error is
attributable to segmentation rather than to scale recovery.

Held-out Dice: clinical 0.803 → **0.869**, FUSeg 0.854 → **0.861**. The increase
in FUSeg validation performance indicates that the clinical improvement was not
obtained at the expense of general segmentation performance.

**Interpretation.** A mean error of 12.7% corresponds to approximately 4 mm on a
3 cm wound. Manual delineation of the same wounds achieves 9.6–11.8%, which
indicates the practical ceiling of the present training target. The corpus of 31
wounds remains below the 30–50 wound target set for the study. The measurements
are intended to support longitudinal comparison of a single wound photographed
under consistent conditions, and are not presented as a substitute for direct
measurement.

> **Acceptance criterion.** Comparative error is evaluated over the
> **intersection** of wounds measurable by both model versions (n = 11), since a
> wound measurable by only one version cannot contribute a paired comparison.
> On that basis mean error is 13.32% (v1.1) against 12.69% (v1.2). Wounds
> measurable only by v1.2 are reported separately and are excluded from the
> paired mean.

---

## 9. Cross-platform agreement

Measurement runs on the device by default and, where a site enables server
mode, on the inference service. Both implement the procedure described above;
`ring_detector.dart` and `inference/ring.py` are direct ports of the same
validated reference implementation, and a parity test compares their outputs.

Verified on `teston app .jpeg`, a photograph in no training or validation set:

| | Phone | Server |
|---|---|---|
| Scale | 123.8 px/cm | 123.4 px/cm |
| Tilt | 25.0° | 24.5° |

Agreement to within 0.3% on scale, from independent implementations in two
languages.

---

## Related

- [FINDINGS](../../DF/clinical_validation/FINDINGS.md) — the running clinical record (kept outside this repository, with the patient data)
- [ACCURACY_IMPROVEMENT_PLAN](ACCURACY_IMPROVEMENT_PLAN.md) — the investigation that led here
- [MODEL1_RETRAINING](MODEL1_RETRAINING.md) — the fine-tune and its gate
- [DESIGN_MODIFICATION_LOG](DESIGN_MODIFICATION_LOG.md) — what changed, round by round
