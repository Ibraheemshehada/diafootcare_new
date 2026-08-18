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
way through the same ring**, reaches **10.1%**:

| | Hand-drawn | Model |
|---|---|---|
| Mean absolute error | **10.1%** | 27.2% |
| Within ±10% | 37 / 61 | 18 / 61 |
| Better on the wound | **16 / 21** | 5 / 21 |
| Spread across photographs of one wound | **±5.8%** | ±15.0% |

Only the boundary differs. So 10.1% is a **measured ceiling**, not a hope, and this
fine-tune is the attempt to reach it.

---

## 2. What you need, and one thing that is missing

| Piece | Where it is |
|---|---|
| The outlined dataset | produced by `export_training_set.py` → `D:\DF\clinical_validation\training_set` |
| The training recipe | `D:\Diafoot experments\model one\model-1-kaggle-with res.ipynb` — 384×384, MobileNetV2 encoder, BCE + Focal-Tversky, three phases |
| The deployed TFLite | `assets/models/model1_wound_fp16.tflite`, byte-identical to `…\model one\newmodel save22\model1_wound_fp16.tflite` |
| **The deployed Keras weights** | ⚠️ **not on this machine** |

**The missing piece matters.** The local `unet_phase2.keras` files are **320×320**,
from an earlier run. Checked rather than assumed: run against the deployed TFLite on
the same photographs, they agree on only **IoU 0.27**. They are a different model.

Two ways forward:

- **Preferred — recover the real weights.** On Kaggle, open the notebook version
  that produced `model1_wound_fp16.tflite` on **2026-07-04** and download
  `unet_phase2.keras` from its Output. Fine-tuning then starts exactly where the
  shipped model stands.
- **Fallback — re-run phases 1–2** of `model-1-kaggle-with res.ipynb` unchanged to
  regenerate a 384 baseline, then fine-tune that. Slower, and the baseline will not
  be bit-identical to what is shipped, so **the "before" column must be re-measured
  rather than copied from this document.**

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

Three choices that are easy to get wrong and are already handled: the split is **by
wound** (three shots of one ulcer are nearly the same picture); the five wounds the
model already handles are **forced into validation**; masks are rasterised **straight
at 384** from the polygon, so the boundary is resampled once.

---

## 4. Upload to Kaggle

1. **kaggle.com → Datasets → New Dataset.**
2. Drag the whole `training_set` folder in.
3. Title: `diafootcare-wound-outlines`. **Visibility: Private.** These are patient
   photographs — this is not optional.
4. Create a second private dataset, `diafootcare-model1`, holding `unet_phase2.keras`
   from §2.
5. If you use the anti-forgetting mix (§5), add the existing **DFUTissue** dataset as
   a third input.
6. **New Notebook → Add Input →** all three. Accelerator **GPU T4 ×2**.

---

## 5. Run the fine-tune

Copy `training/model1_finetune.py` into a cell, or attach it and run:

```python
!python model1_finetune.py
```

Paths come from the environment, so nothing in the file needs editing:

```python
import os
os.environ["DFC_DATA"]      = "/kaggle/input/diafootcare-wound-outlines"
os.environ["DFC_BASE"]      = "/kaggle/input/diafootcare-model1/unet_phase2.keras"
os.environ["DFC_DFUTISSUE"] = "/kaggle/input/dfutissue/DFUTissue/Labeled/Original"
```

**What it does, and why each part is there**

| Stage | | Why |
|---|---|---|
| Mix | clinical ×4 + DFUTissue precise pool | 71 photographs against the ~1,270 the model learned from. Training on ours alone would score well on our own validation split while collapsing in general |
| 1 | decoder only, encoder frozen, LR 3e-4 | a general image encoder should not be moved by 71 photographs while the decoder is still adjusting |
| 2 | everything, LR 2e-5 | low enough to adjust the boundary rather than overwrite the model |
| Loss | BCE + Focal-Tversky (β>α) | the wound is a median **0.9%** of the frame, and every diagnosed failure was the model measuring **too little** — so missed wound pixels are punished harder |
| Augmentation | flips, 90° rotations, mild colour | no elastic warping: here the boundary **is** the label |

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
2. **No held-out good wound regresses** beyond `max(1.5 × baseline, baseline + 5pp)`:

| Wound | Current error |
|---|---|
| `batch_v5_pending\|1` | 0.6% |
| `batch_2026-08-16_hospital1\|6` | 3.0% |
| `batch_2026-08-12_hospital2\|4` | 4.7% |
| `batch_2026-08-08_3patients\|3` | 10.5% |
| `batch_2026-08-16_hospital1\|4` | 18.9% |

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
