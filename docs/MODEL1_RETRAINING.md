# Retraining Model 1 on hand-outlined clinical photographs

Everything needed to run the fine-tune on Kaggle and bring the result back into the
app. The evidence behind it is in `IMPLEMENTATION_TRACKER.md` C20–C29 and, for the
clinical detail, `FINDINGS.md` in the validation archive (kept outside this repo —
it holds patient photographs).

---

## 1. Why

The deployed segmenter measures wounds **27.2%** away from the clinician on average.
The error is not noise and not scale: the printed calibration ring is repeatable to
±1.8–5% while camera distance varies by a factor of two. It is **segmentation**, and
it is polarised by wound type — excellent on round bounded ulcers, failing on
extended lesions with graded tissue.

Outlining the same photographs by hand, and measuring outline and model **the same
way through the same ring**, reaches **11.8%**:

| | Hand-drawn | Model |
|---|---|---|
| Mean absolute error | **11.8%** | 25.8% |
| Median | **8.8%** | 18.0% |
| Within ±10% | **45 / 79** | 21 / 79 |
| Within ±25% | **68 / 79** | 47 / 79 |
| Closer to the clinician | **50 / 79** | — |
| Spread across photographs of one wound | **±5.8%** | ±15.0% |

*(89 outlines over 31 wounds; 79 carry a ruler measurement and are scored. The model's figure is
flattered: it produced no measurement at all in 7 photographs and a mean is taken only over the
ones it answered.)*

Only the boundary differs. So ~12% is a **measured ceiling**, not a hope, and this
fine-tune is the attempt to reach it.

---

## 2. What you need, and one thing that is missing

| Piece | Where it is |
|---|---|
| The outlined dataset | produced by `export_training_set.py` → `D:\DF\clinical_validation\training_set` |
| The training recipe | `D:\Diafoot experments\model one\model-1-kaggle-with res.ipynb` — 384×384, MobileNetV2 encoder, BCE + Focal-Tversky, three phases |
| The deployed TFLite | `assets/models/model1_wound_fp16.tflite`, byte-identical to `…\model one\newmodel save22\model1_wound_fp16.tflite` |
| **The deployed Keras weights** | ⚠️ **not on this machine** |

