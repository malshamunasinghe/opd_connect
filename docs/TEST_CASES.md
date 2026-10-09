# Functional Test Cases and Traceability Matrix: OPD Connect (WE_81)

**How to use this file.** Run every manual test case (TC) on the installed APK and fill in **Actual result** and **Status** (Pass/Fail) yourselves. Add a screenshot reference in the appendix for each one. Do not mark a case Pass until you have actually run it. The automated tests (AT) run with `flutter test`; paste that output into the appendix.

Test accounts to create before testing:
- `staff1@test.lk` (role: OPD staff), `admin1@test.lk` (role: admin)
- `patient1@test.lk`, NIC `199512345678`, mobile `0771234567`
- `patient2@test.lk`, NIC `851234567V`, mobile `0712345678`
- Demo data loaded (Staff → Settings → Load demo data)

---

## 1. Manual functional test cases

### Module 1: Patient journey (Lakmali M.A.D.M, S01–S07)

| TC | Screen | Req | CRUD | Steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|---|---|
| TC-01 | S01 | F1 | R | Patient → Book appointment | Step "1 / 3" shown; list of 4 hospitals from Firestore | | |
| TC-02 | S01 | F1, NF2 | U | Pick *DGH Negombo*, go back to Home, tap Book again | Negombo is listed first, labelled "Last used" | | |
| TC-03 | S01 | NF2 | R | Type "kandy" in search | Only National Hospital, Kandy is shown | | |
| TC-04 | S02 | F1 | R | Choose a hospital | Step "2 / 3"; clinic chips; only real clinic days shown as cards with places left | | |
| TC-05 | S02 | F1 | C | Tap a day card → keep reminder on → Confirm booking | Step "3 / 3" review sheet; on confirm, S03 opens with a token e.g. `A-001` | | |
| TC-06 | S02 | F1 | C | Book the same session again with the same patient | Error "You already have a booking for this clinic." No second token | | |
| TC-07 | S02 | F1 | C | Staff sets a session capacity equal to its bookings (S20); patient opens it | Card shows "Full", is not tappable; amber "All places… taken" message if all days full | | |
| TC-08 | S03 | F1, F4 | R | After TC-05 | Green tick, token largest, booking reference `OPD-XXXXXX`, hospital/clinic/doctor/date/time | | |
| TC-09 | S03 | F4 | U | Toggle "Remind me" off then on | "Saved" snackbar; value persists after reopening | | |
| TC-10 | S04 | F1 | R | Appointments tab | Upcoming tab lists the booking, highlighted; Past tab separate | | |
| TC-11 | S04 | NF2 | R | New patient with no bookings opens Appointments | Empty state with "Book appointment" button (not a blank screen) | | |
| TC-12 | S04 | F1 | D | Past tab → Remove from list on a cancelled appointment → confirm | Entry disappears; document deleted in Firestore | | |
| TC-13 | S05 | F1 | U | Upcoming → Reschedule → pick another day → Confirm change | New date and **new token** shown; old session's places-left goes up by 1 | | |
| TC-14 | S06 | F1, F5 | U | Upcoming → Cancel → submit without a reason | Snackbar asks for reason; nothing cancelled | | |
| TC-15 | S06 | F1, F5 | U | Pick "Transport problem" → Yes, cancel it | Status "Cancelled"; reason saved; session places-left +1; removed from live queue | | |
| TC-16 | S07a | F2, NF4 | R | Open live queue for a booking with 4+ patients ahead | Two labelled cards (Now serving muted / Your token filled); patients ahead and estimated wait | | |
| TC-17 | S07b | F2, F4 | R | Staff calls next until patient has ≤ 2 ahead | Within ~1 s, amber banner "Your turn is near…", vibration, number turns orange | | |
| TC-18 | S07c | F2, NF2 | R | Staff calls this patient | Full-screen green "It's your turn", token centred, room shown | | |
| TC-19 | S07 | F2 | U | Tap "I'm at the hospital" | Text changes to "Reception knows you have arrived"; staff dashboard shows green arrived icon | | |
| TC-20 | Home | F4 | R | With app open, staff calls next | In-app alert snackbar + vibration; badge count on Notifications tab | | |

