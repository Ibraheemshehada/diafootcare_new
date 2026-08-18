# ============================================================
# CLINICAL 4/4 — the gate, then save only if it passes
# ============================================================
import json
import numpy as np, tensorflow as tf

after, cdice_after = clinical_report(model, "AFTER clinical fine-tune")
fuseg_after = model.evaluate(val_ds, verbose=0, return_dict=True)["dice_coef"]

print("\n" + "=" * 74 + "\nGATE\n" + "=" * 74)
mb = np.mean(list(before.values())) if before else float("nan")
ma = np.mean(list(after.values())) if after else float("nan")
print(f"  clinical cm error   {mb:6.1f}%  ->  {ma:6.1f}%")
print(f"  clinical Dice       {cdice_before:6.3f}  ->  {cdice_after:6.3f}")
print(f"  FUSeg val Dice      {fuseg_before:6.3f}  ->  {fuseg_after:6.3f}")

broke = []
print("\n  wounds the model already measured well:")
for w in _gate_wounds:
    # gate.json chooses WHICH wounds are checked. The baseline is this run's own
    # "before" pass, never a number from another script measured on other inputs.
    b, a = before.get(w), after.get(w)
    if b is None or a is None:
        print(f"    {w:<42} not scored this run")
        continue
    limit = max(b * 1.5, b + 5.0)          # tolerance, not a demand for perfection
    ok = a <= limit
    verdict = "ok" if ok else "REGRESSED"
    print(f"    {w:<42}{b:6.1f}% -> {a:6.1f}%   {verdict}")
    if not ok:
        broke.append(w)

forgot = fuseg_after < fuseg_before - 0.03
passed = (ma < mb) and not broke and not forgot

print("\n  " + ("PASS - unet_model.keras updated, the export cell will ship this"
                if passed else "FAIL - unet_model.keras left untouched"))
if not (ma < mb):
    print("    the clinical error did not improve")
for w in broke:
    print("    regressed: " + w)
if forgot:
    print(f"    forgot the original domain: FUSeg Dice {fuseg_before:.3f} -> {fuseg_after:.3f}")

json.dump(dict(before=before, after=after, clinical_dice=[cdice_before, cdice_after],
               fuseg_dice=[fuseg_before, fuseg_after], regressed=broke,
               forgot=bool(forgot), passed=bool(passed)),
          open("gate_report.json", "w"), indent=1)

if passed:
    model.save("unet_model.keras")
    print("\n  saved -> unet_model.keras")
else:
    # Reload the pre-fine-tune model so the export cell ships the OLD weights.
    # A failed experiment must leave no trace in what reaches a patient.
    model = tf.keras.models.load_model("unet_model.keras", compile=False)
    model.compile(optimizer="adam", loss=seg_loss, metrics=[dice_coef, iou_metric])
    print("\n  reloaded the pre-fine-tune model; nothing downstream changes.")
