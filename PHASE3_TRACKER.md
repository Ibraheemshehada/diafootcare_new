# DiaFootCare — Phase 3 Tracker: Online / Offline Modes & Model Delivery

The piece the brief opens with and that Phase 2 deliberately left alone.
Phase 2 (identity, sync, dashboard) is in [`PHASE2_TRACKER.md`](PHASE2_TRACKER.md).

**Legend:** ✅ done · 🚧 in progress · ⚠️ blocked/decision needed · ⬜ not started

_Created: 2026-07-19_

---

## START HERE — handoff

**Phase 3 is feature-complete. F1–F6 are built, on device, and verified.**

### The numbers

| | Before | After |
|---|---|---|
| Release APK (universal) | 284.8 MB | **86.7 MB** |
| Release APK (arm64, what a phone installs) | ~230 MB | **30.5 MB** |
| Flutter assets inside the APK | ~200 MB | 0.3 MB |

The 86.7 MB universal figure is three ABIs of native libs (84.6 MB of it); a
device only ever installs one. Ship an **App Bundle**, or `--split-per-abi`, and
the real download is ~30 MB. Only the universal APK was measured before, so the
arm64 "before" is inferred rather than observed.

### Where to pick up

No feature work is queued. The open items below are the backlog, and
**background download is the one that matters most** — it is the difference
between a 200 MB download that finishes and one a patient has to nurse across
several sessions.

If you are deploying, the web repo's tracker and `DEPLOYMENT.md` are the
documents; the nginx block there is still untested.

### State of the world

| | |
|---|---|
| Mobile tests | 75 pass |
| Analyzer | 0 errors |
| On-device parity | passes on both clinical fixtures |
| Server parity suite | 4 checks pass |
| Release APK | builds, universal and split |

### What F6 turned up

Removing the models exposed three things that were only ever hidden by the
models being present. All three are fixed, and all three were found by running
the app, not by reading it.

**A wound with no models returned an invented result.** 8.1 × 5.0 cm,
"Granulation", risk "Normal", after a two-second pause that made it look like
work had happened. Unreachable while the models shipped in the APK; reachable
the moment they did not. A phone now refuses and says why. Web keeps the
simulation, having no TFLite and no patients.

**A finished download did nothing until the app restarted.** `AiService.init()`
set `_initialized = true` even when every model had failed to load, so the first
run before the bundle arrived cached that failure permanently. The app insisted
the files were missing while they sat on disk. It now only counts as initialised
if something loaded.

**Every specific error message was dead code.** `ApiClient` sets
`validateStatus: s < 500` so error bodies stay readable, which means a 401 is
not a `DioException` — it arrives as a normal response.
`RemoteAnalysisService` went straight to `data['analysis']`, threw a cast error,
and every case landed on the generic "Analysis failed". Status is now checked
explicitly.

### The mode follows the files

Finishing a download switches the app to offline: someone who sat through 200 MB
did it to stop depending on a connection, and leaving them online would mean the
next scan still failing in a clinic with no signal. Deleting the bundle switches
back to online, rather than leaving the app claiming a capability it no longer
has.

When neither route is available — no server *and* no files — the message names
both problems and both ways out. Telling someone only about the connection sends
them to find wifi for an analysis that would still fail when they got there.

Covered by three tests in `model_download_test.dart`. The one that matters is
*a failed download leaves the mode alone*: it was mutation-checked by moving the
switch to before the transfer, so it discriminates rather than passing by
accident. Switching on intent instead of on the files arriving would leave a
half-downloaded phone claiming an offline capability it cannot serve.

### If you are moving to a MacBook

`IOS_TRACKER.md` is the file. It separates what is verified about this repo from
what is only expected on a Mac, because none of the iOS path has ever been
compiled. Two things in it are wrong today and worth knowing before you start:
the bundle identifier is still `com.example.daifootcareNew`, and Firebase config
survives in both platform folders — including a `GoogleService-Info.plist`
committed to git — for an integration that no longer exists in `pubspec.yaml` or
`lib/`.

### What is open, in rough priority order

