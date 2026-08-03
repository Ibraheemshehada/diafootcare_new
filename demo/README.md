# DiaFootCare — Demo assets

Screenshots and script for the app demo video.

- **[DEMO_STORYBOARD.md](DEMO_STORYBOARD.md)** — scene-by-scene script: each screen with a voiceover line and a ready-to-paste video-generation prompt.
- **[screenshots/](screenshots/)** — 42 real captures (1080×2280, clean status bar). Ordered by the demo flow (prefix = flow order).
- **[d.sh](d.sh)** — ADB helper to re-capture / extend (`cap`, `tap`, `dump`, `demo`).

## Screenshot index

| File | Screen |
|------|--------|
| `00_notif_permission` | System notification-permission prompt (first launch) |
| `01_splash` | Splash / logo |
| `02_terms` | Terms & Conditions |
| `02_terms_bottom` / `02_terms_agreed` | Terms scrolled / “I Agree” ticked |
| `03_consent` | Informed consent — data sharing & study participation |
| `04_mode_choice` | Choose analysis mode (Online vs Offline) |
| `04b_mode_offline` | Offline mode selected |
| `05_model_download` | On-device model download (~199 MB, 6 files) |
| `06_login` | Login (with **Continue as Guest**) |
| `06a_forget_password` | Forgot password |
| `07_signup` | Sign up / create account |
| `10_home` | Home dashboard (guest) |
| `11a_capture_tips` | “Tips for Clear Wound Photos” dialog |
| `11_capture_camera` | Capture screen (shutter + choose-photo) |
| `11d_gallery_picker` | System photo picker |
| `12_preview` | Preview the wound photo |
| `14_result_top` | AI result — measurements (length/width), risk badge |
| `14_result_mid` | AI result — tissue findings, infection, blood flow |
| `14_result_bottom` | AI result — progress summary & graph, Save |
| `15_history` | Wound Photo History (summary + trend) |
| `16_healing_top` | Healing Progress — photo + measurements |
| `16_wound_detail` | Healing Progress — measurements & wound details |
| `16_healing_bottom` | Healing Progress — details & progress graph |
| `17_profile` | Profile |
| `20_glucose` | Blood glucose log |
| `21_medication` | Medications / adherence |
| `22_selfcare` | Daily self-care checklist |
| `23_appointments` | Appointments |
| `24_wellbeing` | My Well-being |
| `24a_qol_checkin` | Well-being check-in (pain / mobility / mood) |
| `24b_satisfaction` | App satisfaction survey |
| `24c_sus` | System Usability Scale questionnaire |
| `25_education` | Education — foot-care guides |
| `25b_education_article` | Education article (Daily Foot Care) |
| `26_reminders` | Daily reminders |
| `27_notes` | Daily notes |
| `28_usage` | My Activity — engagement analytics |
| `30_export_data` | Export my data (PDF / CSV) |
| `31_edit_profile` | Edit personal information |
| `32_senior_tips` | Senior Mode Tips (accessibility) |
| `34_change_password` | Change password |

## Before recording
See **Known issues** in the storyboard — two screens still show a leftover **“depth”** field, and one progress figure reads “+-503.4%”. Fix or keep out of frame.
