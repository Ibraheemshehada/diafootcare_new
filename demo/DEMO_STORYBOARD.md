# DiaFootCare — App Demo Storyboard

Scene-by-scene script for the app demo video. Every scene lists the **screenshot**
to show, what is **on screen**, a **voiceover** line, and a **video prompt** you can
paste into an image-to-video tool (Runway, Pika, Kling, Sora, Veo, etc.) or use as a
screen-recording direction.

- **Screenshots folder:** [`demo/screenshots/`](screenshots/) — 42 real captures, Pixel-style phone, 1080×2280, clean status bar (12:00, full battery/Wi-Fi).
- **Device/state:** captured on the live build (`tech.diafootcare.app`) as a **guest** session; wound analysis uses a real diabetic-foot-ulcer photo; the analysis output is **depth-free** (depth was removed from the pipeline).
- **Suggested length:** 90–120 s. **Aspect:** 9:16 (phone) for social, or 16:9 with the phone framed on a soft gradient for a talk/poster.
- **Tone:** calm, clinical, reassuring. Soft ambient music, no hard cuts — cross-dissolves between screens.

> **Read this before recording — 3 things to fix or avoid.** See [§ Known issues](#known-issues-before-you-record) at the end. Short version: two screens still show a leftover **“depth”** field even though depth was removed from the analysis, and one progress figure reads **“+-503.4%”**. Either fix them first or avoid framing those exact spots.

---

## Act 1 — First launch: trust before features (≈25 s)

The opening sells *credibility*: an on-device medical tool that is honest about data. Good for a PhD audience.

### Scene 1 — Splash
- **Screenshot:** `01_splash.png`
- **On screen:** DiaFootCare foot-and-hand logo on white.
- **Voiceover:** “DiaFootCare — diabetic foot-ulcer assessment that runs on the phone in your pocket.”
- **Video prompt:** *A clean white phone screen; a blue foot-and-hand medical logo fades and gently scales up from 90% to 100%, a soft loading pulse beneath it. Minimal, calm, clinical. 2 seconds, slow ease-in.*

### Scene 2 — Notification permission *(optional, keep it short)*
- **Screenshot:** `00_notif_permission.png`
- **On screen:** System dialog “Allow DiaFootCare to send you notifications?”
- **Voiceover:** “It only asks for what it needs — reminders you can turn off any time.”
- **Video prompt:** *Phone screen with a system permission sheet sliding up from the bottom; a finger taps “Allow”. 1.5 s.*

### Scene 3 — Terms & Conditions
- **Screenshot:** `02_terms.png` → `02_terms_agreed.png`
- **On screen:** Plain-language terms; a medical disclaimer; “I Agree” + Continue.
- **Voiceover:** “Clear terms up front — it assists monitoring, it does not replace your clinician.”
- **Video prompt:** *A terms screen scrolls slowly to the bottom; an “I Agree” checkbox ticks; the greyed “Continue” button turns solid blue. 3 s, smooth scroll.*

### Scene 4 — Informed consent (the ethics beat)
- **Screenshot:** `03_consent.png`
- **On screen:** “Data sharing and study participation” — what is collected, where it goes, who sees it, “It is not anonymous.”
- **Voiceover:** “Real informed consent: exactly what is collected, where it goes, and who can see it — nothing hidden.”
- **Video prompt:** *Hold on a calm consent screen; the key line “It is not anonymous” subtly highlights; the “I have read and understood” box ticks and “Accept and continue” activates. 4 s. Trustworthy, unhurried.*

### Scene 5 — Choose how analysis runs
- **Screenshot:** `04_mode_choice.png` → `04b_mode_offline.png`
- **On screen:** Online (nothing to install, needs internet) vs Offline (≈200 MB once, works with no internet).
- **Voiceover:** “Analyse in the cloud, or download the models once and work fully offline — your choice.”
- **Video prompt:** *Two selectable cards labelled Online and Offline; the Offline card’s radio fills blue as it’s selected. Clean toggle animation. 2.5 s.*

### Scene 6 — On-device model download *(offline path)*
- **Screenshot:** `05_model_download.png`
- **On screen:** “Offline analysis files”, progress bar, “file 1 of 6”, “199 MB”, Pause / Use online instead.
- **Voiceover:** “The full AI runs on the device — no wound photo ever has to leave the phone.”
- **Video prompt:** *A download progress ring/bar advancing from 3% upward, “file 1 of 6” ticking, reassuring copy “you can pause any time”. 3 s.*

### Scene 7 — Sign in, or continue as guest
- **Screenshots:** `06_login.png` (main), `07_signup.png`, `06a_forget_password.png` (b-roll)
- **On screen:** Email/password, Remember Me, Login, **Continue as Guest**, Create Account.
- **Voiceover:** “Create an account to sync with your care team — or start straight away as a guest.”
- **Video prompt:** *Login screen; a finger taps “Continue as Guest”; the screen cross-dissolves toward a home dashboard. 2.5 s.*

---

## Act 2 — A daily companion (≈30 s)

Position the app as more than a scanner: a full diabetic self-care hub.

### Scene 8 — Home dashboard
- **Screenshot:** `10_home.png`
- **On screen:** “Good morning, Guest”, What’s New Today, Daily Self-Care progress, Services (Capture Wound / Log).
- **Voiceover:** “Every morning, one place for your reminders, your self-care streak, and a quick foot-care tip.”
- **Video prompt:** *A phone home dashboard gently scrolls; cards rise into view with a soft parallax. Warm, welcoming. 3 s.*

### Scene 9 — Everyday tracking (montage)
- **Screenshots (quick cuts, ~1 s each):** `20_glucose.png`, `21_medication.png`, `22_selfcare.png`, `23_appointments.png`, `26_reminders.png`, `27_notes.png`
- **On screen:** Blood glucose log, medication adherence ring, daily foot-care checklist, appointments, reminders, notes.
- **Voiceover:** “Log blood sugar and medications, tick off your daily foot-care checklist, and keep appointments and notes in one app.”
- **Video prompt:** *A fast, rhythmic montage of six clean tracking screens flipping past like cards, each holding ~0.8 s, synced to a soft beat. Blue-and-white, tidy. 5 s.*

### Scene 10 — Learn to protect your feet
- **Screenshots:** `25_education.png` → `25b_education_article.png`
- **On screen:** Foot-care guides list; “Daily Foot Care” article with a pharmacist-verified badge.
- **Voiceover:** “Short, expert-backed guides — because prevention is the best treatment.”
- **Video prompt:** *An education list; a finger taps “Daily Foot Care”; the article opens and scrolls a few lines. 3 s.*

### Scene 11 — Well-being & study measures
- **Screenshots:** `24_wellbeing.png`, `24a_qol_checkin.png`, `24b_satisfaction.png`, `24c_sus.png`
- **On screen:** Pain/mobility/mood check-in, satisfaction survey, System Usability Scale.
- **Voiceover:** “Quick well-being check-ins and standard questionnaires help track quality of life over time.”
- **Video prompt:** *A well-being check-in with sliders for pain and mood; then a 1–5 Likert questionnaire; a finger taps “Submit”. 3.5 s.*

---

## Act 3 — The core: AI wound analysis (≈35 s) ★

This is the headline. Slow down; let each result read.

### Scene 12 — Start a capture
- **Screenshots:** `11a_capture_tips.png` → `11_capture_camera.png`
- **On screen:** “Tips for Clear Wound Photos”, then the camera screen with a shutter and a “Choose a photo” gallery button.
- **Voiceover:** “Capturing a wound takes seconds — with guidance for a clear, usable photo.”
- **Video prompt:** *A tips dialog dismisses with “Ok”; a camera viewfinder appears with a round shutter button pulsing softly. 3 s.*

### Scene 13 — Pick / take the photo
- **Screenshots:** `11d_gallery_picker.png` → `12_preview.png`
- **On screen:** Photo picker, then Preview with a real diabetic-foot-ulcer photo and “Save and Continue”.
- **Voiceover:** “Take a new photo or choose one — then confirm it’s clear.”
- **Video prompt:** *A photo grid; a wound thumbnail is tapped; it expands into a full-screen preview with Save/Re-take buttons. 2.5 s.*

### Scene 14 — Analysis
- **Screenshot:** *(brief spinner — screen-record live, or reuse `12_preview.png` with an overlay)*
- **On screen:** A loading indicator while the models run.
- **Voiceover:** “Three deep-learning models run — segmentation, tissue type, and infection risk.”
- **Video prompt:** *A short, elegant loading animation over a dimmed wound photo; a subtle circular scan sweep suggests AI processing. 2 s.*

### Scene 15 — AI result: measurements & risk
- **Screenshots:** `14_result_top.png` → `14_result_mid.png`
- **On screen:** Measurements (Length 4.6 cm, Width 3.3 cm), **High Risk Detected**, tissue findings (Necrosis, Slough, Granulation, Callus with confidence %), Infection **Present**, Blood Flow **Impaired**.
- **Voiceover:** “In seconds: wound size, the tissue types in the wound bed, and infection and blood-flow risk — with a clear overall badge.”
- **Video prompt:** *An analysis result scrolls slowly; a red “High Risk Detected” banner draws attention; tissue-confidence bars fill left-to-right. Clinical, precise, 5 s.*

### Scene 16 — AI result: trend & save
- **Screenshot:** `14_result_bottom.png`
- **On screen:** Progress Summary, Progress Graph, “Save Result”.
- **Voiceover:** “Save it, and every scan becomes a point on your healing curve.”
- **Video prompt:** *A line graph draws itself left-to-right; a blue “Save Result” button presses down. 3 s.* *(Avoid framing the “+-503.4%” figure — see Known issues.)*

### Scene 17 — History & healing over time
- **Screenshots:** `15_history.png` → `16_healing_top.png` → `16_healing_bottom.png`
- **On screen:** Wound Photo History (quick summary, healing trend graph); a scan’s detail with measurements and tissue.
- **Voiceover:** “Open any past scan to see how the wound is changing week to week.”
- **Video prompt:** *A history list; a wound card is tapped; a detail screen with a photo and a healing-trend graph slides in. 3.5 s.* *(In `16_wound_detail.png` avoid the “Depth 0.0 cm” card — see Known issues.)*

---

## Act 4 — Your data, your control (≈15 s)

### Scene 18 — Profile
- **Screenshots:** `17_profile.png`, `31_edit_profile.png`, `34_change_password.png` (b-roll)
- **On screen:** Edit personal info, change password, analysis mode, language, dark mode.
- **Voiceover:** “Manage your profile, language, and how the app looks and works.”
- **Video prompt:** *A settings/profile list scrolls; toggles for Dark Mode and Notifications flip on. 2.5 s.*

### Scene 19 — Engagement insights
- **Screenshot:** `28_usage.png`
- **On screen:** “My Activity” — active days, day streak, app opens, task-completion rate, time on task.
- **Voiceover:** “And for the research study, private usage insights show real-world engagement.”
- **Video prompt:** *An analytics screen; small stat tiles (streak, active days) count up. 2.5 s.*

### Scene 20 — Export & close
- **Screenshots:** `30_export_data.png`, then close on `10_home.png` or `01_splash.png`
- **On screen:** Export a copy of health records (PDF/CSV), selectable data types.
- **Voiceover:** “Export everything as PDF or CSV, any time. DiaFootCare — early detection, in your hands.”
- **Video prompt:** *An export screen with checkboxes and PDF/CSV options; then a smooth pull-back to the logo on white as the title card appears. 4 s.*

---

## Bonus / accessibility b-roll
- `32_senior_tips.png` — “Senior Mode Tips”: large text, voice guidance, caregiver profile. Use under Act 2 or Act 4 if you want to stress accessibility for older patients.

---

## Shot list (quick reference)

| # | Scene | Screenshot(s) | ~sec |
|---|-------|---------------|------|
| 1 | Splash | 01_splash | 2 |
| 2 | Notifications | 00_notif_permission | 1.5 |
| 3 | Terms | 02_terms → 02_terms_agreed | 3 |
| 4 | Consent | 03_consent | 4 |
| 5 | Mode choice | 04_mode_choice → 04b_mode_offline | 2.5 |
| 6 | Model download | 05_model_download | 3 |
| 7 | Login / Guest | 06_login (07_signup, 06a_forget_password) | 2.5 |
| 8 | Home | 10_home | 3 |
| 9 | Daily tracking | 20,21,22,23,26,27 | 5 |
| 10 | Education | 25_education → 25b_education_article | 3 |
| 11 | Well-being | 24_wellbeing,24a,24b,24c | 3.5 |
| 12 | Capture start | 11a_capture_tips → 11_capture_camera | 3 |
| 13 | Pick photo | 11d_gallery_picker → 12_preview | 2.5 |
| 14 | Analysis | (live spinner) | 2 |
| 15 | Result: risk | 14_result_top → 14_result_mid | 5 |
| 16 | Result: trend | 14_result_bottom | 3 |
| 17 | History | 15_history → 16_healing_top → 16_healing_bottom | 3.5 |
| 18 | Profile | 17_profile (31,34) | 2.5 |
| 19 | Engagement | 28_usage | 2.5 |
| 20 | Export / close | 30_export_data → 01_splash | 4 |

Total ≈ **62 s** of screens; pad with music/titles to 90–120 s.

---

## Known issues before you record

These are real, in the current build — fix them first, or keep them out of frame.

1. **“Depth” leftovers.** Depth was removed from the analysis, but two places still show it:
   - `16_wound_detail.png` / Healing Progress detail shows a **“Depth 0.0 cm”** measurement card.
   - The Home **“Log Measurements”** card subtitle still reads *“Record size and **depth**”*.
   Both are small string/widget removals. If you want a fully depth-free demo, fix these before recording (I can do it in ~10 min if you want).
2. **Odd progress figure.** The result’s Progress Summary shows **“+-503.4% since last week”** (`14_result_bottom.png`) — a real computed value that looks strange on camera. Either use a scan pair that yields a sensible number, or crop it out of frame.
3. **Guest vs account.** These shots are a **guest** session, so History starts fresh after a data reset. If you want the demo to show a populated history and healing curve, record with an account that already has several scans over time.

## How the screenshots were produced
Captured over ADB on a running emulator with a clean “demo mode” status bar; the AI result uses a real DFU photo picked from the gallery. To re-capture or extend, the helper is [`demo/d.sh`](d.sh) (`cap`, `tap`, `dump`, `demo`).