1. **Background download** — measured: zero progress over 80 s backgrounded,
   because Android reclaims the Flutter engine under memory pressure, not
   because Dart is suspended. Resume means nothing is lost but time. An Android
   foreground service is the recommended first step; `background_downloader`
   solves iOS too but costs the unit-testability of the transfer path, and
   **iOS has never been built in this repo and cannot be, on Windows**. Written
   up under *"Open — the model download does not continue in the background"*.
2. **Mandatory consent** — accepting is still required to use the app during the
   study. Flagged repeatedly; an ethics board will ask.
3. **`_backfillMissingUuids` passes a null `whereArgs`.** sqflite warns it will
   throw in a future version. Harmless today, a broken upgrade path later.
4. **Metered connections** — nothing checks whether a 200 MB download is about to
   run on mobile data.
5. **Deleting the bundle while the app is running** leaves `AiService` holding
   closed-file interpreters until something calls `invalidate()`. The method
   exists; nothing calls it yet, because the delete path also sends the app back
   to online mode where they are not used.
6. **Dashboard** shows the tissue summary but not the per-class breakdown.
7. **nginx config in `DEPLOYMENT.md` is untested** — no nginx on this machine.

### One thing to keep an eye on

The suite failed 4 tests once, in a run three times slower than usual, while the
web parity suite was loading 200 MB of models in the same command. It has passed
every run since, including under deliberate CPU load, so the cause was almost
certainly memory pressure. `model_download_test` uses real HTTP servers and
duration-based waits, so that is where to look if it recurs.

---

## 0) What we are building, and why it is shaped this way

The app currently bundles **~208 MB of TFLite models inside the APK**. Every install
pays that download whether or not the patient ever captures a wound. The brief's
answer is a choice at first launch:

| | Mode A — Online | Mode B — Offline |
|---|---|---|
| Install size | small | small, then a ~208 MB download |
| Analysis runs | on the server | on the phone |
| Needs a connection | to analyse | only to sync |
| Suits | good connectivity, low-end phones, trying the app | clinic with poor signal, privacy-sensitive, daily use |

Both modes sync records the same way — that part is already built and working.

### The measurements
| File | Size | Role |
|---|---|---|
| `clip_backbone_fp16.tflite` | 175.8 MB | shared CLIP feature extractor |
| `tissue_head.tflite` | 20.2 MB | tissue classification |
| `model1_wound_fp16.tflite` | 12.4 MB | segmentation → length/width/area |
| `infection_ischaemia_head.tflite` | 0.27 MB | infection / ischaemia |
| 2 × `*_meta.json` | ~1 KB | head metadata |
| **Total** | **~208 MB** | |

The backbone alone is 85% of the payload. Any download UI that does not survive a
dropped connection is useless at this size on a clinic's wifi.

---

## ⚠️ The decision that shapes the VPS: Mode A cannot run on Laravel alone

**PHP has no TFLite runtime.** Mode A means the server performs the same inference the
phone does, and Laravel cannot do it in-process. The realistic options:

1. **Python sidecar (recommended).** A small FastAPI service on the same VPS running
   `tflite-runtime`, reachable only on localhost. Laravel receives the upload, calls the
   sidecar, stores the result. Same model files, same versions, same numbers as the phone.
2. Convert the models to ONNX and use a PHP binding. Bindings are immature and the
   conversion would have to be re-validated against the phone's outputs — a research task,
   not an integration one.
3. A managed inference API. Sends patient wound images to a third party, which reopens
   the consent question in a worse form.

**Going with (1).** It keeps one set of model files as the source of truth for both modes,
which is also what makes `models_version` on a scan meaningful.

> ⚠️ **Mode A and Mode B must agree.** If the server runs a different model build than a
> given phone downloaded, two patients get different answers from the same photo. Every
> scan already carries `models_version`; the manifest below is what makes it true.

---

## 1) Feature list — built in this order

Each is shippable on its own and verifiable before the next starts.

