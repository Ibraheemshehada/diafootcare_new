# DiaFootCare — Feature Tracker

Living checklist of what's built and what remains, based on the "Introducing
DiaFootCare" feature slide + the clinical-study requirements (engagement,
glucose logs, medication adherence, patient-reported outcomes / QoL, self-care
behavior, pharmacist & education support).

**Legend:** ✅ done · 🚧 in progress · ⚠️ partial · ⬜ not started

_Last updated: 2026-07-08_

---

## 🔖 RESUME HERE — session handoff (2026-07-09)

**State:** `flutter analyze lib test` = **0 errors**. `flutter test` = **23/23 pass** (12 SUS + 11 trend). The old stock "Counter increments" template (`test/widget_test.dart`) that always failed has been deleted and replaced with `test/sus_test.dart`.

This session: **accessibility push** (contrast, text scaling, dialogs, read-aloud) + **Daily/Weekly/Monthly healing-trend chart**. **Follow-up (same handoff): locked the app to portrait** and restored the emulator DB.

> ⚠️ **The app MUST pass the 11-criterion Accessibility Check** (see §11). Now **9/11 green**. Remaining: TalkBack sweep (#5/#11) and multi-device coverage (#10). Orientation is resolved (portrait-locked).

### ⬜ TODO — next session
1. **A11y #5/#11 — TalkBack.** Still never run under a real screen reader. Enable TalkBack, sweep Home → Glucose → Self-Care → SUS. *Tip:* Flutter's semantics tree is not exposed to `uiautomator dump` until an accessibility service is active — enable TalkBack first, then `uiautomator dump` actually shows the nodes, which makes this verifiable.
2. **A11y #10 — device coverage.** Only Pixel 4 / API 36 tested. Try a small phone and a tablet (both portrait now). Large-font already verified at 2.0×.
3. **🩹 Wound measurements are all `0.0 × 0.0 cm` — root cause found, fix open.** The 3 real rows carry Model 2/3 outputs (`tissueType='Callus'`, `infection='Present'`) but `length=width=0`. In `ai_service.dart`, `length`/`width` are only set inside `if (_model1Loaded)`; the CLIP-backbone heads (Models 2/3) loaded but **Model 1 (segmentation) did not**, so measurements stayed 0 and were saved silently. Two things to do: (a) get device model-load logs to see *why* `model1.tflite` failed to load while the others succeeded; (b) **defensive fix** — when `isFromModel` but `length*width == 0`, don't silently persist a 0×0 wound (block the save with a clear message, or mark it "not measured" so it never pollutes the trend baseline). This is the highest-value functional bug: the healing trend can never plot for real users until capture writes real cm.
4. **Consider raising body text 12sp → 14sp** for elderly diabetics (minimum is 12sp everywhere now).
5. **`dart format` divergence.** The repo is *not* dart-formatted (89 of 117 files would change). I formatted the 13 files touched by the fixed-height refactor, so their diffs are larger than the semantic change. Either format the whole repo once, or don't format at all — pick one.
6. **Voice assistant polish (optional).** `SpeakButton` now sits on the education article, the SUS declaration, and the self-care rotating tip. Consider a global on/off toggle in Profile.

### What happened this session
0. **🔄 Orientation locked to portrait — device-verified.** Landscape was broken app-wide: the Home hero card alone filled the entire short viewport, leaving the services grid unreachable (every screen — hero, 2-col grid, charts, surveys, wound-capture camera — assumes a tall viewport). Decision (with the user): lock portrait rather than maintain a second layout. Pinned in **three** places — `AndroidManifest.xml` (`android:screenOrientation="portrait"`, stops the activity being recreated on rotation), `main.dart` (`SystemChrome.setPreferredOrientations([portraitUp])`, cross-platform + foldables), and `ios/Runner/Info.plist` (portrait-only for iphone + ipad). **Verified:** with `user_rotation 1` (device physically landscape) the app screenshot came back **1080×2280 (portrait)** and rendered correctly. **Emulator DB restored** to the original 3 rows (my 9 seeded trend rows removed) via the `%LOCALAPPDATA%\Temp\diafoot_backup_2026-07-08.db` base64 pipe.
1. **SnackBars → dialogs: complete.** `grep -rl showSnackBar lib/` → **none**. All 21 remaining calls in 11 files converted to `showAppSuccess` / `showAppError`.
   - Found `set_password_viewmodel.dart` rendering **raw keys** (`Text('password_updated_success')` — no `.tr()`, and the keys didn't exist). Fixed + keys added.
   - `showAppError` now logs **every** user-facing error, including validation errors — those are exactly what a usability study's error count is meant to capture. (It previously only logged when a `technicalDetail` was passed, so the study's error count read 0.)
2. **A11y #2 — contrast: measured, not guessed.** Wrote relative-luminance math and checked every semantic colour. Added `lib/core/theme/app_colors.dart` (theme-aware `success/danger/warning/caution/streak`). **All 16 text pairs + 3 icon pairs now pass** (was: `warning` 2.04:1, `caution` 2.16:1, `Colors.red` 3.68:1, hero white-on-blue 3.83:1 — all FAIL).
   - **Hero card bug (device-measured):** `whats_new_card.dart` tinted its decorative SVGs with `BlendMode.srcATop` at 1% white, so the art's own `#AED1FF` fills stayed opaque. Sampled the real screenshot: **white title on that art = 1.57:1**. Same `srcATop → srcIn` bug as the service tiles. Fixed; re-measured on device: **4.86:1 worst pixel**.
   - Fixed `Colors.red` logout button (**3.68 → 5.62:1**, confirmed by sampling `#C62828` from a device screenshot), the SUS score band colours, the reminders empty-state icon, and the `ai_result_screen` banners (whose `Colors.red[900]` text was unreadable on a dark card).
   - `ai_result_screen` also had **two hardcoded English strings** shown to users → localized (`ai_demo_result_banner`, `ai_not_calibrated_banner`).
3. **A11y #6 — text scaling: verified at `font_scale 2.0`.** Found and fixed **13** `SizedBox(height: X.h, child: SomeButton)` wrappers → `ConstrainedBox(minHeight:)` (an exact height *clips* the label; a min height keeps the 48dp target and lets it grow). The logout button's label was visibly sliced in half.
   - **The real overflow was the Home services grid:** `childAspectRatio: 1.1` pinned the cell height → *"BOTTOM OVERFLOWED BY 54 PIXELS"*. Now `mainAxisExtent` derives from width **and scales with `MediaQuery.textScalerOf`** (clamped 1.0–2.0); tile title/subtitle bounded at 2 lines each.
   - Verified empirically: `adb shell settings put system font_scale 2.0` → **0 `overflowed by` events in logcat**, screenshots clean. (Earlier my `maxLines: 2 → 3` change had *made it worse*.)
4. **Healing-trend chart: Daily / Weekly / Monthly** (was monthly-only).
   - Extracted the bucketing into a **pure, testable** `computeTrend(entries, range, {now})` in `history_viewmodel.dart`; added `TrendRange` + `TrendSeries`. **11 unit tests** in `test/trend_test.dart` cover daily/weekly/monthly bucketing, same-bucket averaging, Monday week starts, year rollover, DST-safe calendar step-back, negative (wound regrowth) values, and the zero-baseline empty case.
   - **Bug fixed:** a wound last measured *before* the visible window used to plot as 0 % improvement. The carry-forward is now seeded from the most recent prior measurement.
   - **Dead code removed:** the chart's `isRtl` check compared Flutter's `TextDirection` against **intl's** `TextDirection.RTL` (which `easy_localization` re-exports) — `unrelated_type_equality_checks`, always `false`. The axis has always run oldest → newest, left → right; that branch never executed.
   - New `_RangeSelector` (3 `ChoiceChip`s, `MaterialTapTargetSize.padded` → 48dp, `selected` semantics). Kept visible in the empty state so the range is still changeable. Key `weekly` added (en/ar).
5. **Read-aloud extended** to the self-care rotating tip.

### Verification evidence (this session)
- Contrast: sampled real device screenshots with Pillow — hero art `#206FCD` → **4.86:1**, logout glyph `#C62828` → **5.62:1**.
- Text scaling: `font_scale 2.0` + `logcat | grep -c "overflowed by"` → **0** (was 3 visible overflow banners).
- Trend logic: `flutter test test/trend_test.dart` → **11/11 pass**.
- Trend UI: seeded a shrinking wound (20.0 → 2.34 cm²) and rendered the monthly curve rising to **+88 %**, chips يوميًا / أسبوعي / شهري all present.

### Commits on origin/main (previous push cycle)
`6a4f39a` §1+§2 · `64c312d` §3+§4+§6 · `54cfe29` §5 · `ed4ff02` §7 · `8ac4fb4` §8 · `bd7f4b2` QA fixes · `6e6806c` tile icons+bg art · `827eea5` tile bg blend-mode fix (srcIn) · `402667d` SUS + participant declaration · `69eae4b` usability instrumentation + a11y pass.

**DB:** schema is **v12** (…v10 analytics_events, v11 sus_responses, v12 `analytics_events.value`). Existing installs auto-migrate via `onUpgrade`; no wipe needed.

**Build/run gotchas (so we don't rediscover):**
- Run: `flutter run -d emulator-5554`. adb isn't on PATH → use `$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe` (set `export MSYS_NO_PATHCONV=1` in Git Bash, or prefix device paths with `//`, e.g. `//sdcard/u.xml`).
- **Writing a DB into the app sandbox:** `run-as` **cannot read `/data/local/tmp`** (SELinux). Pipe it instead:
  `base64 file.db > f.b64; adb shell "run-as <pkg> sh -c 'base64 -d > databases/diafoot.db'" < f.b64` (then delete `-wal`/`-shm`).
- **Gradle daemon OOM** ("daemon has disappeared") — was `-Xmx8G`; now `-Xmx3G` in `gradle.properties`. Incremental builds ~25–40 s.
- Emulator (Pixel_4_API_36) is **laggy — taps often miss**; screenshot after each tap and re-tap. It also **auto-rotated to landscape** on its own once (see TODO #1); pin with `settings put system accelerometer_rotation 0`.
- The emulator **died mid-session** once; `adb kill-server && adb start-server`, then relaunch: `emulator -avd Pixel_4_API_36 -no-snapshot-load`.
- Models are in **Git LFS** (clip_backbone is 167 MB). `git lfs checkout` restores real files if the tree shows 134-byte pointers.
- Login is via **Guest** (`is_guest` pref) — the app opens straight to Home as "Guest".

---

## 0. Already implemented (baseline)

- ✅ Wound capture (camera + gallery) with capture tips
- ✅ Reference-object scale calibration (px/cm)
- ✅ **Manual wound depth entry** (probe measurement) — *added this session*
- ✅ AI analysis: Model 1 (segmentation/measurements), Model 2 (tissue type), Model 3 (infection & ischaemia → DFU risk badge)
- ✅ Wound history + healing-progress screen (area/size trend)
- ✅ Reminders: once / daily / weekly, with local notifications (vibrate + sound, exact alarms)
- ✅ Daily notes
- ✅ Weekly progress % on home
- ✅ Data export (PDF / CSV / Excel) via share sheet
- ✅ Auth: Firebase login, sign-up, **guest login** *(this session)*
- ✅ Localization EN/AR (RTL), dark mode, senior-mode tips
- ✅ Profile, settings, terms

---

## 1. Glucose Monitoring 🩸  🚧 (blocked by a runtime crash — see Known Issues)
Study needs glucose logs as a primary data source.
- ✅ DB table + repository for glucose readings (value mg/dL, timestamp, tag: fasting/post-meal/random) — `glucose_readings`, DB v5
- ✅ "Add glucose reading" sheet (value + fasting/after-meal/random)
- ✅ Glucose history list + summary card (latest + status color + 7-reading avg)
- ✅ Home services tile "Blood Glucose" (سكر الدم) with droplet icon
- ✅ Include real glucose data in export (CSV/PDF/Excel — replaced the stub)
- ✅ EN/AR localization + clinical status thresholds (low/normal/elevated/high)
- ⚠️ **Blocked:** adding a reading crashes the screen with a framework assert. Data DOES persist (renders correctly after relaunch), but the in-session render throws. See Known Issue #1 below. Feature is NOT shippable until this is fixed.
- ✅ Home dashboard shows the *latest* reading value + status on the "What's New Today?" card (taps through to the Glucose screen)

## 2. Medication Management 💊  🚧 (built — needs QA on device)
- ✅ DB tables `medications` + `medication_logs` (DB v6), repository
- ✅ Medication list screen (add via dialog, swipe-to-delete)
- ✅ Daily dose log: tap per-dose chips to mark taken/untaken (per medication, `timesPerDay`)
- ✅ **Today's adherence %** ring (taken vs scheduled doses) on the screen
- ✅ Real medication data + **7-day adherence %** in export (CSV/PDF/Excel)
- ✅ EN/AR localization, home "Medications" tile (pill icon)
- ⬜ Link medication *reminders* (the existing reminder "medication" type) to specific tracked meds — deferred
- ⬜ QA on device (uses the same dialog/widget-class pattern as the glucose fix, so should be safe — verify)

## 3. Self-Care Behavior & Daily Check-ins 🚧 (built — needs QA on device)
"Daily foot inspection, medication schedule, wound monitoring adherence %."
- ✅ Daily self-care checklist — 5 fixed tasks: inspect feet, wash & dry, moisturize, footwear, wound check (`self_care_task.dart`)
- ✅ Persist per-day completion (DB table `self_care_logs`, DB v7); today's completion % ring
- ✅ Streak indicator (consecutive fully-completed days) shown on the self-care screen
- ✅ Include self-care 7-day adherence % in export (CSV/PDF/Excel + a dedicated toggle)
- ✅ Home "Daily Self-Care" tile (`/selfcare`) + `SelfCareViewModel` provider + route
- ✅ **Do's & Don'ts advice** — 8 "Do" + 6 "Don't" diabetic foot-care tips (transcribed from the clinic infographics), EN/AR. Surfaced as a **rotating "Self-care tip" card** (random Do/Don't picked per app launch, + a shuffle button); the full green/red list is tucked behind a collapsed "View all" expander to keep the screen uncluttered
- ✅ EN/AR localization (task titles + descriptions + advice)
- ✅ **Home dashboard card** — self-care summary on Home (under the "What's New" hero): today's completion bar + 🔥 streak + rotating Do/Don't tip, taps through to the Self-Care screen (`SelfCareTipCard`, RTL-aware)
- ⬜ QA on device (tap tasks, verify ring/streak update live + persistence across relaunch)

## 4. Dashboard — Key Health Indicators 📊  ✅ (built — needs QA on device)
- ✅ Surface **DFU status** on the home "What's New Today?" hero — latest wound's risk (Normal/Infection/Impaired Blood Flow/High Risk), risk-colored icon, taps → wound history. Derived from the newest wound's infection/ischaemia via the same rule as the AI result screen (`HomeViewModel.dfuBadge` + `_dfuStatus`)
- ✅ Glucose tile (from §1) — latest reading + status on the hero card
- ✅ Self-care summary card on Home (from §3) — today's completion bar + **🔥 streak** + rotating Do/Don't tip, taps → Self-Care (`SelfCareTipCard`)
- ✅ Next appointment tile (from §6) — soonest upcoming appointment on the hero, taps → Appointments

## 5. Patient-Reported Outcomes (QoL) 🧠  🚧 (built — needs QA on device)
"Standardized scales: pain, mobility, emotional impact."
- ✅ Periodic **QoL check-in** — 3 items (foot/wound pain, mobility difficulty, emotional impact) on 0–10 sliders (higher = worse), stored per date (DB v9 `qol_entries`)
- ✅ Latest-scores summary card + **burden trend chart** (fl_chart, fixed 0–10 axis) + history list with swipe-to-delete
- ✅ **Satisfaction survey** (1–5 Likert): ease of use, usefulness, willingness to continue (DB v9 `satisfaction_entries`)
- ✅ QoL + satisfaction in export (CSV/PDF/Excel + a "Well-being" toggle)
- ✅ Home "My Well-being" service tile (`/wellbeing`) + `WellbeingViewModel` provider + route
- ✅ EN/AR localization
- ⬜ QA on device (add a check-in → summary/trend/history update; take the survey; delete a check-in; export)

## 6. Appointments & Alerts 📅  🚧 (built — needs QA on device)
- ✅ **Dedicated Appointments feature** (DB table `appointments`, DB v8) — a clean list, not overloaded onto reminders
- ✅ Add appointment (full-page form): title, date, time, location, notes, and a **reminder lead** (none / at time / 1 hour before / 1 day before)
- ✅ **Upcoming** + **Past** sections with a calendar-style date block and swipe-to-delete
- ✅ One-off **local notification** at the chosen lead time — scheduled via `scheduleOneOff` with a **per-appointment id**, so it never touches the reminders feature's `cancelAll`
- ✅ Home "next appointment" hero row + "Appointments" service tile (`/appointments`)
- ✅ Appointments section in export (CSV/PDF/Excel + toggle)
- ✅ EN/AR localization
- ⬜ QA on device (add appointment → shows under Upcoming; notification fires at the lead time; once the time passes it moves to Past)

## 7. Education & Pharmacist Support 📚  🚧 (built — needs QA on device)
- ✅ **Educational content module** — 5 curated foot-care guides (daily foot care, footwear, blood sugar & feet, warning signs, wound/dressing care); each opens an article with an intro + bulleted steps + a "not a substitute for your care team" disclaimer
- ✅ **Pharmacist-verified tips** section (4 tips) with a green "Pharmacist-verified" badge
- ✅ **"Ask your pharmacist"** card with suggested questions (static entry point; no external launcher dependency)
- ✅ Home "Education" service tile (`/education`) + article-detail route — static content, so no DB/provider needed
- ✅ EN/AR localization (all article bodies)
- ⬜ QA on device (open Education → tap a guide → article renders; check RTL + dark mode)

## 8. Engagement / Usage Analytics 📈  🚧 (built — needs QA on device)
Study measures usage frequency, feature utilization, retention.
- ✅ **Local event logging** (DB v10 `analytics_events`) — `app_open` on each launch + `feature_open` on every Home service-tile tap. Local-only; nothing leaves the device (`AnalyticsService`, fire-and-forget)
- ✅ **Usage summary** screen "My Activity" (opened from Profile) — active days, day streak, app opens, first-used / last-active, and a feature-utilization bar list
- ✅ **Engagement summary in export** (CSV/PDF/Excel + a "Usage & Engagement" toggle) — the usage metrics + per-feature open counts
- ✅ EN/AR localization
- ⬜ QA on device (open a few features → My Activity shows counts; export with "Usage & Engagement" ticked)

---

## ⚠️ Known Issues (to investigate)

### Issue #1 — Glucose screen crashes after adding a reading — ✅ RESOLVED (device-verified 2026-07-07)
**Confirmed fixed on device:** added a reading (value 120) → NO red error screen; the summary card, 7-reading average, and history list all updated live in-session. The `AlertDialog` rewrite (below) resolved the `_dependents.isEmpty` assert.

**Update:** Read the real assert — it's `InheritedElement.debugDeactivated()` asserting `_dependents.isEmpty` (an InheritedElement/FocusScope deactivated while a dependent — the autofocused TextField in the modal sheet — was still attached). Rewrote `glucose_screen.dart` to the proven reminders pattern:
- Replaced `showModalBottomSheet` + autofocus TextField with a `showDialog`/`AlertDialog` (`_AddGlucoseDialog`, a `StatefulWidget` that disposes its own controller).
- The dialog **returns** the input; the screen calls `vm.add()` **after** `await showDialog` completes (mutation happens after the route is gone — same as the reminders add flow).
- `FocusScope.of(context).unfocus()` before popping the dialog.
- Extracted `_GlucoseSummaryCard` and `GlucoseTile` into real widget classes (keyed), reverted body to `ListView(children:[...])`.
Pending on-device QA to confirm the assert is gone.

**Original report (for reference):**
- **Symptom:** After saving a glucose reading (and now also sometimes when just opening the Glucose screen with existing readings), the screen is replaced by the app's red ErrorWidget showing:
  `'package:flutter/src/widgets/framework.dart': Failed assertion: line 6171 pos 14: '_dependents.isEmpty': is not true.`
- **Important:** the reading IS saved to the DB — after a full app relaunch the Glucose screen renders the saved readings correctly (summary card + list + correct status colors). So it's a **render/element-lifecycle bug, not a data bug.**
- **Environment:** Flutter 3.35.7 stable, debug build, Pixel_4_API_36 emulator. `flutter analyze` = 0 errors.
- **What I already tried (did NOT fix it):**
  1. Set `mainAxisSize: MainAxisSize.min` on the Columns inside Rows (removed an earlier "RenderFlex overflowed by Infinity" symptom, but the assert remained).
  2. Reordered the save handler to `Navigator.pop(ctx)` **before** `vm.add(...)` (mutate after the sheet route is gone).
  3. Restructured the body from one `ListView(children:[header, ...tiles])` into a fixed header `Column` + `Expanded(ListView.builder(...))` so the mutating keyed list isn't reconciled against the unkeyed header. **After this, it started asserting on open too** — so this may have made it worse or the real cause is elsewhere.
- **Next things to try:**
  1. **Read the actual assertion** — open `$FLUTTER_ROOT/packages/flutter/lib/src/widgets/framework.dart` line ~6171 to see exactly which method asserts `_dependents.isEmpty` (likely `InheritedElement.unmount()` or `Element.deactivate()`), then trace which InheritedWidget is being torn down with a live dependent.
  2. Temporarily **remove `context.watch<GlucoseViewModel>()`** from `GlucoseScreen.build` and instead wrap only the list in a `Consumer<GlucoseViewModel>` / `Selector` — the crash strongly correlates with the whole StatelessWidget (which is a Provider dependent) rebuilding while a route/overlay tears down.
  3. Convert the add-reading `showModalBottomSheet` to `showDialog`+`AlertDialog` — that pattern already works elsewhere (wound-depth dialog).
  4. Compare against the **reminders** feature which does add/delete via a provider with no such crash: it uses a full-page `Navigator.push` for adding (not a modal sheet) and `context.watch` on a plain `ListView(children: map(...))`.
  5. Try removing the `Dismissible` from the reading tile to rule it out.
- **Files:** `lib/features/glucose/screens/glucose_screen.dart` (UI + `_showAddSheet`), `lib/features/glucose/viewmodel/glucose_viewmodel.dart`, provider registered in `lib/app.dart`.

## 9. Post-test questionnaire (SUS) 🧪  ✅ (device-verified)
Required by the study's usability protocol (SUS + satisfaction ratings).
- ✅ **10-item System Usability Scale**, statements verbatim, EN/AR (DB v11 `sus_responses`)
- ✅ **Official scoring**: odd items `r−1`, even items `5−r`, ×2.5 → 0–100. **Verified against the DB**: all-5s ⇒ **50.0** (a naive impl gives 100), all-1s ⇒ 50.0, `[5,1,5,2,5,4,5,2,5,2]` ⇒ 85.0
- ✅ **Raw Q1..Q10 stored + exported** (not just the composite) so items can be re-analysed
- ✅ **Participant declaration** (voluntary / anonymous / not linked to medical data / on-device) with a **required consent checkbox that gates submission** — verified: unchecked ⇒ blocked
- ✅ `© Digital Equipment Corporation, 1986` attribution (required to reproduce SUS)
- ✅ 48dp touch targets + `Semantics` on the 1–5 scale; result dialog with adjective band (68 = average)
- ✅ Satisfaction ratings (3-item Likert) — already existed in §5

## 10. Usability-study instrumentation 📈  ✅ (device-verified)
Closes the gaps against the study's "automatic app analytics" list. DB v12 adds `analytics_events.value`.
- ✅ **Navigation logs** — `AnalyticsRouteObserver` (a `NavigatorObserver`) logs every route push/pop; pushed routes are named (`/wellbeing/sus`, `/appointments/add`, …)
- ✅ **Time-on-task** — dwell time (ms) recorded on `screen_close`; per-screen totals + averages in "My Activity" and the export
- ✅ **Error logs** — `FlutterError.onError` + `ErrorWidget.builder` + every `showAppError` (so *user* errors like failed validation are counted too)
- ✅ **Help/tutorial usage** — capture-tips dialog, senior tips, education articles, and `read_aloud:*`
- ✅ **Task completion rate** — `task_start` on opening a flow, `task_complete` on successful save; rate = complete/start
- ✅ Surfaced in **My Activity** and the **engagement export** (CSV/PDF/Excel)
- ⬜ Researcher observation (assistance required, confusion, think-aloud) is **manual by design** — out of app scope

## 11. Accessibility & error handling ♿  🚧 (must pass — 9/11 green)
| # | Criterion | Status | Note |
|---|---|---|---|
| 1 | Font size | ✅ Pass | 39 sub-12sp sizes raised; **0 remain < 12sp**. Consider 14sp body (item 6 in TODO) |
| 2 | Text/background contrast | ✅ Pass | **Measured**, not guessed. `core/theme/app_colors.dart`; all 16 text pairs ≥ 4.5:1, 3 icon pairs ≥ 3:1. Device-sampled: hero 4.86:1, logout 5.62:1 |
| 3 | Touch target size | ✅ Pass | Dialog buttons, SUS circles, `SpeakButton` all 48dp; self-care shuffle 40dp `TextButton` |
| 4 | Alternative labels for icons | ✅ Pass | **0 IconButtons without a tooltip** (12 added); tooltip = screen-reader label |
| 5 | Screen reader compatibility | 🚧 **Ready, untested** | Labels + `Semantics` in place; **still never run under TalkBack** |
| 6 | Text scaling supported | ✅ Pass | 13 fixed-height buttons → `ConstrainedBox(minHeight:)`; services grid scales with `textScalerOf`. Verified at `font_scale 2.0`: **0 overflow events** |
| 7 | Arabic (RTL) display | ✅ Pass | Device-verified across all features |
| 8 | English–Arabic switching | ✅ Pass | 527/527 key parity, verified live |
| 9 | Error messages accessible | ✅ Pass | All user-facing errors are **localized dialogs**; raw exceptions never shown (`ErrorWidget` sanitised); each error logged |
| 10 | Device compatibility | 🚧 Partial | Only Pixel 4 / API 36. **App is now portrait-locked** (manifest + `SystemChrome` + iOS plist), verified on device — landscape no longer a concern; small-phone/tablet still untested |
| 11 | TalkBack / larger fonts | 🚧 Partial | Larger fonts ✅ verified at 2.0×; TalkBack still untested (#5) |

**Save/error UX:** all save confirmations and errors now use **dialogs, not SnackBars** (`core/widgets/app_dialogs.dart`) — a 40sp icon, localized title/body, and a full-width 48dp OK button. Dialogs are announced by screen readers; SnackBars auto-dismiss and are easily missed.

**Voice assistant:** `flutter_tts` (`core/services/voice_assistant_service.dart`) + a 48dp `SpeakButton`. **Device-verified**: logcat showed `TTS: Utterance ID has started` and the engine requested the **Arabic** voice (`ar-xa`) when the app was in Arabic. ⚠️ *Important:* TalkBack/VoiceOver are the real accessibility path (driven by `Semantics`); read-aloud is a **complement** for elderly users who never enable a screen reader — it does not by itself satisfy criteria #5/#11.

## Progress
- **Done + committed + pushed:** §0 baseline · §1 Glucose · §2 Medication · §3 Self-Care · §4 Home dashboard · §5 QoL/PRO · §6 Appointments · §7 Education · §8 Engagement.
- **Device-QA'd this session (all pass, Arabic RTL + dark mode):** §1–§8. Glucose crash (Issue #1) confirmed **fixed**.
- **All 8 tracker sections are built, committed, and pushed to `origin/main`** (through `827eea5`).
- **Home tile art device-verified** in light + dark (after the `srcIn` blend-mode fix); self-care shuffle confirmed working.
- **§9 SUS · §10 instrumentation · §11 accessibility** built and device-verified. Accessibility is **9/11**; the two open criteria are a TalkBack sweep and device/orientation coverage.
- **Open functional bug:** wound `length`/`width` are written as `0.0` — the healing-trend chart therefore has no baseline for real users (see RESUME HERE TODO #5).

_As each item ships, it gets checked off here._