**The missing piece matters.** The local `unet_phase2.keras`
(`D:\Diafoot experments\model one\`, 18 June) is **320×320** from an earlier run.

Checked properly rather than assumed. A first comparison ran it at 320 against the
384 TFLite and gave IoU 0.27 — but that test was itself flawed: the network is fully
convolutional, so running it at the wrong size changes its answers regardless of the
weights. Rebuilt at 384 and compared like with like, it gives **IoU 0.203, mean
probability difference 0.028**. Genuinely different weights.

Before uploading any candidate, verify it:

```bash
python D:\DF\clinical_validation\scriptserify_base_weights.py <path-to-unet_phase2.keras>
```

The same weights give IoU > 0.95 and a probability difference near zero. A file with
the right name from the wrong run looks identical on disk, and the first sign of the
mistake would be a fine-tune that "improves" a model nobody is using.

### Where to find the real one

On Kaggle, in the notebook that produced the shipped export:

1. **kaggle.com → Your Work → Code** (or your profile → Code) — the notebook is
   `model-1-kaggle-with res` or the version of it that ran at 384.
2. Open it → **Versions** (top right) → find the run of **2026-07-04**, the one whose
   output produced `model1_wound_fp16.tflite` — that export is byte-identical to what
   ships, so it is the right version by definition.
3. **Output** tab → download **`unet_phase2.keras`** (~117 MB).
4. Verify it with the command above, then upload it as the private dataset
   `diafootcare-model1`.

**If the output has expired** (Kaggle keeps outputs only for saved versions), the
fallback is §2b.

### 2b. Fallback — regenerate the baseline

Re-run phases 1 and 2 of `model-1-kaggle-with res.ipynb` unchanged. It is the notebook
that produced the shipped model, so the recipe is right; only the random seed and the
run differ.

The consequence is worth being explicit about: the fine-tune then improves on a
**re-created** baseline, not on the model patients are using. The training gate stays
valid — it compares before and after within one run — but it no longer answers "is
this better than what is deployed?".

That question gets answered separately, after the run:

```bash
python D:\DF\clinical_validation\scripts\compare_tflite.py <shipped.tflite> <new.tflite>
```

Same wounds, same post-processing, same ring, both models. **That comparison is the
one that decides whether to ship**, and it does not depend on where the baseline came
from.

---

## 3. Prepare the data

```bash
# after every annotation session
python D:\DF\clinical_validation\scripts\build_annotation_set.py 3
python D:\DF\clinical_validation\scripts\export_training_set.py
```

Produces, in `training_set/`:

| | |
|---|---|
| `images/`, `masks/` | 384×384 PNG pairs |
| `splits.json` | train/val **by wound**, never by photograph |
| `gate.json` | the wounds the current model already measures well |
| `index.json` | per-photograph metadata, including `ppc_x`/`ppc_y` so the gate can be scored **in centimetres** without the ring detector |
| `dataset_card.md` | what it is and what it must not be used for |

Currently **89 photographs over 31 wounds** — 57 train / 32 validation, across 19 / 12
wounds. Three choices that are easy to get wrong and are already handled: the split is
**by wound** (three shots of one ulcer are nearly the same picture); the wounds the
model already handles are **forced into validation**; masks are rasterised **straight
at 384** from the polygon, so the boundary is resampled once.

`training_set.zip` beside the folder is the same thing in one file, for the upload.

---

## 4. Upload to Kaggle

1. **kaggle.com → Datasets → New Dataset.**
2. Drag the whole `training_set` folder in.
3. Title: `diafootcare-wound-outlines`. **Visibility: Private.** These are patient
   photographs — this is not optional.
4. Create a second private dataset, `diafootcare-model1`, holding `unet_phase2.keras`
   from §2.
5. Add **`fuseg-wound`** and **`dfutissue`** as further inputs — the anti-forgetting mix
   (§5). FUSeg is the important one: ~1,010 **whole-foot** photographs with precise
   masks at roughly 1% wound area, which is the same framing as our clinical
   photographs (median 0.9%). DFUTissue is tight crops at ~18%.
6. **New Notebook → Add Input →** all three. Accelerator **GPU T4 ×2**.

---

## 5. Run it — one notebook, one run

**`training/model1_retrain_kaggle.ipynb`** is the whole thing: the original training
notebook with four clinical cells added after self-training and before the TFLite
export. Upload that one file to Kaggle and run it.

Why one notebook rather than two: the deployed model's Keras weights were never saved
as a Kaggle version, so the baseline has to be regenerated anyway. One run therefore
produces everything —

| Output | |
|---|---|
| `unet_phase1.keras`, `unet_phase2.keras` | the baseline, finally saved |
| `unet_clinical.keras` | the fine-tuned checkpoint |
| `gate_report.json` | the evidence |
| `model1_wound_fp16.tflite` | exported from whatever passed the gate |

The four cells **reuse the notebook's own machinery** — `seg_loss`, `make_ds` with its
augmentation, `make_opt` with the mixed-precision loss scaling, `make_callbacks`, the
same `FINE_TUNE_FROM` deep-unfreeze, and above all `Xp_os`, the precise FUSeg +
DFUTissue pool it has already built. Duplicating any of that would let the fine-tune
drift from the recipe that produced the model it is fine-tuning.

Each cell also stands alone if the notebook was not run: it rebuilds the pool from the
same datasets, loads the model from any `.keras` it can find, and **says which checks
it could not perform** rather than passing silently.

| Stage | | Why |
|---|---|---|
| Mix | clinical ×4 + `Xp_os` | 89 photographs against ~1,270. Ours alone would score well on our own split and collapse everywhere else |
| 1 | decoder only, LR 3e-4 | a general encoder should not be moved by 89 photographs while the decoder is still adjusting to a new boundary convention |
| 2 | the same deep unfreeze, LR 2e-5 | adjust the boundary, do not overwrite the model |

**The safety property:** `unet_model.keras` is written **only if the gate passes**. On
failure the previous model is reloaded, so the export cell ships the old weights and a
failed experiment leaves no trace in what gets shipped.

---

## 6. The gate — decided before training, so it cannot be moved afterwards

The script scores in **centimetres, through the same ring, with the same
post-processing the app applies** — 0.5 threshold with the 0.5×peak fallback, 5×5
open then close, the printed-label guard, largest component, principal-axis extent.
Dice is reported but is **not** the gate: a mask can gain Dice while losing the
extent that actually gets measured.

**It passes only if both hold:**

1. **Mean absolute error across validation wounds improves** on the same model's own
   "before" figure, measured in the same run.
2. **No held-out good wound regresses** beyond `max(1.5 × baseline, baseline + 5pp)`,
   where the baseline is also **from this run's own "before" pass**.

`gate.json` chooses *which* wounds are checked; it never supplies the number they are
checked against. The two are measured by different scripts, and their image resampling
differs enough to move one wound by 8 percentage points — enough to excuse a real
regression or invent a false one. Paired comparison on identical inputs, always:

| Wound | Current error |
|---|---|
| `batch_v5_pending\|1` | 0.6% |
| `batch_2026-08-16_hospital1\|6` | 3.0% |
| `batch_2026-08-12_v5_beforeafter\|2` | 3.3% |
| `batch_2026-08-12_hospital2\|4` | 4.7% |
| `batch_2026-08-16_hospital1\|1` | 7.2% |
| `batch_2026-08-08_3patients\|3` | 10.5% |

That list is **read from `mask_eval.xlsx`, not typed** — the six most accurate wounds, capped at
six on purpose. Holding out every wound under 20% error took 14 of 31 and left 13 to train on; the
gate exists to *detect* a regression, and the wounds with the most to lose detect it.

If it fails, **the script stops before exporting**. A model that fails the gate must
not reach a patient, and the easiest way for that to happen is an exported file
sitting in a folder next to a passing one.

Results land in `gate_report.json`. **Keep it** — it is the evidence for the claim.

---

## 7. Back into the app

On success the script writes `model1_wound_fp16.tflite`. Then:

```bash
# from the repo root
cp <downloaded>/model1_wound_fp16.tflite assets/models/model1_wound_fp16.tflite
flutter analyze lib test && flutter test
```

**No Dart code changes** — architecture, input size (384×384×3), output shape and
post-processing are all unchanged, so the swap is the file and nothing else. That is
deliberate: it keeps the change reversible by restoring one file.

Note the model ships **downloaded on demand**, not inside the APK, so also publish
the new file wherever `ModelRepository` fetches from, and bump its version there —
otherwise installed devices keep the old weights and no local test will show it.

**Then verify on a device before believing it.** Nothing in this document is
evidence about the app until one photograph has gone through it end to end.

---

## 8. Afterwards — measure it again in the clinic

The gate proves the model improved **on photographs already collected**. It does not
prove it improved in the clinic. Run the next batch through `run_batch.py` as usual
and compare against the numbers in `FINDINGS.md`. Two things to watch, both already
known to matter more than the average:

- **Repeatability within one wound** — currently ±15.0% for the model against ±5.8%
  for the outlines. If the fine-tune helps, this should fall.
- **The failure modes**, not the mean: extended lesions with graded tissue
  (under-segmented) and dark necrotic tissue around a wound (over-segmented).