### F1. Model manifest + hosted files (web) ✅
- ⬜ `GET /api/v1/models/manifest` → version, per-file name, size, sha256, URL
- ⬜ Files served with **HTTP Range** support so a download can resume
- ⬜ Checksums generated from the real files, not hand-typed
- ⬜ Manifest is public (no token): a phone in Mode B may not have signed in yet

### F2. First-run mode selection (mobile) ✅
- ⬜ Onboarding screen after consent, before the app opens
- ⬜ Persist the choice; changeable later from Profile
- ⬜ EN/AR + RTL, 48dp targets, screen-reader labels — parity with the rest of the app
- ⬜ Report the choice to the server (`devices/{uuid}/mode` already exists)

### F3. Resumable model download (mobile) ✅
- ⬜ Range-request downloader with resume after a dropped connection or app restart
- ⬜ Per-file and overall progress, pause / resume / retry
- ⬜ sha256 verified before a file is accepted; a corrupt file is re-fetched, not used
- ⬜ Refuses to start on a metered connection without consent, and on low storage
- ⬜ Survives the app being backgrounded

### F4. AiService loads downloaded files (mobile) ✅
- ⬜ `Interpreter.fromFile` when the models are on disk, `fromAsset` otherwise
- ⬜ Mode B with an incomplete download degrades honestly rather than silently failing
- ⬜ **Only after F3 is proven**: this touches every inference path and the app is
      currently correct offline. Regressing that is worse than a large APK.

### F5. Online analysis (web + mobile) ✅
- ⬜ Python inference sidecar (FastAPI + tflite-runtime), localhost only
- ⬜ `POST /api/v1/analyse` — image in, the same result shape `AiService` returns
- ⬜ Mobile Mode A path calling it, with the result screen unchanged
- ⬜ Graceful failure when the network drops mid-analysis

### F6. Unbundle the models from the APK ✅
- ⬜ Remove `assets/models/` from `pubspec.yaml`
- ⬜ **Last step, deliberately.** Until F3 and F5 are proven on a device, the bundled
      models are the working fallback. Removing them early turns any bug in the new path
      into "the app cannot analyse anything".

---

## 2) The flows

### First launch
```
splash → terms → consent → MODE CHOICE
                              ├─ Online  → home (analysis needs a connection)
                              └─ Offline → download screen → home
                                             ├─ complete   → on-device analysis
                                             └─ incomplete → offer Online, or resume
```

### Capture, by mode
```
Mode A: photo → upload → server inference → result  (needs connection)
Mode B: photo → on-device inference → result        (works offline)
both:   result → SQLite (pending_sync=1) → sync queue → server
```

### Download, interrupted
```
start → range GET per file → progress
   ├─ connection drops → keep the partial file, mark resumable
   ├─ app killed       → resume from the byte count on next open
   └─ checksum fails   → discard that file and re-fetch it alone
```

---

## 3) What the VPS will need

Recorded here so it is not discovered on deploy day.

- PHP 8.2+, Composer, a web server, a database — the Laravel app as it stands
- **~210 MB of static model files**, served with Range support
- **Python 3.10+ with `tflite-runtime` + FastAPI** for Mode A (F5)
- HTTPS. The app pins `API_BASE_URL` at build time; a plain-HTTP host would need
  cleartext permitted on Android, which is not acceptable for clinical data
- Enough disk for uploaded wound images if F5 stores them (it does not have to)

Full deploy notes are written at the end of the phase, once the parts exist.

---

## 4) Open questions for the owner

1. **Where do the model files live?** Same VPS as the app, or object storage / CDN? At
   208 MB per Offline install, egress is a real cost once the cohort grows.
2. **Does Mode A store the uploaded image?** It is not needed to return a result. Storing
   it means wound photographs at rest on the server, which is a consent and retention
   question, not a technical one.
3. **What happens on a metered connection?** Proposal: ask before starting a 208 MB
   download, never start silently.

---

## Progress log

_(appended as each feature lands)_

## What F3 cost, and what it bought

The downloader took four rounds of device testing, not one, because three
defects only appeared against a real server and a real 175 MB file. Recording
them because each is a trap worth not falling into twice.

