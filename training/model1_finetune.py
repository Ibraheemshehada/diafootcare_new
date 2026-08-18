# -*- coding: utf-8 -*-
"""Fine-tune Model 1 (wound segmentation) on hand-outlined clinical photographs.

Written to run as a single Kaggle notebook cell, or as a script. See
`docs/MODEL1_RETRAINING.md` for the upload steps and the acceptance gate.

WHAT THIS IS FOR
The deployed segmenter measures wounds ~27% away from the clinician, and the error
is polarised by wound type: excellent on round bounded ulcers, failing on extended
lesions with graded tissue. Outlining the same photographs by hand and measuring
both the same way reaches 11.8%. So the fault is segmentation, and this fine-tune
is the correction.

HOW IT AVOIDS THE THREE OBVIOUS WAYS OF GETTING THIS WRONG

1. **Catastrophic forgetting.** 89 clinical photographs against the ~1,270 the
   model was trained on. Training on ours alone would overwrite everything the
   model knows and score beautifully on our validation split while collapsing in
   general. Each epoch therefore mixes our photographs with the original precise
   DFUTissue pool, ours oversampled so they are seen often without being the only
   thing seen.

2. **Judging by Dice.** Dice is not what the app reports; centimetres are. A mask
   can gain Dice while losing the extent that gets measured. So the gate is scored
   in **centimetres, through the same printed ring, with the same post-processing
   the app applies** — including the label guard.

3. **Trading good cases for bad.** An average can improve while the wounds the
   model already handles are ruined. Six such wounds are held out and checked
   separately; the fine-tune fails if it breaks them, no matter what the mean does.
"""
import json, os, pathlib
import cv2
import numpy as np
import tensorflow as tf
from tensorflow.keras import backend as K

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
def first_existing(*candidates, find=None, roots=("/kaggle/input", ".")):
    """Resolve a path that Kaggle may have mounted under any of several slugs.

    Kaggle rewrites dataset paths depending on how a dataset was added
    (`/kaggle/input/<slug>` vs `/kaggle/input/datasets/<owner>/<slug>`), and a
    slug can be renamed between runs. The original training notebook resolved
    paths this way for exactly that reason, and hard-coding one spelling here
    would reintroduce the failure it was written to avoid.

    Tries each candidate, then falls back to searching for `find` as a path tail.
    """
    for c in candidates:
        if c and os.path.exists(c):
            return c
    if find:
        for root in roots:
            if not os.path.isdir(root):
                continue
            for dirpath, dirnames, filenames in os.walk(root):
                if dirpath.replace("\\", "/").endswith(find):
                    return dirpath
                tail = dirpath.replace("\\", "/")
                if os.path.basename(find) in filenames and tail.endswith(os.path.dirname(find)):
                    return dirpath
    return None


OWNER = os.environ.get("DFC_OWNER", "ibrahimshehada")

# The outlined set: whichever spelling Kaggle mounted it under, it is the folder
# that contains index.json.
DATA = os.environ.get("DFC_DATA") or first_existing(
    f"/kaggle/input/datasets/{OWNER}/diafootcare-wound-outlines",
    "/kaggle/input/diafootcare-wound-outlines",
    "./training_set",
    find="index.json")

# The base weights: the folder holding unet_phase2.keras.
_base_dir = first_existing(
    f"/kaggle/input/datasets/{OWNER}/diafootcare-model1",
    "/kaggle/input/diafootcare-model1",
    ".",
    find="unet_phase2.keras")
BASE_WEIGHTS = os.environ.get("DFC_BASE") or (
    os.path.join(_base_dir, "unet_phase2.keras") if _base_dir else "")

# The original precise pools, resolved by path tail rather than dataset name.
#
# FUSeg matters more than DFUTissue here and is listed first for that reason: it is
# ~1,010 whole-FOOT photographs with precise masks and roughly 1% wound area, which
# is the same domain as our clinical photographs (median 0.9%). DFUTissue is tight
# CROPS at ~18% wound area — valuable, but a different framing, and the original
# notebook oversampled it precisely because it is scarce rather than because it is
# representative.
_fuseg_img = os.environ.get("DFC_FUSEG_IMAGES") or first_existing(
    f"/kaggle/input/datasets/{OWNER}/fuseg-wound/FUSeg/train/images",
    find="FUSeg/train/images")
_fuseg_lbl = os.environ.get("DFC_FUSEG_LABELS") or first_existing(
    f"/kaggle/input/datasets/{OWNER}/fuseg-wound/FUSeg/train/labels",
    find="FUSeg/train/labels")