### Module 2: Reception queue (P.A.J. Sithmini, S08–S12)

| TC | Screen | Req | CRUD | Steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|---|---|
| TC-21 | S08 | F2, F5 | R | Staff → Queue tab | Today's sessions in dropdown; waiting list in queue order; summary counts | | |
| TC-22 | S08 | F2 | U | Tap ↓ on position 1 | Patients swap; patient phone's "patients ahead" changes immediately | | |
| TC-23 | S08 | F5 | U | Tap arrived icon on a waiting patient | Icon turns green; tap again reverts | | |
| TC-24 | S08 | F5 | R | Change date (top right) to a day with no sessions | Empty state "No clinic sessions on this day" | | |
| TC-25 | S09 | F5 | R | Walk-in → search NIC `851234567V` (seeded or registered) | Green card with name, age, allergies; name/phone pre-filled | | |
| TC-26 | S09 | F5 | C | Walk-in → unknown NIC → enter name only → Issue token | Dialog shows new token; patient appears at end of queue; capacity +1 | | |
| TC-27 | S09 | F5 | C | Walk-in for a patient aged 70+ | Priority switch is pre-selected "Elderly (70+)"; token placed ahead of non-priority | | |
| TC-28 | S09 | F1 | C | Pick a **future** date → session → Walk-in / phone | Title "Phone / assisted booking"; token issued with channel "Phone booking", not marked arrived | | |
| TC-29 | S09 | F5 | R | Search with an unknown NIC → Register | Opens S13 with NIC pre-filled; after save, record is found | | |
| TC-30 | S10 | F2, F5 | U | Long-press a waiting patient → reason "Disability" → Flag | Row gets orange border + ★ reason; moves after other priority patients | | |
| TC-31 | S10 | F5 | U | Long-press a priority patient → Remove priority | Flag removed; patient moves back behind priority patients | | |
| TC-32 | S10 | F5 | U | Choose "Other" with empty text → Flag | "Describe the reason" error; nothing saved | | |
| TC-33 | S11 | F5 | U | Call next with an empty "Now serving" | First waiting token becomes "With the doctor"; removed from waiting | | |
| TC-34 | S11 | F3, F5 | C, U | Call next again | Previous patient → Completed and a visit appears in their S14 history; next patient called | | |
| TC-35 | S11 | F4 | C | Call next while patient2 (app) is 1st–3rd in queue | patient2 receives "Your turn is near" notification once (not repeated) | | |
| TC-36 | S11 | F5 | U | "Complete only" with nobody waiting | Now serving clears; button reads "Queue is empty" | | |
| TC-37 | S12 | F5 | U | No-shows → Close a token → Mark no-show | Token moves to "Closed tokens"; removed from queue | | |
| TC-38 | S12 | F5 | U | Closed tokens → Re-queue | Patient back at the end of the waiting list | | |
| TC-39 | S12 | F5 | D | Delete a token issued in error → confirm | Appointment deleted; capacity count −1 | | |

### Module 3: Patient records & access control (Weerasinghe W.D.S.U, S13–S17)

