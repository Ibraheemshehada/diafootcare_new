# =============================================================================
# CLINICAL FINE-TUNE  ->  hand-outlined wounds from two hospitals
# =============================================================================
# Why this cell exists. The model above is trained on FUSeg + DFUTissue + boxes and
# reaches a good Dice. Measured against clinicians on 199 real photographs through a
# printed calibration ring, it is still ~26% away in CENTIMETRES, and the error is
# polarised by wound type: excellent on round bounded ulcers, failing on extended
# lesions with graded tissue. Outlining those same photographs by hand and measuring
# both the same way reaches ~12%. Only the boundary differs, so the fault is
# segmentation and this is the correction.
#
# Three things it is careful about:
#   1. It trains on our 89 photographs MIXED with Xp_os, the precise pool this
#      notebook already built. Ours alone would score well on our own split and
#      collapse everywhere else.
#   2. It judges in CENTIMETRES with the app's own post-processing, not by Dice.
#      A mask can gain Dice while losing the extent that actually gets measured.
#   3. It refuses to overwrite unet_model.keras unless a gate passes, so the export
#      cell below ships the fine-tuned model only when it is actually better.
import json, os, glob as _glob
import numpy as np, cv2, tensorflow as tf

CLIN_DIR = first_existing(
    "/kaggle/input/datasets/ibrahimshehada/diafootcare-wound-outlines",
    "/kaggle/input/diafootcare-wound-outlines",
    find="index.json")
print("clinical set:", CLIN_DIR)
assert CLIN_DIR, "attach the diafootcare-wound-outlines dataset"

_index = json.load(open(os.path.join(CLIN_DIR, "index.json"), encoding="utf-8"))
_splits = json.load(open(os.path.join(CLIN_DIR, "splits.json"), encoding="utf-8"))
_gate_wounds = list(json.load(open(os.path.join(CLIN_DIR, "gate.json"), encoding="utf-8")))
clin_tr = [it for it in _index if it["wound"] in _splits["train"]]
clin_va = [it for it in _index if it["wound"] in _splits["val"]]
print(f"clinical: {len(clin_tr)} train / {len(clin_va)} val photographs "
      f"({len(_splits['train'])}/{len(_splits['val'])} wounds, split BY WOUND)")


def _clin_pair(it):
    img = cv2.cvtColor(cv2.imread(os.path.join(CLIN_DIR, "images", it["file"])), cv2.COLOR_BGR2RGB)
    msk = cv2.imread(os.path.join(CLIN_DIR, "masks", it["file"]), cv2.IMREAD_GRAYSCALE)
    if img.shape[0] != IMG_HEIGHT:
        img = cv2.resize(img, (IMG_WIDTH, IMG_HEIGHT))
        msk = cv2.resize(msk, (IMG_WIDTH, IMG_HEIGHT), interpolation=cv2.INTER_NEAREST)
    return img.astype(np.float32) / 255.0, (msk > 127).astype(np.float32)[..., None]


Xc_tr = np.array([_clin_pair(it)[0] for it in clin_tr], np.float32)
Yc_tr = np.array([_clin_pair(it)[1] for it in clin_tr], np.float32)
Xc_va = np.array([_clin_pair(it)[0] for it in clin_va], np.float32)
Yc_va = np.array([_clin_pair(it)[1] for it in clin_va], np.float32)