_dfu_img = os.environ.get("DFC_DFUTISSUE_IMAGES") or first_existing(
    f"/kaggle/input/datasets/{OWNER}/dfutissue/DFUTissue/Labeled/Original/Images/TrainVal",
    f"/kaggle/input/datasets/{OWNER}/dfutissuesegnet-main/DFUTissueSegNet-main/DFUTissue/Labeled/Original/Images/TrainVal",
    find="DFUTissue/Labeled/Original/Images/TrainVal")
_dfu_lbl = _dfu_img.replace("Images", "Annotations") if _dfu_img else None

MAX_FUSEG = int(os.environ.get("DFC_MAX_FUSEG", "0")) or None   # cap if RAM is tight

OUT = os.environ.get("DFC_OUT", "/kaggle/working" if os.path.isdir("/kaggle/working") else ".")

print(f"data      : {DATA}")
print(f"base      : {BASE_WEIGHTS}")
print(f"fuseg     : {_fuseg_img or 'NOT FOUND'}")
print(f"dfutissue : {_dfu_img or 'NOT FOUND'}")
if not _fuseg_img and not _dfu_img:
    print("WARNING: neither original pool found. The fine-tune would train on 89 "
          "photographs alone and may forget what the model already knows. "
          "The gate will tell you, so do not skip it.")

# DFUC2020's bbox pseudo-masks are deliberately NOT mixed in. They were useful for
# teaching the model where wounds are; they are rectangles, and this fine-tune is
# about the boundary. Training on them here would blunt the thing being sharpened.

IMG_SIZE = 384          # must match the deployed model; changing it changes the app
BATCH_SIZE = 8
EPOCHS_HEAD = 12        # decoder only, encoder frozen
EPOCHS_FULL = 25        # everything, low LR
LR_HEAD, LR_FULL = 3e-4, 2e-5
CLINICAL_OVERSAMPLE = 4
SEED = 42

tf.keras.utils.set_random_seed(SEED)
AUTOTUNE = tf.data.AUTOTUNE

# ---------------------------------------------------------------------------
# Losses — identical to the run that produced the deployed model
# ---------------------------------------------------------------------------
def dice_coef(y_true, y_pred, smooth=1.0):
    yt = K.flatten(K.cast(y_true, "float32"))
    yp = K.flatten(K.cast(y_pred, "float32"))
    inter = K.sum(yt * yp)
    return (2.0 * inter + smooth) / (K.sum(yt) + K.sum(yp) + smooth)


def iou_metric(y_true, y_pred, smooth=1.0):
    yt = K.flatten(K.cast(y_true, "float32"))
    yp = K.flatten(K.cast(K.round(y_pred), "float32"))
    inter = K.sum(yt * yp)
    return (inter + smooth) / (K.sum(yt) + K.sum(yp) - inter + smooth)


def focal_tversky_loss(y_true, y_pred, alpha=0.3, beta=0.7, gamma=0.75, smooth=1.0):
    """beta > alpha punishes MISSED wound pixels harder than false ones.

    Deliberate: the wound covers a median 0.9% of the frame in this set, and every
    failure mode we diagnosed clinically was the model measuring too little.
    """
    yt = K.flatten(K.cast(y_true, "float32"))
    yp = K.flatten(K.cast(y_pred, "float32"))
    tp = K.sum(yt * yp)
    fn = K.sum(yt * (1 - yp))
    fp = K.sum((1 - yt) * yp)
    tv = (tp + smooth) / (tp + alpha * fp + beta * fn + smooth)
    return K.pow(1.0 - tv, gamma)


def seg_loss(y_true, y_pred):
    """BCE for stable pixel-wise gradients, Focal-Tversky for overlap on a small region."""
    bce = tf.reduce_mean(tf.keras.losses.binary_crossentropy(
        tf.cast(y_true, "float32"), tf.cast(y_pred, "float32")))
    return bce + focal_tversky_loss(y_true, y_pred)


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------
def load_index():
    index = json.load(open(os.path.join(DATA, "index.json"), encoding="utf-8"))
    splits = json.load(open(os.path.join(DATA, "splits.json"), encoding="utf-8"))
    tr = [it for it in index if it["wound"] in splits["train"]]
    va = [it for it in index if it["wound"] in splits["val"]]
    return tr, va, splits