| TC | Screen | Req | CRUD | Steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|---|---|
| TC-40 | S13 | F3, F5 | C | Patients → New patient → fill required fields → Register | Record created; appears in list; audit "create" entry | | |
| TC-41 | S13 | F3 | R | Type NIC `199512345678` | Date of birth and gender filled automatically from NIC | | |
| TC-42 | S13 | F3 | R | Register with an NIC that already exists | Error "A patient with NIC … is already registered" | | |
| TC-43 | S13 | NF1 | C | Invalid NIC `12345` / mobile `12345` | Field errors; form not submitted | | |
| TC-44 | S14 | F3 | R | Open a seeded patient | Details, allergy warning banner, visit history, audit trail | | |
| TC-45 | S14 | F3 | C | Add visit → diagnosis → Save | Visit appears at top of history | | |
| TC-46 | S14 | F3 | U | Tap a visit → change notes → Save | Notes updated | | |
| TC-47 | S14 | F3 | D | Delete a visit → confirm | Visit removed | | |
| TC-48 | S15 | F3, NF1 | U | Edit → change mobile → Save | Profile shows new number; audit "update · Changed: phone" | | |
| TC-49 | S15 | F3 | U | Edit → change NIC to another patient's NIC | Error "NIC … belongs to …"; nothing saved | | |
| TC-50 | S16 | F3, NF1 | U, C | Archive → "Duplicate record" → confirm | Record leaves Active list, shown under Archived; audit "archive" | | |
| TC-51 | S16 | F3, NF1 | U | Archived record → Restore with empty note | "A note is required"; with a note, record restored + audit entry | | |
| TC-52 | S17 | NF1 | C | Register as patient with valid details | Account created; patient home opens; verification email sent | | |
| TC-53 | S17 | NF1 | C | Register as staff with a wrong access code | "The staff access code is not valid."; no account remains | | |
| TC-54 | S17 | NF1 | R | Log in with wrong password | "Email or password is incorrect." | | |
| TC-55 | S17 | NF1 | R | Log in as staff vs patient | Staff → dark-green staff home (Queue/Patients/Schedule); patient → patient home | | |
| TC-56 | S17 | NF1 | U | Type email → Forgot password? | "Password reset link sent" and email received | | |
| TC-57 | Rules | NF1 | R | (Rules Playground in console) patient reads another patient's appointment | **Denied** | | |

### Module 4: Schedule, notifications & accessibility (Nethmini K, S18–S22)

| TC | Screen | Req | CRUD | Steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|---|---|
| TC-58 | S18 | F1 | C | Schedule → New session → fill → Create | Appears on that day in S19; patients can book it in S02 | | |
| TC-59 | S18 | F1 | R | Create a session for the same doctor overlapping an existing one | "Time clash" warning with option to continue | | |
| TC-60 | S18 | F1 | C | End time before start time | "End time must be after start time" | | |
| TC-61 | S19 | F1 | R | Schedule tab → next/previous week | Week range changes; sessions grouped by day; booked/capacity shown | | |
| TC-62 | S19 | F4 | R | Patient → Notifications | Booking confirmation, reminders, near-turn alerts, newest first, unread highlighted | | |
| TC-63 | S19 | F4 | U | Tap a notification / Mark all as read | Unread dot disappears; badge count drops | | |
| TC-64 | S19 | F4 | D | Swipe a notification left | Notification removed | | |
| TC-65 | S20 | F1, F4 | U, C | Edit a session with bookings → change start time → Save | Warning "N patients will be notified"; booked patients get "Clinic changed" notification; their appointment shows new time | | |
| TC-66 | S20 | F4 | U | Change reminder to 2 hours before | Saved; booked appointments' reminder window updated | | |
| TC-67 | S20 | F1 | D | Delete a session with no bookings | Session removed. (Delete icon hidden when bookings exist) | | |
| TC-68 | S21 | F4 | U, C | Cancel a session with 2 app bookings → "Doctor unavailable" | Session shown struck through; both appointments Cancelled; both patients notified | | |
| TC-69 | S22 | NF3 | U | Settings → සිංහල → Save | Patient screens switch to Sinhala; persists after logout/login | | |
| TC-70 | S22 | NF3 | U | Settings → தமிழ் → Save | Patient screens in Tamil | | |
| TC-71 | S22 | NF2 | U | Largest "A" → Save | All text larger app-wide; preview grows before saving | | |
| TC-72 | S22 | NF2 | U | High contrast on → Save | Black/white theme with thicker borders | | |
| TC-73 | Reminder | F4 | C | Book a session within 24 h with reminder on, close and reopen app | One "Reminder: …" notification is created (not duplicated on next open) | | |

### Non-functional checks

| TC | Req | Steps | Expected result | Actual result | Status |
|---|---|---|---|---|---|
| TC-74 | NF4 | Time from staff "Call next" to patient screen update (stopwatch, 5 trials) | ≤ 2 s each | | |
| TC-75 | NF4 | Time to open S07 live queue (5 trials) | ≤ 2 s | | |
| TC-76 | NF1 | Turn on airplane mode on patient phone with S07 open | Last known position stays visible (offline cache); updates on reconnect | | |
| TC-77 | NF2 | Measure buttons with Android "Layout bounds" / screenshots | All tappable controls ≥ 48 dp high | | |

