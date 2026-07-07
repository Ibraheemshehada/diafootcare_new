# DiaFootCare — Feature Tracker

Living checklist of what's built and what remains, based on the "Introducing
DiaFootCare" feature slide + the clinical-study requirements (engagement,
glucose logs, medication adherence, patient-reported outcomes / QoL, self-care
behavior, pharmacist & education support).

**Legend:** ✅ done · 🚧 in progress · ⚠️ partial · ⬜ not started

_Last updated: 2026-07-07_

---

## 🔖 RESUME HERE — session handoff (2026-07-07)

**State:** §1 Glucose + §2 Medication are **committed** (`6a4f39a`). §3 Self-Care built this session and is **local & uncommitted** (not committed/pushed yet). `flutter analyze` = **0 errors** (only pre-existing `withOpacity`/style infos remain).

**Built this session (2026-07-07), awaiting device QA:**
1. **§3 Self-Care Behavior & Daily Check-ins** — a fixed daily foot-care checklist (5 tasks: inspect feet, wash & dry, moisturize, footwear, wound check). Tap a task to mark it done today; a completion ring shows today's %, plus a 🔥 streak badge (consecutive fully-completed days). Persists per-day in new DB table `self_care_logs`. Home tile "Daily Self-Care" (`/selfcare`), EN/AR, and a **7-day adherence %** section in export (CSV/PDF/Excel + toggle). **No add-dialog/FAB** (fixed task list) so it avoids the glucose crash class entirely. Includes the clinic **Do's & Don'ts** (8+6, from the infographics) as a rotating "Self-care tip" (random per launch + shuffle), with the full list behind a "View all" expander.
2. **§4 Home health dashboard** — the home hero now surfaces **DFU risk** (from the latest wound's infection/ischaemia), glucose, and the **next appointment**; a dedicated **Self-Care summary card** shows today's completion bar + 🔥 streak + the rotating tip and taps through to the feature. **QA:** home shows Foot status row colored by risk (add a wound analysis first) → tap it opens wound history; self-care card bar/streak reflect today's checklist.
3. **§6 Appointments** — new DB-backed feature (`appointments`, DB v8): full-page add form (title/date/time/location/notes + reminder lead), Upcoming/Past lists with swipe-to-delete, one-off local notification at the chosen lead time, home hero "next appointment" row + service tile, and an export section. **QA:** add an appointment a few minutes out with "at time" reminder → confirm it lists under Upcoming, the home hero shows it, and the notification fires.

**Still awaiting device QA from last session (now committed):**
- **§1 Glucose** — add a reading → confirm NO red error screen; reading + status + 7-avg update live (crash fix from Issue #1).
- **§2 Medication** — add a med, tap dose chips → adherence % updates; swipe-to-delete works.

4. **§5 QoL / Patient-Reported Outcomes** — new "My Well-being" feature (DB v9 `qol_entries` + `satisfaction_entries`): a periodic QoL check-in (pain / mobility / emotional impact on 0–10 sliders) with a latest-scores card, a burden trend chart, and a swipe-to-delete history; plus a 1–5 Likert satisfaction survey (ease / usefulness / willingness). Home service tile + export section. **QA:** record a check-in → summary + trend update; submit the survey; export with "Well-being" ticked.

**DB:** schema is now **v10** (glucose=v5, medications+medication_logs=v6, self_care_logs=v7, appointments=v8, qol_entries+satisfaction_entries=v9, analytics_events=v10). Existing installs auto-migrate via `onUpgrade`; no wipe needed.

5. **§7 Education & Pharmacist Support** — new "Education" hub (static, no DB): 5 curated foot-care guides with article detail pages, a pharmacist-verified tips card, and an "Ask your pharmacist" suggestions card. Home service tile. **QA:** open Education → tap a guide → article renders; check RTL/dark.
6. **§8 Engagement / Usage Analytics** — local event logging (DB v10 `analytics_events`), a "My Activity" usage-summary screen (from Profile), and an engagement export section. **QA:** open a few features → My Activity shows counts; export with "Usage & Engagement" ticked.

**🎉 All 8 tracker sections are now built.** Remaining work is **device QA of every feature + commit review**, not new features. (Optional polish backlog below.)

## Optional polish backlog (not blocking)
- `intl` is used directly in several files but isn't a direct `pubspec.yaml` dependency (transitive via easy_localization) → a handful of harmless `depend_on_referenced_packages` info lints. Add `intl` to dependencies to clear them.
- Wider pre-existing lint cleanup: many `withOpacity` → `.withValues()` deprecations across older screens.
- Surface the self-care streak / QoL on the Home hero only if desired (hero is already dense).

**Build/run gotchas (so we don't rediscover):**
- Run: `flutter run -d emulator-5554`. adb isn't on PATH → use `C:/Users/jawhara/AppData/Local/Android/Sdk/platform-tools/adb.exe` (set `export MSYS_NO_PATHCONV=1` in Git Bash for `adb shell`).
- **Gradle daemon crashes when it's been idle** ("daemon has disappeared" / `hs_err_pid*.log`). Fix: `cd android && ./gradlew --stop`, then rebuild. (Not a code error.)
- Emulator (Pixel_4_API_36) is **laggy — taps often miss**; screenshot after each tap. It's been bumped to 4 GB RAM / 12 GB disk (in its `config.ini`).
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

### Issue #1 — Glucose screen crashes after adding a reading — 🔧 FIX APPLIED (needs QA)
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

## Progress
- **Done:** baseline (§0)
- **Committed:** §1 Glucose Monitoring (+ crash fix), §2 Medication Management (`6a4f39a`).
- **Committed:** §3 Self-Care, §4 Home health dashboard, §6 Appointments (`64c312d`).
- **Committed:** §5 QoL / PRO (`54cfe29`), §7 Education (`ed4ff02`).
- **Built this session, pending device QA + commit:** §8 Engagement / Usage Analytics (event logging + "My Activity" + engagement export). Compiles with **0 analyzer errors**.
- **All 8 tracker sections are built.** Next up: **device QA of the whole app**, then commit review. No feature work remains.

_As each item ships, it gets checked off here._