def read_pair(item):
    img = cv2.cvtColor(cv2.imread(os.path.join(DATA, "images", item["file"])), cv2.COLOR_BGR2RGB)
    msk = cv2.imread(os.path.join(DATA, "masks", item["file"]), cv2.IMREAD_GRAYSCALE)
    return img.astype(np.float32) / 255.0, (msk > 127).astype(np.float32)[..., None]


def load_seg_dir(img_dir, lbl_dir, limit=None):
    """Load an image/mask directory pair at IMG_SIZE. Masks may be 0/1, 0/255 or a
    label map — anything above zero is wound, which is what every source here means."""
    if not img_dir or not lbl_dir or not os.path.isdir(img_dir) or not os.path.isdir(lbl_dir):
        return (np.empty((0, IMG_SIZE, IMG_SIZE, 3), np.float32),
                np.empty((0, IMG_SIZE, IMG_SIZE, 1), np.float32))
    X, Y = [], []
    for name in sorted(os.listdir(img_dir)):
        ip = os.path.join(img_dir, name)
        mp = os.path.join(lbl_dir, name)
        if not os.path.exists(mp):
            for ext in (".png", ".jpg", ".jpeg"):
                alt = os.path.splitext(mp)[0] + ext
                if os.path.exists(alt):
                    mp = alt
                    break
            else:
                continue
        im, mk = cv2.imread(ip), cv2.imread(mp, cv2.IMREAD_GRAYSCALE)
        if im is None or mk is None:
            continue
        X.append(cv2.resize(cv2.cvtColor(im, cv2.COLOR_BGR2RGB),
                            (IMG_SIZE, IMG_SIZE)).astype(np.float32) / 255.0)
        Y.append((cv2.resize(mk, (IMG_SIZE, IMG_SIZE),
                             interpolation=cv2.INTER_NEAREST) > 0).astype(np.float32)[..., None])
        if limit and len(X) >= limit:
            break
    return np.asarray(X, np.float32), np.asarray(Y, np.float32)


def load_original_pool():
    """FUSeg train + DFUTissue TrainVal — what the model already knows, so it keeps knowing it."""
    Xf, Yf = load_seg_dir(_fuseg_img, _fuseg_lbl, MAX_FUSEG)
    Xd, Yd = load_seg_dir(_dfu_img, _dfu_lbl)
    print(f"original pool: FUSeg {len(Xf)}  +  DFUTissue {len(Xd)}")
    if not len(Xf) and not len(Xd):
        return Xf, Yf
    return (np.concatenate([a for a in (Xf, Xd) if len(a)]),
            np.concatenate([a for a in (Yf, Yd) if len(a)]))


def augment(x, y):
    """Geometry and light only. No elastic warping: the boundary IS the label here."""
    if tf.random.uniform([]) < 0.5:
        x, y = tf.image.flip_left_right(x), tf.image.flip_left_right(y)
    if tf.random.uniform([]) < 0.5:
        x, y = tf.image.flip_up_down(x), tf.image.flip_up_down(y)
    k = tf.random.uniform([], 0, 4, dtype=tf.int32)
    x, y = tf.image.rot90(x, k), tf.image.rot90(y, k)
    x = tf.image.random_brightness(x, 0.12)
    x = tf.image.random_contrast(x, 0.9, 1.1)
    x = tf.image.random_saturation(x, 0.9, 1.1)
    return tf.clip_by_value(x, 0.0, 1.0), y


def make_ds(X, Y, training):
    ds = tf.data.Dataset.from_tensor_slices((X, Y))
    if training:
        ds = ds.shuffle(min(len(X), 512), seed=SEED).map(augment, num_parallel_calls=AUTOTUNE)
    return ds.batch(BATCH_SIZE).prefetch(AUTOTUNE)


