# DiaFootCare — iOS tracker

What to do the day this repo opens on a MacBook.

**Nothing in this file has been run.** iOS cannot be built on Windows, so
everything below is split into two kinds of statement, and the difference
matters:

- **Verified** — read out of this repository. True today.
- **Expected** — what should happen on a Mac. Reasoned, not observed. Treat as a
  checklist to work through, not as fact.

_Written 2026-07-20, from a Windows machine._

---

## Verified: what state the iOS project is actually in

| | |
|---|---|
| Xcode workspace | present (default Flutter scaffolding) |
| `Podfile.lock` | **absent** — `pod install` has never been run |
| `build/ios` | **absent** — never compiled |
| Deployment target | **12.0** |
| Bundle identifier | **`com.example.daifootcareNew`** |
| Permission strings | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` — all three present |
| `UIBackgroundModes` | `remote-notification` only |

So the iOS side is untouched Flutter scaffolding plus a few Info.plist edits. It
has never been near a compiler.

### Two things that are wrong today

**The bundle identifier is still `com.example.daifootcareNew`.** A `com.example`
identifier cannot be registered on the Apple Developer portal or submitted to
TestFlight. It has to change before anything can be signed, and changing it later
means a new App Store record, so change it first.

**Firebase is gone from the app but not from the build config.** `pubspec.yaml`
and `lib/` contain no Firebase at all — it was removed when auth moved to
Laravel. What remains:

| Leftover | Where |
|---|---|
| `GoogleService-Info.plist` | `ios/Runner/` — **and committed to git** |
| `FirebaseAppDelegateProxyEnabled` | `ios/Runner/Info.plist` |
| `UIBackgroundModes: remote-notification` | `ios/Runner/Info.plist` |
| `google-services.json` | `android/app/` |
| `com.google.gms.google-services` plugin | `android/app/build.gradle.kts` |

The plist holds `API_KEY`, `PROJECT_ID`, `GCM_SENDER_ID` and `STORAGE_BUCKET`.
Firebase client keys are designed to ship inside apps and are not secret in the
way a server key is, so this is housekeeping rather than an incident — but they
identify a live project, for an integration nothing uses.

Deliberately **not** removed yet: the Android build currently works with the
plugin applied, and pulling it out is a build-config change worth doing when
someone can watch a build, not in the middle of a deployment. Do it on the Mac
alongside the iOS cleanup, and rebuild Android too.

---

## Expected: the order to do things in

### 1. Prerequisites

```bash
xcode-select --install
sudo gem install cocoapods          # or: brew install cocoapods
flutter doctor                       # must show a clean Xcode section
```

### 2. Clean out Firebase first

Before the first `pod install`, so it never gets baked into a Podfile.lock:

```bash
git rm ios/Runner/GoogleService-Info.plist
git rm android/app/google-services.json
```

Then remove from `ios/Runner/Info.plist`:
- the `FirebaseAppDelegateProxyEnabled` key
- `UIBackgroundModes` → `remote-notification`, **unless** push notifications are
  actually wanted on iOS. The app uses `flutter_local_notifications`, which
  schedules locally and needs no background mode. Nothing sends remote pushes.

And from `android/app/build.gradle.kts`, the
`id("com.google.gms.google-services")` plugin line. **Rebuild Android after
this** — it is the change most likely to break something that currently works.

### 3. Set a real bundle identifier

In Xcode, Runner → Signing & Capabilities, or search
`PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj`. Something
like `com.<yourorg>.diafootcare`. It must match what is registered on the Apple
Developer portal. Note there is a second entry for `RunnerTests` that also needs
updating.

### 4. Expect the deployment target to move

The project says **12.0**. `tflite_flutter`'s podspec asks for 11.0, so that one
is fine — but several other plugins here are newer than the target, and Flutter's
own iOS floor has risen. `pod install` will say which, by name and version.

When it does, raise the target in **both** places or they will disagree:
- `ios/Podfile` — the `platform :ios, '...'` line, currently **commented out**
- Xcode → Runner → General → Minimum Deployments

Then:

```bash
cd ios && pod install && cd ..
flutter build ios --release --no-codesign     # first honest smoke test
```

### 5. Plugins worth watching on the first build

Every one of these has native iOS code, and none has ever been compiled here:

| Plugin | Why it is worth a second look |
|---|---|
| `tflite_flutter` | Ships a TensorFlowLite framework. The most likely thing to fail on Apple Silicon vs simulator architectures. |
| `camera` | Needs the camera usage string (present) and a real device to test. |
| `image_picker` | Needs both photo-library strings (present). |
| `flutter_secure_storage` | Uses Keychain — needs a Keychain Sharing entitlement, and Keychain persists across reinstalls on iOS, which Android does not. Sessions may survive a delete-and-reinstall. |
| `workmanager` | The Android background sync path. **iOS equivalent is `BGTaskScheduler` and needs `UIBackgroundModes: processing` plus registered task identifiers.** Background sync will not work on iOS without this. |
| `flutter_local_notifications` | Needs explicit permission request on iOS. |
| `path_provider` | App-support directory maps differently; the model bundle lands somewhere iCloud may try to back up — see below. |

### 6. Things that behave differently on iOS and will need real decisions

**The 208 MB model bundle and iCloud.** On iOS, files in Application Support are
backed up to iCloud by default. Backing up 208 MB of models that can be
re-downloaded would eat a participant's iCloud quota for nothing. Set the
"do not back up" resource value on the models directory —
`NSURLIsExcludedFromBackupKey` — via a small platform channel or a package.
`ModelRepository.dir()` is the single place the path is decided.

**Background downloads.** The model download stops when the app leaves the
foreground. On Android this is because the OS reclaims the Flutter engine under
memory pressure (measured — see `PHASE3_TRACKER.md`). **On iOS it is worse and
structural**: the only mechanism Apple provides for a sustained background
transfer is `URLSession` with a background configuration, where the system
daemon does the transfer. That cannot be driven from Dart. This is the main
argument for the `background_downloader` package, and it only becomes worth its
cost once iOS is real — which is now.

**App Store review.** A health app that analyses wounds will attract scrutiny.
Expect questions about the medical disclaimer (the app has one in Terms), and be
ready to explain that it is a monitoring aid, not a diagnostic device.

### 7. What to actually test on a device

The Android equivalents of these all found real bugs, so they are not ceremony:

- [ ] First run: terms → consent → mode choice → download
- [ ] Download 208 MB, background the app mid-transfer, return — does it resume?
- [ ] Kill the app mid-download, relaunch — does the splash gate route back in?
- [ ] Analyse a wound offline; compare against the same photo on Android. The
      fixtures and expected numbers are in `integration_test/analysis_parity_test.dart`
- [ ] Analyse in online mode against the server
- [ ] Analyse with no models and no connection — the message must name both
      problems, not one
- [ ] Pick a photo from the library as well as taking one
- [ ] Arabic + RTL through the whole flow
- [ ] Delete and reinstall — check whether the Keychain kept the session

**Parity is the one that matters most.** The two platforms already disagree
slightly because `package:image` decodes JPEG differently from libjpeg; a third
platform is a third decoder. Run the parity fixtures on iOS and compare against
the recorded Android numbers before trusting any iOS measurement clinically.

---

## Open questions for whoever picks this up

1. **Is iOS in the study at all,** or is this future-proofing? It changes whether
   `background_downloader` is worth the rewrite described in `PHASE3_TRACKER.md`.
2. **Apple Developer account** — is there one? $99/year, and TestFlight needs it.
3. **Push notifications on iOS** — if not wanted, the `remote-notification`
   background mode should go with the rest of the Firebase leftovers.
