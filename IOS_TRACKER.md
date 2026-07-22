# DiaFootCare — iOS tracker

What to do the day this repo opens on a MacBook.

**Nothing in this file has been run.** iOS cannot be built on Windows, so
everything below is split into two kinds of statement, and the difference
matters:

- **Verified** — read out of this repository. True today.
- **Expected** — what should happen on a Mac. Reasoned, not observed. Treat as a
  checklist to work through, not as fact.

_Written 2026-07-20, updated 2026-07-22, from a Windows machine._

---

## Verified: what state the iOS project is actually in

| | |
|---|---|
| Xcode workspace | present (default Flutter scaffolding) |
| `Podfile.lock` | **absent** — `pod install` has never been run |
| `build/ios` | **absent** — never compiled |
| Deployment target | **12.0** |
| Bundle identifier | **`tech.diafootcare.app`** (fixed 2026-07-22) |
| Permission strings | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` — all three present |
| `UIBackgroundModes` | **absent** — the Firebase push mode was removed |

So the iOS side is untouched Flutter scaffolding plus a few Info.plist edits. It
has never been near a compiler.

### Settled: identifier and Firebase

Both were wrong and are now fixed — verified by building and running on a
device, though still not by compiling for iOS.

**Bundle identifier: `tech.diafootcare.app`** on both platforms.

It was `com.example.daifootcareNew` on iOS and `com.example.daifootcare_new` on
Android. Google Play rejects `com.example.*` outright and Apple cannot register
it, so neither could have shipped. The new value is the reverse of the domain
the project owns, which is what both stores want to see, and it corrects a
transposition the old identifiers carried — the domain is **dia**footcare.tech
but the packages said **dai**footcare.

This had to happen before anything is signed. The identifier is permanent once
submitted, and on Android a changed `applicationId` is a *different app*:
existing installs do not upgrade, they sit alongside, and the local SQLite goes
with them. For an offline-first app that database can hold unsynced scans.

Tests target is `tech.diafootcare.app.RunnerTests`.

**Firebase config is gone.** `GoogleService-Info.plist` (committed to this repo
with an API key and project id), `android/app/google-services.json`, the
`com.google.gms.google-services` gradle plugin, `FirebaseAppDelegateProxyEnabled`
and the `remote-notification` background mode. Firebase left `pubspec.yaml` and
`lib/` when auth moved to Laravel; only the platform config survived.

`UIBackgroundModes` is now **absent entirely**. Notifications are scheduled
locally by `flutter_local_notifications`; nothing sends remote pushes. If push
is ever wanted, add the mode back *and* the capability in Xcode — but claiming
it while unused is a question at review for no benefit.

## What still needs an Apple account

- **Apple Developer Program**: $99/year. Required for TestFlight and the store.
- Register `tech.diafootcare.app` as an App ID in the developer portal before
  the first signed build.
- The Apple account holder becomes the legal publisher of a health app. If a
  university or hospital owns the study, the account should probably be theirs,
  not an individual's — and that decision is easier before an App ID exists.

## Expected: the order to do things in

### 1. Prerequisites

```bash
xcode-select --install
sudo gem install cocoapods          # or: brew install cocoapods
flutter doctor                       # must show a clean Xcode section
```

### 2 and 3. Firebase cleanup and the bundle identifier — already done

Both were completed on 2026-07-22 and verified by building and running on
Android. See "Settled: identifier and Firebase" above. Nothing to redo.

### 2. Expect the deployment target to move

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

### 3. Plugins worth watching on the first build

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

### 4. Things that behave differently on iOS and will need real decisions

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

### 5. What to actually test on a device

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
