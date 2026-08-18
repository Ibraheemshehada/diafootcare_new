# ============================================================
# CLINICAL 3/4 — fine-tune
# ============================================================
# Mixed with Xp_os, the precise FUSeg + DFUTissue pool this notebook already built
# and oversampled. 89 photographs against ~1,270: ours alone would score well on our
# own split and collapse everywhere else.
import numpy as np, tensorflow as tf, os

CLIN_OVERSAMPLE = 4
X_mix = np.concatenate([np.repeat(Xc_tr, CLIN_OVERSAMPLE, 0), Xp_os], 0)
Y_mix = np.concatenate([np.repeat(Yc_tr, CLIN_OVERSAMPLE, 0), Yp_os], 0)
print(f"mixed pool: {len(Xc_tr)}x{CLIN_OVERSAMPLE} clinical + {len(Xp_os)} precise "
      f"= {len(X_mix)}")

clin_tr_ds = make_ds(X_mix, Y_mix, training=True)
clin_va_ds = make_ds(Xc_va, Yc_va, training=False)

# Stage 1 — decoder only. A general encoder should not be moved by 89 photographs
# while the decoder is still adjusting to a new boundary convention.
model.backbone.trainable = False
model.compile(optimizer=make_opt(3e-4), loss=seg_loss,
              metrics=["accuracy", dice_coef, iou_metric])
print("\n[Clinical 1] decoder only, encoder frozen")
model.fit(clin_tr_ds, validation_data=clin_va_ds, epochs=12,
          callbacks=make_callbacks("unet_clinical.keras", patience=6))

# Stage 2 — the same deep unfreeze the notebook uses above, at a lower LR:
# adjust the boundary, do not overwrite the model.
model.backbone.trainable = True
for i, layer in enumerate(model.backbone.layers):
    if i < FINE_TUNE_FROM or isinstance(layer, BatchNormalization):
        layer.trainable = False
model.compile(optimizer=make_opt(2e-5), loss=seg_loss,
              metrics=["accuracy", dice_coef, iou_metric])
print("\n[Clinical 2] deep fine-tune, low LR")
model.fit(clin_tr_ds, validation_data=clin_va_ds, epochs=25,
          callbacks=make_callbacks("unet_clinical.keras", patience=10))

if os.path.exists("unet_clinical.keras"):
    model = tf.keras.models.load_model("unet_clinical.keras", compile=False)
    model.compile(optimizer="adam", loss=seg_loss, metrics=[dice_coef, iou_metric])
    print("\nloaded the best clinical checkpoint")
