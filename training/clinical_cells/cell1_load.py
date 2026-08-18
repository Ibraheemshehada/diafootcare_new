# ============================================================
# CLINICAL 1/4 — load the hand-outlined wounds
# ============================================================
# Runs on its own. Everything the later cells need from the notebook is checked
# here by name, so a missing piece says which one instead of raising NameError
# five cells later.
import json, os
import numpy as np, cv2, tensorflow as tf

IMG_H = globals().get("IMG_HEIGHT", 384)
IMG_W = globals().get("IMG_WIDTH", 384)
print(f"input size: {IMG_H}x{IMG_W}"
      + ("" if "IMG_HEIGHT" in globals() else "   (notebook value not found, using 384)"))


def _find_clinical():
    for c in ("/kaggle/input/datasets/ibrahimshehada/diafootcare-wound-outlines",
              "/kaggle/input/diafootcare-wound-outlines"):
        if os.path.exists(os.path.join(c, "index.json")):
            return c
    for root, _dirs, files in os.walk("/kaggle/input"):
        if "index.json" in files and "masks" in _dirs:
            return root
    return None


CLIN_DIR = _find_clinical()
assert CLIN_DIR, "attach the diafootcare-wound-outlines dataset first"
print("clinical set:", CLIN_DIR)

_index = json.load(open(os.path.join(CLIN_DIR, "index.json"), encoding="utf-8"))
_splits = json.load(open(os.path.join(CLIN_DIR, "splits.json"), encoding="utf-8"))
_gate_wounds = list(json.load(open(os.path.join(CLIN_DIR, "gate.json"), encoding="utf-8")))
clin_tr = [it for it in _index if it["wound"] in _splits["train"]]
clin_va = [it for it in _index if it["wound"] in _splits["val"]]


def _clin_pair(it):
    img = cv2.cvtColor(cv2.imread(os.path.join(CLIN_DIR, "images", it["file"])), cv2.COLOR_BGR2RGB)
    msk = cv2.imread(os.path.join(CLIN_DIR, "masks", it["file"]), cv2.IMREAD_GRAYSCALE)
    if img.shape[0] != IMG_H or img.shape[1] != IMG_W:
        img = cv2.resize(img, (IMG_W, IMG_H))
        msk = cv2.resize(msk, (IMG_W, IMG_H), interpolation=cv2.INTER_NEAREST)
    return img.astype(np.float32) / 255.0, (msk > 127).astype(np.float32)[..., None]


Xc_tr = np.array([_clin_pair(it)[0] for it in clin_tr], np.float32)
Yc_tr = np.array([_clin_pair(it)[1] for it in clin_tr], np.float32)
Xc_va = np.array([_clin_pair(it)[0] for it in clin_va], np.float32)
Yc_va = np.array([_clin_pair(it)[1] for it in clin_va], np.float32)

print(f"train {len(Xc_tr)} photographs / {len(_splits['train'])} wounds")
print(f"val   {len(Xc_va)} photographs / {len(_splits['val'])} wounds   "
      f"(split BY WOUND — three shots of one ulcer are nearly the same picture)")
print(f"gate  {len(_gate_wounds)} wounds the current model already measures well")

_missing = [n for n in ("model", "Xp_os", "Yp_os", "make_ds", "make_opt",
                        "make_callbacks", "seg_loss", "dice_coef", "iou_metric",
                        "val_ds", "FINE_TUNE_FROM", "BatchNormalization")
            if n not in globals()]
if _missing:
    print("\n⚠️  not in memory yet: " + ", ".join(_missing))
    print("    Run the notebook's own cells first (Run All). Cells 3 and 4 below")
    print("    train and gate; they need the model and the precise pool from above.")
else:
    print("\nall notebook pieces present — cells 2, 3, 4 can run")