**Pause did not pause.** Cancelling a dio `CancelToken` aborts a request that
is still pending; it does not stop a response whose stream is already being
consumed. A paused download quietly kept spending the participant's data. The
byte loop now checks a stop flag directly.

**A short file was treated as a corrupt file.** The hash was verified without
first checking the length, so a connection that ended early — a proxy giving
up, a server tiring — condemned every byte it had delivered. On the device this
discarded 168 MB of perfectly good data. Length is now checked first, and a
short file is resumed rather than deleted.

**An HTML error page was written into the middle of a model.** The real cause
of the checksums that would not verify: the server answered mid-transfer with
`<!DOCTYPE html>`, and the downloader appended it as if it were model bytes,
landing markup 124 MB into the file. The result was a file of exactly the right
length that could never verify — every size check passed. Responses are now
checked for shape (Content-Range start, Content-Length, content type) before a
single byte is written.

The last one has a deployment consequence: **`php artisan serve` cannot serve
these files.** It is single-threaded and gave up partway through every attempt.
Against a threaded, Range-capable server the same build downloaded all 208 MB
byte-identical on the first try. In production nginx must serve the model files
directly — see the deployment notes.

---

## F5 — server-side analysis (online mode)

Status: **built and working end to end**, with one clinical decision outstanding.

Built:
- `inference/pipeline.py` in the web repo — the on-device pipeline ported to
  Python, because PHP has no TFLite runtime.
- `inference/server.py` — a FastAPI sidecar on loopback. It runs models and
  authenticates nobody; Laravel decides who may ask.
- `POST /api/v1/analyse` — authenticated, rate limited, validates the image
  before it reaches the sidecar. Verified: 401 unauthenticated, correct result
  authenticated, non-images rejected.
- `RemoteAnalysisService` + `AiService` routing — online mode analyses on the
  server, falling back to local models only while they still exist on the phone.

### What the parity work found

Two real wound photographs did in one run what a synthetic fixture never did.

**The pipelines are now matched to the limit of the image decoders.** Getting
there took two corrections. `img.copyResize` defaults to *nearest*, not linear,
which cost 7.5% on wound area. And `Interpolation.cubic` is Catmull-Rom
(a = -0.5) where OpenCV's `INTER_CUBIC` is a = -0.75 — on the 480→224 downscale
CLIP needs, that moved a callus probability from 0.53 to 0.72. `pipeline.py` now
reproduces package:image's exact resize, including its edge-handling quirks.
Residual after the resize equals the residual from JPEG decoding alone
(~0.2 of 255 per pixel), so the port adds nothing further.

**Exact numeric parity is not achievable.** `package:image` decodes JPEG in pure
Dart with different rounding than libjpeg. That 0.08% input difference is
amplified by the tissue head: necrosis on 200003 reads 0.327 on the device and
0.493 on the server. The model is simply not reproducible across platforms at
fine granularity, and no amount of matching the arithmetic changes that.

**So label stability had to be engineered, not assumed.** The original rule
named the single highest-scoring tissue. On 200029 three classes clear their
thresholds and the top two sit 0.013 apart, so the same photograph came out
**Necrosis on the device and Callus on the server** — dead tissue needing
debridement, versus thickened skin. The rule is now: report the most clinically
serious class that clears its threshold. That cannot flip on ranking noise.

### Settled — the clinical question that was open here

The severity rule changed 200003 from **Granulation** to **Callus**, because
callus scrapes over its 0.45 threshold at 0.53 while granulation sits at 0.96,
and callus outranks granulation in the severity order. For a visibly granulating
wound that is arguably the wrong headline. `necrosis > slough > callus` is
defensible; `callus > granulation` is the questionable link, and it is not a
call to make without a clinician.

Options: drop callus below granulation; or show every tissue present rather than
one headline, which is the most truthful and removes the ranking question
entirely, at the cost of changing `tissueType` from one label to a set.

Also recorded: `200003 necrosis` diverges by 0.166 against a 0.107 margin to its
own threshold. It cannot change the headline today because necrosis is already
the top of the severity order, but on another wound a class could cross. The
parity suite prints this headroom on every run.

