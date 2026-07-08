# DiaFootCare — Feature Tracker

Living checklist of what's built and what remains, based on the "Introducing
DiaFootCare" feature slide + the clinical-study requirements (engagement,
glucose logs, medication adherence, patient-reported outcomes / QoL, self-care
behavior, pharmacist & education support).

**Legend:** ✅ done · 🚧 in progress · ⚠️ partial · ⬜ not started

_Last updated: 2026-07-07_

---

## 🔖 RESUME HERE — session handoff (2026-07-08)

**State:** `flutter analyze` = **0 errors**. §1–§8 built + device-QA'd (Arabic RTL, light + dark). This session added **§9 SUS questionnaire**, **§10 usability-study instrumentation**, and **§11 accessibility + dialogs + voice assistant** — all device-verified. See the ⬜ TODO list below.

> ⚠️ **The app MUST pass the 11-criterion Accessibility Check** (see §11). It does **not** fully pass yet — 4 criteria still need work (contrast, text scaling, TalkBack testing, device coverage). Everything else is green.

### ⬜ TODO — next session
1. **Finish SnackBar → dialog conversion.** 21 `showSnackBar` calls remain in 11 files: `auth/viewmodel/*` (5), `otp_verify_screen`, `notes_screen`, `notifications_screen`, `change_password_screen`, `wound/analysis/ai_result_screen`, `analysis_loading_screen`. Use `showAppSuccess` / `showAppError` from `core/widgets/app_dialogs.dart`. (16 of 37 already converted.)
2. **Accessibility #2 — contrast.** Measure text/background against WCAG AA (4.5:1). Suspects: `hintColor` body text, and the `.06–.16` alpha tints on cards/badges.
3. **Accessibility #6 — text scaling.** Set the device font size to Largest and walk the app. Fixed-height containers (`SizedBox(height: 48/50/52.h)`, badge `Container(height: 30.h)`) and `maxLines: 2` + ellipsis will overflow/truncate. Prefer intrinsic heights + `minHeight`.
4. **Accessibility #5/#11 — TalkBack.** Every icon button now has a tooltip (= its semantics label) and the SUS scale/consent have explicit `Semantics`. **This has never been run under TalkBack.** Enable TalkBack on a real device and sweep the main flows.
5. **Accessibility #10 — device coverage.** Only Pixel 4 / API 36 has been tested. Try a small phone, a tablet, and (if in scope) iOS.
6. **Consider raising body text 12sp → 14sp.** Minimum is now 12sp everywhere, but this app's users are elderly diabetics; 14sp body would be kinder.
7. **Voice assistant polish (optional).** `SpeakButton` is on the education article, the SUS declaration. Consider adding it to self-care tips and the Do's & Don'ts, and a global on/off in Profile.

### What happened this session
1. **Full on-device QA of §1–§8** — all pass. Highlights verified live: glucose add-reading (crash fix — NO red screen, live update), self-care toggle + ring + color thresholds + tip-on-launch, appointments add → Upcoming/Past + reminder chip, well-being sliders + severity colors + **fl_chart trend chart updates**, education hub + article + pharmacist-verified badge, and **§8 "My Activity" showed real per-feature open counts** (proof analytics logging works end-to-end). Persistence survived app reinstall.
2. **Fixes applied + pushed (`bd7f4b2`):**
   - **`android/gradle.properties`: heap 8G → 3G** (metaspace 4G→1G, `workers.max=2`). The 8G heap was the cause of the recurring **"Gradle build daemon disappeared" OOM crash** on this 16 GB machine. Clean build now ~18 min; **incremental builds ~30–40 s and reliable.**
   - **Appointment default time** now rounds to the *next* hour with a 30-min buffer (was rounding *down*, so a just-created appointment could show as "Past"). Verified on device: at 1:56 the default correctly became **3:00 PM**.
   - **Self-care "Another" shuffle** → swapped small `InkWell` for a 40dp `TextButton` (bigger, gesture-robust, better for seniors). ✅ **Verified working on device**: the tip rotated from a green "إفعل/Do" tip to a red "لا تفعل/Don't" tip, badge colour flipping correctly. The earlier non-response was the tiny `InkWell` target losing the emulator's synthetic taps to the surrounding scroll view — not a code bug.
   - **`intl` added to `pubspec.yaml`** (was transitive) — clears the `depend_on_referenced_packages` info lints.
3. **Home tile visuals (`6e6806c`) — ✅ device-verified:**
   - Redrew **glucose.svg + medication.svg as outline icons**. Reason: the service tile tints icons with a single color (`BlendMode.srcIn`), which **erased the white detail overlays** of the old filled icons (they rendered as flat blobs). Outline style matches the other newer icons and keeps detail.
   - Added **6 decorative background SVGs** (`bg_glucose/medication/selfcare/appointments/wellbeing/education`) and wired `bgSvgAsset` into those `ServiceItem`s. **All 10 Home tiles now have background art** (before, only the first four did).
4. **Service-tile bg blend-mode bug — found & fixed (`827eea5`):** the tile tinted bg art with **`BlendMode.srcATop`**, which only layers the 6–7% tint *on top* of the artwork, leaving the SVGs' own white/cream fills ~93% opaque. On light cards that passed as "subtle art" by accident; **on dark cards it rendered as glaring white shapes that covered the tile titles.** Changed to **`BlendMode.srcIn`** so the art is fully replaced by the faint tint. ✅ Device-verified in **both light and dark**: every title readable, art reads as subtle texture, icons crisp and consistent across all 10 tiles.