---

## 2. Automated tests (`flutter test`, test/logic_test.dart)

| AT | Covers | Req |
|---|---|---|
| AT-01 | Token label format `A-052` | F1, F5 |
| AT-02 | Capacity check blocks overbooking | F1 |
| AT-03 | Patients-ahead calculation | F2 |
| AT-04 | Estimated wait time | F2 |
| AT-05 | Waiting → near turn → your turn state | F2, F4 |
| AT-06 | Normal patient appended to queue | F5 |
| AT-07 | Priority placed after other priority patients | F5 |
| AT-08 | Priority with none existing goes first | F5 |
| AT-09 | No duplicate queue entries | F5 |
| AT-10 | Move up/down with edge handling | F2, F5 |
| AT-11 | NIC validation (old/new formats) | F3, NF1 |
| AT-12 | Mobile number validation | F3 |
| AT-13 | Email/password validation | NF1 |
| AT-14 | DOB + gender derived from NIC | F3 |
| AT-15 | Clinic time-clash detection | F1 |
| AT-16 | Date keys / week start / time parsing | F1 |
| AT-17 | Strings exist in EN, SI and TA | NF3 |
| AT-18 | NIC must encode a real birth date (not day 999, not a future year) | NF1 |
| AT-19 | Person names: letters (incl. Sinhala/Tamil), 3-80 chars, no digits | NF1 |
| AT-20 | New password: 8+ chars with a letter and a number; sign-in only requires non-empty | NF1 |
| AT-21 | Optional mobile, free-text length limits, date of birth range | F3 |
| AT-22 | A clinic that has ended cannot be booked | F1 |
| AT-23 | Avatar initials from a name | F3 |
| AT-24 | Password strength score rises with character variety | NF1 |
| AT-25 | Skipping a patient moves them back 3 places, clamped at the end of the queue | F5 |

---

## 3. Traceability matrix (requirement → prototype → implementation → tests)

| Req | Description | M02 prototype screens | Implementation (lib/…) | Test cases |
|---|---|---|---|---|
| F1 | Book via phone, in-person, digital/assisted | S01–S06, S18–S20 | `features/patient/book_*`, `reschedule_screen`, `cancel_appointment_screen`, `reception/walk_in_screen` (phone/assisted), `schedule/create_session_screen` · `services/booking_service.dart` | TC-01–15, 28, 58–61, 65–67 · AT-01, 02, 15, 16 |
| F2 | Real-time queue position & wait for patients and staff | S07a/b/c, S08, S10 | `patient/live_queue_screen`, `reception/queue_dashboard_screen` · Firestore snapshot listeners on `sessions/{id}.waitingIds` | TC-16–18, 21–22, 30, 74 · AT-03–05, 10 |
| F3 | Centralised patient record & appointment database | S13–S16 | `features/records/*` · `services/patient_service.dart` · visits written on Call next | TC-34, 40–51 · AT-11, 12, 14 |
| F4 | Automated reminders / notifications | S03, S07b, S19–S21 | `schedule/notification_centre_screen`, `BookingService.sendDueReminders`, `QueueService._notifyQueueChanges`, `ScheduleService.update/cancel` | TC-09, 17, 20, 35, 62–68, 73 · AT-05 |
| F5 | Staff digitally register & update queue in real time | S06, S08–S13 | `features/reception/*` · `services/queue_service.dart` | TC-15, 21–39, 40 · AT-06–10 |
| NF1 | Data security & confidentiality | S15–S17 | `firestore.rules`, `auth/*`, audit log in `patient_service.dart`, staff access code | TC-43, 48–57, 76 · AT-11, 13 |
| NF2 | Simple, accessible for elderly users | S01, S04, S07c, S22 | Design system (`core/theme.dart`: 48 dp targets, 16–18 sp text), step indicator, large cards, text size, high contrast | TC-02, 11, 18, 71, 72, 77 |
| NF3 | Sinhala, Tamil, English | S22 | `core/strings.dart`, language on login + settings | TC-69, 70 · AT-17 |
| NF4 | Queue queries ≤ 2 s | S07a | Firestore real-time listeners, single-document queue read, offline cache | TC-74, 75 |