### Still to do
- F6 — remove the models from the APK. Blocked on the decision above only in the
  sense that it should not land while anything about the analysis path is in
  flux; technically it is ready.

---

## Tissue findings — from one label to the whole answer

Done, in both codebases. Replaces `tissueType: String` with
`tissueFindings: List<TissueFinding>`, where each finding carries `type`,
`probability`, `isPresent` and `thresholdUsed`.

**Why.** The head is multi-label: a wound bed holds several tissue types at
once, and each class has its own tuned threshold. Reporting one winner threw
away most of the answer and made the label turn on hundredths — on 200029 the
phone said Necrosis and the server said Callus for the same photograph, because
the two sat 0.013 apart and the platforms disagree by more than that.

**Where it lives now**

| | |
|---|---|
| App model | `viewmodel/tissue_finding.dart`, `analysis_result.dart` |
| App storage | `wounds.tissueFindings` (JSON), schema **v17** |
| Sync | `tissue_json = { label, findings[] }` |
| App UI | headline + full breakdown on the result screen |
| Server model | `TissueFinding` in `inference/pipeline.py` |
| Server API | `tissue_findings[]` in `POST /api/v1/analyse` |
| Server storage | `wound_scans.tissue_json` — already a JSON column, and always
  documented as holding per-class probabilities; it had only ever received the
  headline |

**Back-compat.** `primaryTissueType` derives the headline from the findings, and
`tissueType` still returns it, so history, exports and the dashboard are
untouched. A record written before v17 has no findings and falls back to its
stored label rather than reading "Unknown". Nothing is backfilled: the per-class
probabilities were never stored and cannot be invented from a label.

**Severity order changed.** Now `necrosis > slough > granulation > callus >
epithelial`. Callus previously outranked granulation, which headlined a visibly
granulating wound (200003) as "Callus" because callus scraped over its 0.45
threshold at 0.53 while granulation sat at 0.96. Both platforms now report
Granulation for that wound, with "Granulation, Callus" as the summary.

**What the presence flags buy.** A headline can be kept stable by choosing it
carefully; the *set* of tissues reported present cannot, because each is an
independent threshold decision a clinician will read. `test_presence_flags_match`
asserts every class lands on the same side of its threshold on both platforms.

### Caught on the way
- The v17 `ALTER TABLE` was unguarded and threw on any database without a
  `wounds` table, which fails the open — the app refusing to start over a column
  nothing had read yet. Now wrapped like every other ALTER here.
- Pre-existing and unrelated: `_backfillMissingUuids` passes a null `whereArgs`,
  which sqflite currently warns about and says it will throw in a later version.
  Not touched here; worth fixing before that lands.

### Next
- **F6 — remove the models from the APK.** Ready: the app prefers downloaded
  files, online mode needs no local models, and the analysis path is settled now
  that the tissue question is closed. ~220 MB to ~20 MB.
- Dashboard does not yet display tissue findings; `tissue_json` now receives
  them, so it is a presentation task whenever it is wanted.

---

## Open — the model download does not continue in the background

**Measured, not assumed.** Started a download, pressed Home, and sampled the
bytes on disk: **zero progress over 80 seconds** backgrounded. Bringing the app
forward resumed it immediately, from 168 MB of 199 MB.

### Why it stops — the earlier explanation here was wrong

It is *not* that Dart is suspended. The process stayed alive (same pid) and the
isolate kept working while backgrounded: it ran a WorkManager job, loaded notes,
and drained the sync queue. What actually happens is that **Android reclaimed the
Flutter engine**, and the download died with the isolate that was running it.
The log shows a full boot sequence — localisation init, Home load, model load
attempts — inside the same process, which is a new isolate, not a resumed one.

Confirmed this is genuine and not a development artefact:
`always_finish_activities` is off, and the emulator had 300 MB free of 4 GB.
Memory pressure is the cause, which means **a cheap phone will do this more
often, not less** — and cheap phones are the ones this app is for.

