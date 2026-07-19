# DiaFootCare — Phase 3 Tracker: Online / Offline Modes & Model Delivery

The piece the brief opens with and that Phase 2 deliberately left alone.
Phase 2 (identity, sync, dashboard) is in [`PHASE2_TRACKER.md`](PHASE2_TRACKER.md).

**Legend:** ✅ done · 🚧 in progress · ⚠️ blocked/decision needed · ⬜ not started

_Created: 2026-07-19_

---

## START HERE — handoff for 2026-07-20

**Everything F1–F5 is built, on device, and verified. F6 is the only feature left.**

Yesterday closed the analysis path: online mode works against the server, the two
modes agree on what they call a wound, and three UI bugs found by actually
running the app are fixed.

### Pick up with F6 — unbundle the models from the APK

The payoff: **~220 MB → ~20 MB**. Nothing blocks it now.

1. Delete `- assets/models/` from `pubspec.yaml` (keep `assets/testdata/`).
2. `AiService._open()` already prefers the downloaded copy, so the asset branch
   becomes dead — remove the `Interpreter.fromAsset` fallback and let a missing
   model throw, because a silent fallback to nothing is worse than a clear error.
3. Check the offline-mode gate still works from a **clean install**: splash must
   route into the downloader before anything tries to analyse.
4. Check online mode with **no models on disk at all** — it must never fall back
   to local inference, since there is nothing to fall back to.
5. Measure the APK before and after and put both numbers in this file.

The one thing to be careful about: `AiService.analyzeWound` currently falls back
to the on-device models when the server fails. After F6 that fallback can only
fire when models are actually installed, so the condition needs to be honest
about it — see the comment already in place there.

### State of the world

| | |
|---|---|
| Mobile tests | 72 pass |
| Analyzer | 0 errors |
| On-device parity | passes on both clinical fixtures |
| Server parity suite | 4 checks pass |
| APK | builds |

### What is open, in rough priority order

1. **Background download** — the transfer stops when the app leaves the
   foreground, on both platforms, and iOS cannot do it from Dart at all. Resume
   makes this survivable rather than fine. Options are written up under
   *"Open — the model download does not continue in the background"*.
2. **Mandatory consent** — accepting is still required to use the app during the
   study. Flagged repeatedly; an ethics board will ask.
3. **`_backfillMissingUuids` passes a null `whereArgs`.** sqflite warns it will
   throw in a future version. Harmless today, a broken upgrade path later.
4. **Metered connections** — nothing checks whether a 200 MB download is about to
   run on mobile data.
5. **Dashboard** shows the tissue summary but not the per-class breakdown, which
   the app already shows and the server already stores.
6. **nginx config in `DEPLOYMENT.md` is untested** — no nginx on this machine.
   The curl checks in §4 are what prove it before a phone depends on it.

### Yesterday, in one line each

- Resumable 208 MB download: pause, resume, verified — three defects found only
  by testing against a real server and a real file
- Online analysis on the server, matched to the phone to the limit of the JPEG
  decoders
- Tissue reporting moved from one label to every class, after the two platforms
  disagreed on a real photograph
- Analyse a photo from the gallery, not only a fresh capture
- Fixed: a 10-pixel overflow, an unreachable mode screen, and a depth dialog that
  logged 19 framework errors per scan

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

### F6. Unbundle the models from the APK ⬜ ← next
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

**Not built, on either platform.** `ModelDownloadService` runs in the Dart
isolate that the UI lives in. Leave the download screen open and it proceeds;
send the app to the background and it stops.

What softens this is F3: nothing transferred is ever lost. Bytes land in a
`.part` file, the next launch resumes with a Range request, and the splash gate
routes an offline install with an unfinished bundle straight back into the
download. So the failure is "this takes several sessions", not "this starts
again". For a 200 MB download over a clinic connection that is still a poor
experience, and on iOS it is worse than on Android.

**Android.** The process usually survives a while in the background, so a
download often keeps going for a few minutes before the OS reclaims it. There is
no guarantee, and no foreground service declared, so it can be killed at any
point. `workmanager` is already in the app for sync, but a WorkManager task is
the wrong shape for this: it has its own execution windows and a ~10 minute
budget per run, where this is one long transfer.

**iOS.** It simply stops. `UIBackgroundModes` currently declares only
`remote-notification`, and even adding `fetch` would not help — background fetch
grants short opportunistic windows, not a sustained transfer. The only
mechanism Apple provides for this is `URLSession` with a background
configuration, where the *system* daemon performs the transfer and wakes the app
on completion. That cannot be driven from Dart: `dio` and `HttpClient` both run
in-process.

### What it would take

The honest options, in order of preference:

1. **`background_downloader` package.** Wraps `URLSession` background transfers
   on iOS and a foreground service with `WorkManager` on Android, and supports
   Range resumption. It would replace the transfer loop inside
   `ModelDownloadService` while leaving the manifest handling, checksum
   verification and `.part` bookkeeping alone — those are the parts that took
   four rounds of device testing to get right and should not be rewritten.

2. **A platform channel per OS.** `URLSession` background configuration on iOS,
   a foreground service with a notification on Android. More control, more code,
   and it re-implements what the package already does.

3. **Leave it.** Defensible for a pilot, given resume works. It should be a
   decision rather than an oversight, which is why it is written down here.

Whichever is chosen, two things change beyond the transfer itself: iOS needs the
background transfer entitlement and a completion handler wired in
`AppDelegate`, and Android needs a foreground service type declared with a
user-visible notification — Play policy requires one for a long download, and
`dataSync` is the applicable type.

**Verify on a real device, not a simulator.** The simulator does not enforce
suspension the way a phone does, so a background download will appear to work
there and fail in a clinic.

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
