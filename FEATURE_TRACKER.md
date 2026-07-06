# DiaFootCare — Feature Tracker

Living checklist of what's built and what remains, based on the "Introducing
DiaFootCare" feature slide + the clinical-study requirements (engagement,
glucose logs, medication adherence, patient-reported outcomes / QoL, self-care
behavior, pharmacist & education support).

**Legend:** ✅ done · 🚧 in progress · ⚠️ partial · ⬜ not started

_Last updated: 2026-07-06_

---

## 🔖 RESUME HERE — session handoff (2026-07-06, end of day)

**State:** All work below is **local & uncommitted** (nothing committed/pushed this session). `flutter analyze` = **0 errors** across the project.

**Built today, awaiting device QA (couldn't test — emulator was closed):**
1. **§1 Glucose** — full feature + a **crash fix** for the `_dependents.isEmpty` assert on add. Fix = rewrote the add flow to an `AlertDialog` that returns the input and mutates *after* the dialog closes (see Issue #1). **QA priority #1:** open Glucose → add a reading → confirm NO red error screen, and the reading + status + 7-avg update live.
2. **§2 Medication** — new tracker (meds list, per-dose taken chips, today's adherence ring, 7-day adherence in export). **QA priority #2:** add a medication, tap dose chips, confirm adherence % updates; check swipe-to-delete.

**DB:** schema is now **v6** (glucose=v5, medications+medication_logs=v6). Existing installs auto-migrate via `onUpgrade`; no wipe needed.

**Next features (in order):** §3 Self-care daily checklist → §4 remaining dashboard tiles (DFU status, appointment) → §6 Appointments → §5 QoL/PRO survey → §7 Education/pharmacist → §8 Engagement analytics.

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

## 3. Self-Care Behavior & Daily Check-ins ✅-ish  ⬜
"Daily foot inspection, medication schedule, wound monitoring adherence %."
- ⬜ Daily self-care checklist (foot inspection, wear proper footwear, wound check, etc.)
- ⬜ Persist per-day completion; compute daily/weekly adherence %
- ⬜ Streak / check-in indicator on home
- ⬜ Include self-care adherence in export
- ⬜ EN/AR localization

## 4. Dashboard — Key Health Indicators 📊  ⚠️
- ⬜ Surface **DFU status** (latest infection/ischaemia risk badge) on the home dashboard
- ⬜ Glucose tile (from §1)
- ⬜ Self-care adherence / streak tile (from §3)
- ⬜ Next appointment tile (from §6)

## 5. Patient-Reported Outcomes (QoL) 🧠  ⬜
"Standardized scales: pain, mobility, emotional impact."
- ⬜ Periodic QoL questionnaire (pain 0–10, mobility, emotional impact) — simple standardized scale
- ⬜ Store responses with date; show trend over time
- ⬜ Satisfaction survey (ease of use, usefulness, willingness to continue)
- ⬜ Include QoL + satisfaction in export
- ⬜ EN/AR localization

## 6. Appointments & Alerts 📅  ⬜
- ⬜ Add "appointment" reminder type (or dedicated appointments list)
- ⬜ Appointment notification + home "next appointment" tile
- ⬜ EN/AR localization

## 7. Education & Pharmacist Support 📚  ⬜
- ⬜ Educational content module (articles/tips on DFU care, prevention)
- ⬜ Pharmacist-verified tips section (curated content)
- ⬜ (Optional) contact/ask-pharmacist entry point
- ⬜ EN/AR localization

## 8. Engagement / Usage Analytics 📈  ⬜
Study measures usage frequency, feature utilization, retention.
- ⬜ Local event logging (screen opens, feature use, login timestamps)
- ⬜ Usage summary (last active, streak, feature-use counts)
- ⬜ Include engagement summary in export (for the study)

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
- **Built, pending device QA:** §1 Glucose Monitoring (+ crash fix applied), §2 Medication Management (tracker + adherence + export). Both compile with 0 analyzer errors.
- **Next up:** device QA of §1 + §2 → §3 Self-care checklist → §4 remaining dashboard tiles → §6 Appointments → §5 QoL → §7 Education → §8 Engagement

_As each item ships, it gets checked off here._