# ---- measurement: identical to ai_service.dart, including the label guard --------
def _measure_cm(prob, item):
    """Major-axis extent in cm, or None. Every step below runs in the app.

    The label guard matters here: on 40% of small-label photographs the segmenter
    reads the printed magenta ring as granulation and returns the ring's own
    diameter as the wound size. Scoring without it would score a pipeline nobody runs.
    """
    m = (prob >= 0.5).astype(np.uint8)
    if m.sum() == 0:
        pk = float(prob.max())
        if pk <= 0:
            return None
        m = (prob > 0.5 * pk).astype(np.uint8)
    k = np.ones((5, 5), np.uint8)
    m = cv2.morphologyEx(cv2.morphologyEx(m, cv2.MORPH_OPEN, k), cv2.MORPH_CLOSE, k)
    n, lab, st, _ = cv2.connectedComponentsWithStats(m, 8)
    if n <= 1:
        return None

    bgr = cv2.imread(os.path.join(CLIN_DIR, "images", item["file"]))
    hsv = cv2.cvtColor(cv2.resize(bgr, (m.shape[1], m.shape[0])), cv2.COLOR_BGR2HSV)
    paper = (hsv[..., 1] < 50) & (hsv[..., 2] > 170)   # printed ink sits on a white card
    keep = []
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 10:
            continue
        comp = (lab == i).astype(np.uint8)
        collar = (cv2.dilate(comp, k, iterations=2) > 0) & (comp == 0)
        if collar.sum() and paper[collar].mean() >= 0.40:
            continue
        keep.append(i)
    if not keep:
        return None

    idx = max(keep, key=lambda i: st[i, cv2.CC_STAT_AREA])
    ys, xs = np.where(lab == idx)
    px, py = item.get("ppc_x"), item.get("ppc_y")
    if not px or not py:
        return None
    p = np.stack([xs * (m.shape[1] / IMG_WIDTH) / px,
                  ys * (m.shape[0] / IMG_HEIGHT) / py], 1).astype(np.float64)
    p -= p.mean(0)
    _, _, vt = np.linalg.svd(p, full_matrices=False)
    q = p @ vt.T
    return float(q[:, 0].max() - q[:, 0].min())


def clinical_report(net, title):
    """Mean absolute cm error per wound, plus Dice, on photographs never trained on."""
    per, dices, unmeasured = {}, [], 0
    P = net.predict(Xc_va, batch_size=8, verbose=0)[..., 0]
    Pf = net.predict(Xc_va[:, :, ::-1, :], batch_size=8, verbose=0)[..., 0][:, :, ::-1]
    P = (P + Pf) / 2.0
    for i, it in enumerate(clin_va):
        gt = Yc_va[i, ..., 0] > 0.5
        pr = P[i] >= 0.5
        dices.append(2 * (gt & pr).sum() / max(1e-6, gt.sum() + pr.sum()))
        if it.get("ref_quality") != "measured" or not it.get("ref_major"):
            continue                      # an estimate by eye is not ground truth
        cm = _measure_cm(P[i], it)
        if cm is None:
            unmeasured += 1
            continue
        per.setdefault(it["wound"], []).append(100.0 * (cm - it["ref_major"]) / it["ref_major"])
    w = {k: float(np.mean(np.abs(v))) for k, v in per.items()}
    print(f"\n--- {title} ---")
    print(f"  clinical Dice {np.mean(dices):.3f} | wounds scored in cm: {len(w)} | "
          f"unmeasurable: {unmeasured}")
    for k, v in sorted(w.items(), key=lambda kv: -kv[1]):
        print(f"    {k:<42}{v:6.1f}%")
    if w:
        print(f"  MEAN ABSOLUTE ERROR: {np.mean(list(w.values())):.1f}%")
    return w, float(np.mean(dices))


fuseg_before = model.evaluate(val_ds, verbose=0, return_dict=True)['dice_coef']
before, cdice_before = clinical_report(model, "BEFORE clinical fine-tune")

# ---- train: ours oversampled + the precise pool this notebook already built ------
CLIN_OVERSAMPLE = 4
X_mix = np.concatenate([np.repeat(Xc_tr, CLIN_OVERSAMPLE, 0), Xp_os], 0)
Y_mix = np.concatenate([np.repeat(Yc_tr, CLIN_OVERSAMPLE, 0), Yp_os], 0)
print(f"\nmixed pool: {len(Xc_tr)}x{CLIN_OVERSAMPLE} clinical + {len(Xp_os)} precise "
      f"= {len(X_mix)}")
clin_tr_ds = make_ds(X_mix, Y_mix, training=True)
clin_va_ds = make_ds(Xc_va, Yc_va, training=False)