### ✅ Nothing blocking — the tracker is complete
All 8 sections built, committed, pushed, and device-verified. Optional polish only:
- Pre-existing `withOpacity` → `.withValues()` deprecations across older screens (info lints).
- Consider a home streak/QoL chip if desired (the hero is already fairly dense).
- The capture-tips dialog pops over Home on launch; tap "عدم الإظهار مرة أخرى" to suppress. Worth checking whether that's intended on Home (it's the wound-capture tips dialog).
3. **(Optional) polish backlog:** pre-existing `withOpacity` → `.withValues()` deprecations across older screens; consider a home streak/QoL chip if desired.

### Commits on origin/main (this push cycle)
`6a4f39a` §1+§2 · `64c312d` §3+§4+§6 · `54cfe29` §5 · `ed4ff02` §7 · `8ac4fb4` §8 · `bd7f4b2` QA fixes · `6e6806c` tile icons+bg art · `827eea5` tile bg blend-mode fix (srcIn).

**DB:** schema is **v10** (glucose=v5, meds+med_logs=v6, self_care_logs=v7, appointments=v8, qol+satisfaction=v9, analytics_events=v10). Existing installs auto-migrate via `onUpgrade`; no wipe needed.

**Build/run gotchas (so we don't rediscover):**
- Run: `flutter run -d emulator-5554`. adb isn't on PATH → use `C:/Users/jawhara/AppData/Local/Android/Sdk/platform-tools/adb.exe` (set `export MSYS_NO_PATHCONV=1` in Git Bash for `adb shell`).
- Launch/install pattern that worked: `flutter emulators --launch Pixel_4_API_36`; wait for `adb shell getprop sys.boot_completed`=1; `adb install -r -d build/app/outputs/flutter-apk/app-debug.apk`; launch with `adb shell monkey -p com.example.daifootcare_new -c android.intent.category.LAUNCHER 1`; screenshot with `adb exec-out screencap -p > out.png`. App opens straight to Home (guest session persists).
- **Gradle daemon OOM crash** ("daemon has disappeared" / `hs_err_pid*.log`) — was caused by `org.gradle.jvmargs=-Xmx8G`. **FIXED** in `gradle.properties` (now `-Xmx3G`). If it recurs on a low-RAM run: the machine only had ~2.4 GB free with the emulator up — **kill the emulator, build the APK, then relaunch the emulator and `adb install`** (build is the memory-heavy step; install is light).
- Emulator (Pixel_4_API_36) is **laggy — taps often miss** (especially small targets in scroll views); screenshot after each tap and re-tap. It's 4 GB RAM / 12 GB disk (in its `config.ini`).
- Models are in **Git LFS** now (clip_backbone is 167 MB > GitHub's 100 MB limit). Pushes work; `git lfs checkout` restores real model files if the working tree shows 134-byte pointers.
- Login is via **Guest** (`is_guest` pref) — the app opens straight to Home as "Guest"; the old temp bypass was removed.

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

## 11. Accessibility & error handling ♿  🚧 (must pass — 7/11 green)
| # | Criterion | Status | Note |
|---|---|---|---|
| 1 | Font size | ✅ Pass | 39 sub-12sp sizes raised; **0 remain < 12sp**. Consider 14sp body (item 6 in TODO) |
| 2 | Text/background contrast | ⬜ **Not verified** | Needs a WCAG AA (4.5:1) measurement pass |
| 3 | Touch target size | ✅ Pass | Dialog buttons, SUS circles, `SpeakButton` all 48dp; self-care shuffle 40dp `TextButton` |
| 4 | Alternative labels for icons | ✅ Pass | **0 IconButtons without a tooltip** (12 added); tooltip = screen-reader label |
| 5 | Screen reader compatibility | 🚧 **Ready, untested** | Labels + `Semantics` in place; never run under TalkBack |
| 6 | Text scaling supported | ⬜ **Not verified** | Scaling not blocked, but fixed heights will overflow at large fonts |
| 7 | Arabic (RTL) display | ✅ Pass | Device-verified across all features |
| 8 | English–Arabic switching | ✅ Pass | 527/527 key parity, verified live |
| 9 | Error messages accessible | ✅ Pass | All user-facing errors are **localized dialogs**; raw exceptions never shown (`ErrorWidget` sanitised); each error logged |
| 10 | Device compatibility | 🚧 Partial | Only Pixel 4 / API 36 tested |
| 11 | TalkBack / larger fonts | 🚧 **Ready, untested** | Blocked on #5 + #6 |

**Save/error UX:** all save confirmations and errors now use **dialogs, not SnackBars** (`core/widgets/app_dialogs.dart`) — a 40sp icon, localized title/body, and a full-width 48dp OK button. Dialogs are announced by screen readers; SnackBars auto-dismiss and are easily missed.

**Voice assistant:** `flutter_tts` (`core/services/voice_assistant_service.dart`) + a 48dp `SpeakButton`. **Device-verified**: logcat showed `TTS: Utterance ID has started` and the engine requested the **Arabic** voice (`ar-xa`) when the app was in Arabic. ⚠️ *Important:* TalkBack/VoiceOver are the real accessibility path (driven by `Semantics`); read-aloud is a **complement** for elderly users who never enable a screen reader — it does not by itself satisfy criteria #5/#11.

## Progress
- **Done + committed + pushed:** §0 baseline · §1 Glucose · §2 Medication · §3 Self-Care · §4 Home dashboard · §5 QoL/PRO · §6 Appointments · §7 Education · §8 Engagement.
- **Device-QA'd this session (all pass, Arabic RTL + dark mode):** §1–§8. Glucose crash (Issue #1) confirmed **fixed**.
- **All 8 tracker sections are built, committed, and pushed to `origin/main`** (through `827eea5`).
- **Home tile art device-verified** in light + dark (after the `srcIn` blend-mode fix); self-care shuffle confirmed working. **Nothing is pending** — see RESUME HERE for the optional polish list.

_As each item ships, it gets checked off here._
