# ============================================================
# CLINICAL 2/4 — measure the model the way the app measures it
# ============================================================
# In CENTIMETRES, not Dice. A mask can gain Dice while losing the extent that
# actually gets measured, and centimetres are what the clinician is handed.
# Every step below runs in ai_service.dart, the label guard included: on 40% of
# small-label photographs the segmenter reads the printed magenta ring as
# granulation and returns the ring's own diameter as the wound size.
import numpy as np, cv2, os


def _measure_cm(prob, item):
    m = (prob >= 0.5).astype(np.uint8)
    if m.sum() == 0:                                  # 0.5x-peak fallback
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
    paper = (hsv[..., 1] < 50) & (hsv[..., 2] > 170)  # printed ink sits on a white card
    keep = []
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] < 10:
            continue
        comp = (lab == i).astype(np.uint8)
        collar = (cv2.dilate(comp, k, iterations=2) > 0) & (comp == 0)
        if collar.sum() and paper[collar].mean() >= 0.40:
            continue                                  # that blob is the label
        keep.append(i)
    if not keep:
        return None

    idx = max(keep, key=lambda i: st[i, cv2.CC_STAT_AREA])
    ys, xs = np.where(lab == idx)
    px, py = item.get("ppc_x"), item.get("ppc_y")     # pixels per cm, from the ring
    if not px or not py:
        return None
    sx, sy = m.shape[1] / IMG_W, m.shape[0] / IMG_H
    p = np.stack([xs * sx / px, ys * sy / py], 1).astype(np.float64)
    p -= p.mean(0)
    _, _, vt = np.linalg.svd(p, full_matrices=False)  # principal axis = longest extent
    q = p @ vt.T
    return float(q[:, 0].max() - q[:, 0].min())


def clinical_report(net, title):
    per, dices, unmeasured = {}, [], 0
    P = net.predict(Xc_va, batch_size=8, verbose=0)[..., 0]
    Pf = net.predict(Xc_va[:, :, ::-1, :], batch_size=8, verbose=0)[..., 0][:, :, ::-1]
    P = (P + Pf) / 2.0                                # 2-view TTA, as the app does
    for i, it in enumerate(clin_va):
        gt, pr = Yc_va[i, ..., 0] > 0.5, P[i] >= 0.5
        dices.append(2 * (gt & pr).sum() / max(1e-6, gt.sum() + pr.sum()))
        if it.get("ref_quality") != "measured" or not it.get("ref_major"):
            continue                                  # an estimate by eye is not truth
        cm = _measure_cm(P[i], it)
        if cm is None:
            unmeasured += 1
            continue
        per.setdefault(it["wound"], []).append(100.0 * (cm - it["ref_major"]) / it["ref_major"])
    w = {k: float(np.mean(np.abs(v))) for k, v in per.items()}
    print("\n--- " + title + " ---")
    print(f"  clinical Dice {np.mean(dices):.3f} | wounds scored: {len(w)} | "
          f"unmeasurable: {unmeasured}")
    for k, v in sorted(w.items(), key=lambda kv: -kv[1]):
        print(f"    {k:<42}{v:6.1f}%")
    if w:
        print(f"  MEAN ABSOLUTE ERROR: {np.mean(list(w.values())):.1f}%")
    return w, float(np.mean(dices))


fuseg_before = model.evaluate(val_ds, verbose=0, return_dict=True)["dice_coef"]
before, cdice_before = clinical_report(model, "BEFORE clinical fine-tune")
print(f"\nFUSeg val Dice (the original domain): {fuseg_before:.3f}")