# Stage 1 — decoder only. A general encoder should not be moved by 89 photographs
# while the decoder is still adjusting to a new boundary convention.
model.backbone.trainable = False
model.compile(optimizer=make_opt(3e-4), loss=seg_loss, metrics=['accuracy', dice_coef, iou_metric])
print("\n[Clinical 1] decoder only, encoder frozen")
model.fit(clin_tr_ds, validation_data=clin_va_ds, epochs=12,
          callbacks=make_callbacks("unet_clinical.keras", patience=6))

# Stage 2 — same deep unfreeze the notebook uses above, at a lower LR: adjust, not overwrite.
model.backbone.trainable = True
for i, layer in enumerate(model.backbone.layers):
    if i < FINE_TUNE_FROM or isinstance(layer, BatchNormalization):
        layer.trainable = False
model.compile(optimizer=make_opt(2e-5), loss=seg_loss, metrics=['accuracy', dice_coef, iou_metric])
print("\n[Clinical 2] deep fine-tune, low LR")
model.fit(clin_tr_ds, validation_data=clin_va_ds, epochs=25,
          callbacks=make_callbacks("unet_clinical.keras", patience=10))

if os.path.exists("unet_clinical.keras"):
    model = tf.keras.models.load_model("unet_clinical.keras", compile=False)
    model.compile(optimizer='adam', loss=seg_loss, metrics=[dice_coef, iou_metric])

after, cdice_after = clinical_report(model, "AFTER clinical fine-tune")
fuseg_after = model.evaluate(val_ds, verbose=0, return_dict=True)['dice_coef']

# ---- the gate -------------------------------------------------------------------
print("\n" + "=" * 74 + "\nGATE\n" + "=" * 74)
mb = np.mean(list(before.values())) if before else float('nan')
ma = np.mean(list(after.values())) if after else float('nan')
print(f"  clinical cm error   {mb:6.1f}%  ->  {ma:6.1f}%")
print(f"  clinical Dice       {cdice_before:6.3f}  ->  {cdice_after:6.3f}")
print(f"  FUSeg val Dice      {fuseg_before:6.3f}  ->  {fuseg_after:6.3f}   "
      "(the original domain — watch for forgetting)")

broke = []
print("\n  wounds the model already measured well:")
for w in _gate_wounds:
    # gate.json chooses WHICH wounds are checked; the baseline is this run's own
    # "before", never a number from another script measured on other inputs.
    b, a = before.get(w), after.get(w)
    if b is None or a is None:
        print(f"    {w:<42} not scored this run"); continue
    limit = max(b * 1.5, b + 5.0)          # tolerance, not a demand for perfection
    ok = a <= limit
    print(f"    {w:<42}{b:6.1f}% -> {a:6.1f}%   {'ok' if ok else 'REGRESSED'}")
    if not ok:
        broke.append(w)

forgot = fuseg_after < fuseg_before - 0.03
passed = (ma < mb) and not broke and not forgot
print("\n  " + ("PASS — unet_model.keras updated, the export cell will ship this"
                if passed else "FAIL — unet_model.keras left untouched"))
if not (ma < mb):
    print("    the clinical error did not improve")
for w in broke:
    print(f"    regressed: {w}")
if forgot:
    print(f"    forgot the original domain: FUSeg Dice fell {fuseg_before:.3f} -> {fuseg_after:.3f}")

json.dump(dict(before=before, after=after, clinical_dice=[cdice_before, cdice_after],
               fuseg_dice=[fuseg_before, fuseg_after], regressed=broke,
               forgot=bool(forgot), passed=bool(passed)),
          open("gate_report.json", "w"), indent=1)

if passed:
    model.save("unet_model.keras")
    print("\n  saved -> unet_model.keras")
else:
    model = tf.keras.models.load_model("unet_model.keras", compile=False)
    model.compile(optimizer='adam', loss=seg_loss, metrics=[dice_coef, iou_metric])
    print("\n  reloaded the pre-fine-tune model; nothing downstream changes.")
    print("  A model that fails the gate must not reach a patient.")
