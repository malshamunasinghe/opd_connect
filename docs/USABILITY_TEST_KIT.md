# Usability Testing Kit: OPD Connect working app (Milestone 03)

This kit lets you run the usability test on the **installed APK** with at least 5 real or proxy users, and record the results in a way that can be compared with the Milestone 02 prototype test.

> **Integrity note.** Every number in your report's results section must come from sessions you actually ran. The tables at the end are **blank on purpose**. Fill them from your own recordings and forms.

---

## 1. Plan

| Item | Plan |
|---|---|
| Goal | Check that real users can complete the core tasks on the working app, and find usability problems that only show up with real data, real timing and a real phone. |
| Method | Moderated task-based test, think-aloud, in person on an Android phone (screen recorded with Android's built-in recorder, audio on). |
| Participants | **Minimum 5.** Suggested: P1 patient 18–30, P2 patient 46–60, P3 patient 60+ (Harmanis persona proxy), P4 & P5 reception/nursing staff or proxy (given a written role card). If possible use **new** people, not the M02 participants, so learning from the prototype doesn't skew results. Record why each is representative. |
| Devices | One phone logged in as patient, one phone/emulator logged in as staff, so the facilitator can drive queue changes during patient tasks. |
| Data prepared | Demo data loaded; a patient account per participant (or one shared test account reset between sessions); 3–4 dummy bookings ahead in today's queue so the live-queue states can be shown. |
| Duration | 20–30 minutes per session. |
| Roles | Facilitator (reads tasks, doesn't help), note-taker (times, errors, quotes), operator (staff phone: calls next). Rotate so every member facilitates at least one session; the viva asks about the results. |
| Ethics | Signed consent (below) before recording. Participants may stop at any time. No real health data is entered. Use test NICs. |

### Metrics (same as M02 so results can be compared)
- **Task success** (completed unassisted = 1, assisted or failed = 0)
- **Time on task** (from end of reading the scenario to reaching the success state)
- **Errors** (wrong taps or paths before recovery)
- **SEQ**: Single Ease Question after each task, 1 (very difficult) to 7 (very easy)
- **SUS**: System Usability Scale at the end (score 0–100; 68 = average)
- **Qualitative**: think-aloud quotes, observed hesitation, post-test comments

### Stopping rule
If a participant is stuck for **2 minutes**, mark the task failed, note where they were stuck, and move on.

---

## 2. Tasks

Patient tasks (P1–P3; staff participants may also try T1–T2):

| Task | Scenario read aloud | Req | Success criterion | Target |
|---|---|---|---|---|
| T1 | "You need to see a doctor at the General OPD in Negombo hospital on the next available day. Book an appointment." | F1 | Reaches S03 with a token | 100%, ≤ 90 s |
| T2 | "You are now at the hospital. Find out how many people are ahead of you and roughly how long you will wait." | F2 | States both numbers correctly from S07 | 100%, ≤ 30 s |
| T3 | "Something came up. Move your appointment to a different day." | F1 | New date visible in My appointments | 80%, ≤ 60 s |
| T4 | "Let the reception know you have arrived." | F2 | Taps "I'm at the hospital" | 80%, ≤ 30 s |
| T5 | (Operator calls the participant's token.) "Tell me what the phone is telling you to do now." | F2, F4 | Notices near-turn / your-turn state unprompted and explains it | 100% |
| T6 | "Turn off the reminder for your appointment." | F4 | Reminder switch off on S03 | 80%, ≤ 45 s |
| T7 | "Change the app to Sinhala (or Tamil) and make the text bigger." | NF2, NF3 | Both saved | 80%, ≤ 60 s |
| T8 | "You can't go any more. Cancel the appointment." | F1 | Status Cancelled with a reason | 80%, ≤ 45 s |

Staff tasks (P4–P5; role card: "You are a reception officer at DGH Negombo OPD this morning."):

| Task | Scenario | Req | Success criterion | Target |
|---|---|---|---|---|
| T9 | "A patient with NIC 851234567V walked in. Check them in and give them a number." | F5 | Token issued for that record | 80%, ≤ 75 s |
| T10 | "The doctor is ready. Call the next patient." | F5 | Queue advances | 100%, ≤ 20 s |
| T11 | "The elderly man in the queue (Harmanis) should be seen sooner. Give him priority." | F5 | Priority flagged with reason | 80%, ≤ 45 s |
| T12 | "Token X didn't come when called. Close it." | F5 | Marked no-show | 80%, ≤ 45 s |
| T13 | "Register a new patient: Kumari Perera, NIC 199267812345, mobile 0779988776." | F3 | Record visible in Patients | 80%, ≤ 90 s |
| T14 | "Find Nimali Silva's last visit and add a note 'BP normal'." | F3 | Note saved on a visit | 80%, ≤ 60 s |
| T15 | "Dr. Fernando is sick tomorrow. Cancel tomorrow's Medical Clinic and make sure patients know." | F4 | Session cancelled (notifications sent) | 80%, ≤ 60 s |

---

## 3. Facilitator script

> "Thank you for helping us. We are testing the **app**, not you. There are no wrong answers. If something is confusing, that is exactly what we need to find. Please **think aloud**: say what you are looking for and what you expect to happen. I can't help during the tasks, but you can stop at any time. We'll record the screen and your voice only to review our notes, and the recording will be deleted after marking. Is that OK?"

For each task: read the scenario → start the timer → stay quiet → stop when the success state is reached or after 2 minutes → ask the SEQ: *"Overall, how easy or difficult was that task, from 1 very difficult to 7 very easy?"*

After all tasks: SUS form → then ask:
1. What was the most confusing moment?
2. What did you like most?
3. Would you use this instead of the current counter system? Why / why not?
4. (Patients 60+) Was the text large enough? Did the colours help?

---

## 4. Consent form (print one per participant)

> **OPD Connect usability study: IT3060 HCI, SLIIT, Group WE_81**
> I agree to take part in a usability test of a student-built mobile app. I understand that:
> - the session takes about 30 minutes and my screen and voice will be recorded;
> - only test data is used; I will not enter my real medical information;
> - the recording is used only for this coursework and deleted after marking;
> - I can stop at any time without giving a reason.
>
> Participant name: ____________________ Signature: ____________ Date: ________
> Age group: ☐ 18–30 ☐ 31–45 ☐ 46–60 ☐ 60+  Role: ☐ Patient ☐ Family/caregiver ☐ OPD staff
> Smartphone use: ☐ Daily ☐ Sometimes ☐ Rarely

---

## 5. SUS questionnaire (1 = strongly disagree … 5 = strongly agree)

1. I think that I would like to use this app frequently.
2. I found the app unnecessarily complex.
3. I thought the app was easy to use.
4. I think that I would need the support of a technical person to be able to use this app.
5. I found the various functions in this app were well integrated.
6. I thought there was too much inconsistency in this app.
7. I would imagine that most people would learn to use this app very quickly.
8. I found the app very cumbersome to use.
9. I felt very confident using the app.
10. I needed to learn a lot of things before I could get going with this app.

**Scoring:** odd items: (response − 1); even items: (5 − response); sum × 2.5.
Offer a Sinhala/Tamil verbal translation for participants who prefer it, and note that you did.

---

## 6. Recording sheets (fill in from your sessions)

### 6.1 Participants
| ID | Age group | Role | Real / proxy | Phone experience | Language used | Date | Facilitator |
|---|---|---|---|---|---|---|---|
| P1 | | | | | | | |
| P2 | | | | | | | |
| P3 | | | | | | | |
| P4 | | | | | | | |
| P5 | | | | | | | |

### 6.2 Task results (S = success 1/0, T = seconds, E = errors, Q = SEQ)
| Task | P1 S/T/E/Q | P2 S/T/E/Q | P3 S/T/E/Q | P4 S/T/E/Q | P5 S/T/E/Q | Success % | Mean time | Mean SEQ | Target met? |
|---|---|---|---|---|---|---|---|---|---|
| T1 | | | | | | | | | |
| T2 | | | | | | | | | |
| T3 | | | | | | | | | |
| T4 | | | | | | | | | |
| T5 | | | | | | | | | |
| T6 | | | | | | | | | |
| T7 | | | | | | | | | |
| T8 | | | | | | | | | |
| T9 | | | | | | | | | |
| T10 | | | | | | | | | |
| T11 | | | | | | | | | |
| T12 | | | | | | | | | |
| T13 | | | | | | | | | |
| T14 | | | | | | | | | |
| T15 | | | | | | | | | |

### 6.3 SUS
| | Q1 | Q2 | Q3 | Q4 | Q5 | Q6 | Q7 | Q8 | Q9 | Q10 | SUS score |
|---|---|---|---|---|---|---|---|---|---|---|---|
| P1 | | | | | | | | | | | |
| P2 | | | | | | | | | | | |
| P3 | | | | | | | | | | | |
| P4 | | | | | | | | | | | |
| P5 | | | | | | | | | | | |
| **Mean** | | | | | | | | | | | |

Compare against the M02 prototype mean SUS of **79.5**, and explain any difference (e.g. real loading delays, real data, typing on a phone).

### 6.4 Usability issue log (same severity scale as M02)
High = could not complete / needed help · Medium = completed with delay, confusion or wrong path · Low = cosmetic/preference

| ID | Issue observed | Screen | Participants affected | Severity | Evidence (quote/time) | Fix made / planned | Status (Fixed / Planned) |
|---|---|---|---|---|---|---|---|
| M3-U1 | | | | | | | |
| M3-U2 | | | | | | | |

After fixing an issue, re-test it with at least one participant and note the result. That is the "evidence of issues found and addressed" the marking scheme asks for.

### 6.5 Milestone 02 issues: verify the fixes in the working app
| M02 issue | Fix implemented in the app | Where | Re-tested? Result |
|---|---|---|---|
| U1 booking confirmation unclear | Green tick, "Booking confirmed", booking reference, full summary | S03 | |
| U2 back navigation / steps unclear | "Step 1 / 3" indicator + progress bar; Back button in review sheet | S01–S02 | |
| U3 Sinhala text hard to read | 16 sp minimum body text; Noto Sans family (Android Noto Sinhala/Tamil fallback); text-size setting | All / S22 | |
| U4 scroll content not discoverable | Extra bottom padding so the next card peeks above the fold | S02, lists | |
| U5 no tap feedback | Material ripple on all controls; buttons show a spinner while saving | All | |
| U6 users wanted wait time | Estimated wait in minutes beside patients-ahead | S07 | |