# ---------------------------------------------------------------------------
# Measurement — mirrors ai_service.dart and wound_mask.py exactly
# ---------------------------------------------------------------------------
def measure_cm(prob, item, guard=True):
    """Major-axis extent in centimetres, or None when nothing is measurable.

    Every step here exists in the shipped app: 0.5 threshold with a 0.5x-peak
    fallback, 5x5 open then close, the printed-label guard, largest component,
    principal-axis extent. Scoring anything else would score a pipeline nobody runs.
    """
    m = (prob >= 0.5).astype(np.uint8)
    if m.sum() == 0:
        peak = float(prob.max())
        if peak <= 0:
            return None
        m = (prob > 0.5 * peak).astype(np.uint8)
    k = np.ones((5, 5), np.uint8)
    m = cv2.morphologyEx(cv2.morphologyEx(m, cv2.MORPH_OPEN, k), cv2.MORPH_CLOSE, k)

    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    if n <= 1:
        return None
    keep = [i for i in range(1, n) if stats[i, cv2.CC_STAT_AREA] >= 10]

    if guard:
        img = cv2.imread(os.path.join(DATA, "images", item["file"]))
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        paper = (hsv[..., 1] < 50) & (hsv[..., 2] > 170)
        kept = []
        for i in keep:
            comp = (lab == i).astype(np.uint8)
            collar = (cv2.dilate(comp, k, iterations=2) > 0) & (comp == 0)
            if collar.sum() and paper[collar].mean() >= 0.40:
                continue            # printed calibration label, not tissue
            kept.append(i)
        keep = kept
    if not keep:
        return None

    idx = max(keep, key=lambda i: stats[i, cv2.CC_STAT_AREA])
    ys, xs = np.where(lab == idx)
    if len(xs) < 10:
        return None
    ppc_x, ppc_y = item.get("ppc_x"), item.get("ppc_y")
    if not ppc_x or not ppc_y:
        return None
    p = np.stack([xs / ppc_x, ys / ppc_y], 1).astype(np.float64)
    p -= p.mean(0)
    _, _, vt = np.linalg.svd(p, full_matrices=False)
    q = p @ vt.T
    return float(q[:, 0].max() - q[:, 0].min())


def evaluate(model, items, title):
    """Centimetre error per wound, and Dice, on the photographs the model never trained on."""
    per_wound, dices, unmeasured = {}, [], 0
    for it in items:
        img, msk = read_pair(it)
        p = model.predict(img[None], verbose=0)[0, ..., 0]
        p = (p + model.predict(np.fliplr(img)[None], verbose=0)[0, ..., 0][:, ::-1]) / 2.0
        inter = ((p >= 0.5) & (msk[..., 0] > 0.5)).sum()
        dices.append(2 * inter / max(1e-6, (p >= 0.5).sum() + (msk[..., 0] > 0.5).sum()))
        if it.get("ref_quality") != "measured" or not it.get("ref_major"):
            continue                       # an estimate is not ground truth
        cm = measure_cm(p, it)
        if cm is None:
            unmeasured += 1
            continue
        err = 100.0 * (cm - it["ref_major"]) / it["ref_major"]
        per_wound.setdefault(it["wound"], []).append(err)

    wounds = {w: float(np.mean(np.abs(e))) for w, e in per_wound.items()}
    print(f"\n=== {title} ===")
    print(f"  Dice {np.mean(dices):.3f}   |   photographs scored in cm: "
          f"{sum(len(v) for v in per_wound.values())}   |   unmeasurable: {unmeasured}")
    for w, e in sorted(wounds.items(), key=lambda kv: -kv[1]):
        print(f"    {w:<40} {e:6.1f}%")
    if wounds:
        print(f"  MEAN ABSOLUTE ERROR ACROSS WOUNDS: {np.mean(list(wounds.values())):.1f}%")
    return wounds, float(np.mean(dices)), unmeasured


# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
def main():
    tr_items, va_items, splits = load_index()
    print(f"clinical: {len(tr_items)} train / {len(va_items)} val photographs "
          f"({len(splits['train'])}/{len(splits['val'])} wounds)")

    Xc = np.stack([read_pair(it)[0] for it in tr_items])
    Yc = np.stack([read_pair(it)[1] for it in tr_items])
    Xv = np.stack([read_pair(it)[0] for it in va_items])
    Yv = np.stack([read_pair(it)[1] for it in va_items])

    Xo, Yo = load_original_pool()
    if len(Xo):
        Xt = np.concatenate([np.repeat(Xc, CLINICAL_OVERSAMPLE, 0), Xo])
        Yt = np.concatenate([np.repeat(Yc, CLINICAL_OVERSAMPLE, 0), Yo])
        print(f"mixed training pool: {len(Xc)}x{CLINICAL_OVERSAMPLE} clinical + {len(Xo)} original")
    else:
        Xt, Yt = Xc, Yc
        print("WARNING: no original pool - training on clinical photographs ALONE.")
        print("         The model may forget what it already knows; the gate below")
        print("         is the only thing that will tell you, so do not skip it.")

    model = tf.keras.models.load_model(BASE_WEIGHTS, compile=False)
    assert model.input_shape[1:3] == (IMG_SIZE, IMG_SIZE), \
        f"base weights are {model.input_shape[1:3]}, the app expects {(IMG_SIZE, IMG_SIZE)}"

    before, dice_before, _ = evaluate(model, va_items, "BEFORE fine-tuning")

    backbone = next((l for l in model.layers if isinstance(l, tf.keras.Model)), None)
    train_ds, val_ds = make_ds(Xt, Yt, True), make_ds(Xv, Yv, False)
    ckpt = os.path.join(OUT, "unet_finetuned.keras")
    cb = [tf.keras.callbacks.ModelCheckpoint(ckpt, monitor="val_dice_coef", mode="max",
                                             save_best_only=True, verbose=1),
          tf.keras.callbacks.ReduceLROnPlateau(monitor="val_dice_coef", mode="max",
                                               factor=0.5, patience=4, min_lr=1e-7, verbose=1),
          tf.keras.callbacks.EarlyStopping(monitor="val_dice_coef", mode="max",
                                           patience=10, restore_best_weights=True, verbose=1)]

    if backbone is not None:
        # Stage 1 — decoder only. The encoder is a general image model; letting it
        # move while the decoder is still adjusting to 71 photographs is how a small
        # set does large damage.
        backbone.trainable = False
        model.compile(optimizer=tf.keras.optimizers.Adam(LR_HEAD), loss=seg_loss,
                      metrics=[dice_coef, iou_metric])
        print("\n[Stage 1] decoder only, encoder frozen")
        model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD, callbacks=cb, verbose=2)
        backbone.trainable = True

    # Stage 2 — everything, at a learning rate low enough to adjust rather than overwrite.
    model.compile(optimizer=tf.keras.optimizers.Adam(LR_FULL), loss=seg_loss,
                  metrics=[dice_coef, iou_metric])
    print("\n[Stage 2] full network, low learning rate")
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FULL, callbacks=cb, verbose=2)

    after, dice_after, unmeasured = evaluate(model, va_items, "AFTER fine-tuning")

    # ---- the gate ----
    gate_wounds = json.load(open(os.path.join(DATA, "gate.json"), encoding="utf-8"))
    print("\n" + "=" * 72 + "\nGATE\n" + "=" * 72)
    mean_before = np.mean(list(before.values())) if before else float("nan")
    mean_after = np.mean(list(after.values())) if after else float("nan")
    print(f"  mean absolute error   {mean_before:.1f}%  ->  {mean_after:.1f}%")
    print(f"  Dice                  {dice_before:.3f}  ->  {dice_after:.3f}")

    broke = []
    print("\n  wounds the model already measured well:")
    for w in gate_wounds:
        # `gate.json` chooses WHICH wounds are the check. The baseline comes from
        # this run's own "before" pass, never from that file: the two are measured
        # by different scripts, whose image resampling differs enough to move one
        # wound by 8 percentage points. A paired comparison on identical inputs is
        # sound; comparing across measurement contexts is not, and would either
        # excuse a real regression or invent a false one.
        base, now = before.get(w), after.get(w)
        if base is None or now is None:
            print(f"    {w:<40} not scored this run"); continue
        # A tolerance, not a demand for perfection: a good wound may move a little.
        limit = max(base * 1.5, base + 5.0)
        ok = now <= limit
        print(f"    {w:<40} {base:5.1f}%  ->  {now:5.1f}%   {'ok' if ok else 'REGRESSED'}")
        if not ok:
            broke.append(w)

    improved = mean_after < mean_before
    passed = improved and not broke
    print("\n  " + ("PASS — export it" if passed else "FAIL — do not ship this"))
    if not improved:
        print("    the average did not improve")
    for w in broke:
        print(f"    regressed: {w}")

    json.dump(dict(before=before, after=after, dice_before=dice_before, dice_after=dice_after,
                   regressed=broke, passed=bool(passed), unmeasured=unmeasured),
              open(os.path.join(OUT, "gate_report.json"), "w"), indent=1)

    if not passed:
        print("\nStopping before export. A model that fails the gate must not reach a patient.")
        return

    sm = os.path.join(OUT, "saved_model")
    model.export(sm)
    conv = tf.lite.TFLiteConverter.from_saved_model(sm)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]
    conv.target_spec.supported_types = [tf.float16]
    pathlib.Path(os.path.join(OUT, "model1_wound_fp16.tflite")).write_bytes(conv.convert())
    print(f"\nexported -> {os.path.join(OUT, 'model1_wound_fp16.tflite')}")


if __name__ == "__main__":
    main()
