# On-device tests

Everything else in this repo is measured on a desktop: the Python pipeline over
239 clinic photographs, the Dart detector against that pipeline, widget tests
over synthetic images. None of it proves the path works on a **phone**, where the
JPEG decoder, the isolates and the file system all differ.

## Running them

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Clinic photographs must reach the app's own sandbox. /sdcard/Download is
# scoped away on Android 14 behind a permission prompt a test cannot answer, and
# files adb pushes to the external directory belong to the shell user, which the
# app may not read. Internal storage is the one place both sides can reach.
for f in wound_test:H1f_P1_6 wound_tilted:H1e_P3_24; do
  adb push "D:/DF/clinical_validation/annotate/images/${f#*:}.jpeg" "/data/local/tmp/${f%%:*}.jpg"
  adb shell "run-as tech.diafootcare.app sh -c 'cat /data/local/tmp/${f%%:*}.jpg > files/${f%%:*}.jpg'"
done

flutter test integration_test/wound_pipeline_test.dart -d emulator-5554
```

**`flutter test integration_test` uninstalls the app when it finishes**, so the
push has to be redone before each run — and `run-as` will report "unknown
package" if you forget to reinstall first.

## What it proved, 2026-08-19, Pixel 4 API 36

| | |
|---|---|
| Ring found and measured | **152.6 px/cm** against the reference detector's 152.3 — **0.2%** |
| Tilt read | 11° on the square photograph, **41° on the tilted one** |
| Capture gate | **refused** the 41° photograph, `blocks: true` |
| Overlay | rendered and written, 609 KB |
| Schema | migrated to **v22** on a real install: `overlayPath`, `pixelsPerCm`, `tiltDeg` |

## What these do NOT cover

Segmentation. It loads a 12 MB TFLite model whose accuracy is measured over all
239 photographs by the Python pipeline, which is a better instrument than a
single device run. What could only be checked here is whether the **Dart** path
from photograph to centimetres survives a phone.