What saves it is F3. The `.part` survives, the splash gate routes an unfinished
offline install back into the downloader, and `fromSetup: true` starts it again
automatically. So the participant loses time, not bytes, and does not have to do
anything except reopen the app.

### iOS is not currently buildable here — see `IOS_TRACKER.md`

Worth knowing before anyone plans around it: **iOS has never been built in this
repo.** No `Podfile.lock`, no `build/ios`, and development is on Windows, where
it cannot be compiled at all. The iOS half of this problem is real but currently
theoretical, and it cannot be tested until there is a Mac in the picture.

That matters for the choice below, because the main thing
`background_downloader` buys over an Android foreground service is iOS.

### What it would take

1. **Android foreground service, keeping the Dart downloader.** Recommended
   first step. A foreground service tells the OS this is user-visible ongoing
   work, which is what stops the engine being reclaimed. It solves the platform
   that is actually in use, changes nothing about the transfer loop, and keeps
   all eleven `model_download_test` cases — they drive the real Dart loop against
   a local HTTP server, which is why the pause, truncation, error-page and
   checksum defects were caught at all.

   Note the subtlety: a foreground service keeps the *process* near the top of
   the LRU, but the engine is owned by the Activity. Surviving reliably means a
   cached `FlutterEngine` that outlives the Activity, which is the part worth
   prototyping before committing.

2. **`background_downloader` (9.5.6, resolves cleanly).** Wraps `URLSession`
   background transfers on iOS and a foreground service on Android, and supports
   Range resumption. It solves both platforms — but the transfer happens in
   native code, so `flutter test` cannot exercise it. Verification of the most
   safety-critical path in the app would drop to manual device testing, and the
   four guards found by device testing (stop-flag pause, length-before-hash,
   response-shape validation, `RandomAccessFile` writes) would move into someone
   else's code or disappear. The sha256 check would remain as the final arbiter.

   Reasonable once iOS is real. Paying that price now, for a platform that
   cannot be built, is not.

3. **Leave it.** Defensible for a pilot: nothing is lost, only time, and the
   resume is automatic. It should be a decision rather than an oversight.

Whichever is chosen: Android needs a `dataSync` foreground service type with a
user-visible notification — Play policy requires one for a long download — and
iOS would need the background transfer entitlement and an `AppDelegate`
completion handler.

**Verify on a real device, not a simulator.** The simulator does not enforce
suspension the way a phone does.

---

## Choosing an existing photo to analyse ✅

The capture screen now offers picking a photo from the gallery alongside taking
one. Wounds are often photographed by someone else — a district nurse, a family
member holding the foot — or during a dressing change when the phone was not to
hand. Requiring a live capture meant those never got analysed, or got
re-photographed off a screen, which is worse.

The picked file goes through the same preview, calibration and analysis path as
a capture. `PreviewScreen` already copies it into app storage, so a gallery URI
that later disappears cannot strand a record. No `maxWidth` on the picker:
`image_picker` would resample before the analysis saw the file, and the
measurements come from those pixels.

Permissions were already in place — `NSPhotoLibraryUsageDescription` on iOS,
`READ_MEDIA_IMAGES` plus `READ_EXTERNAL_STORAGE` (maxSdk 32) on Android.

### Server-side photograph upload — built, then reverted

Uploading photographs to the server was built from a misreading of this request
and then backed out (`5dcb665`, reverted in `04573fa`).

Backed out rather than kept: it re-prompted every participant with a new consent
version and began retaining identifiable images, and it made a promise —
"withdrawal removes your photographs" — with no retention or withdrawal
mechanism behind it. That is a lot of weight for something nobody asked for.

It is in history if server-side photographs are wanted later. What it contained:
upload keyed on `local_uuid`, a private disk, streamed reads through an
authorising controller, `image_path` hidden in favour of `has_image`, images
travelling separately from record sync so a failed photo could not drive a batch
of measurements into backoff, and a 1600 px downscale in an isolate. What it did
**not** solve, and would need solving first: retention, and honouring a
withdrawal without hand-written SQL.
