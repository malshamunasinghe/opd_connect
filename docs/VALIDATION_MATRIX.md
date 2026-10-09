# Validation matrix (per member module)

Every input is checked **twice**: in the app (instant message under the field, from
`lib/core/logic.dart` -> `Validators`) and again in the service / Firestore security rules,
so bad data cannot get in even if a request does not come from the app.

Shared rules (`Validators`): name 3-80 letters (Sinhala/Tamil ok, no digits) · mobile `0` + 9 digits ·
NIC old (9 digits + V/X) or new (12 digits) **and** must encode a real birth date · e-mail format ·
new password 8-64 chars with a letter and a number, no spaces · free text with a maximum length.

## Lakmali M.A.D.M (IT23679344) - Patient journey S01-S07

| Screen | Field | Rule |
|---|---|---|
| S01 Hospital | Search | optional, filters name / town / district |
| S02 Review | Patient name | required, letters only, 3-80 |
| | Mobile / contact | required, `07XXXXXXXX` |
| | NIC | required for "Myself" (valid + real date), optional for a relative |
| | Age | required, 0-120 |
| | Gender | required |
| | Relationship | required when booking for someone else |
| | Reason for visit | optional, max 200 |
| S02 Booking | Clinic already finished | blocked |
| | Same clinic twice | blocked (per person) |
| | Overlapping times on the same day | blocked (account holder) |
| | Clinic full / cancelled | blocked inside a transaction |
| S05 Reschedule | Same session, not "waiting", target full / ended | blocked |
| S06 Cancel | Reason | required; "Other" needs 3-150 chars |
| S07 Live queue | Rating | 1-5 stars, once per visit, comment max 300 (rules enforce) |

## P.A.J. Sithmini (IT23671874) - Queue S08-S12

| Screen | Field | Rule |
|---|---|---|
| S09 Walk-in | Patient name | required, letters only, 3-80 |
| | Mobile | optional, `07XXXXXXXX` |
| | Duplicate token for the same person | blocked |
| | Clinic day in the past | blocked |
| | Priority reason | required when priority is on |
| S10 Priority | "Other" reason | 3-100 chars |
| S08 Queue | Call next while paused / cancelled | blocked |
| | Call a patient who is no longer waiting | blocked (list refreshed) |
| | Delay | 0-240 minutes |
| | Pause | reason required |
| | Announcement | 5-200 chars |
| Check-in desk | Search | token, OPD-reference, QR text, NIC, mobile, name |

## Weerasinghe W.D.S.U (IT23685802) - Records and access S13-S17

| Screen | Field | Rule |
|---|---|---|
| S17 Register | Name / mobile / e-mail / NIC | shared rules above |
| | Password | 8+ with a letter and a number, strength meter, confirm must match |
| | Staff / admin code | required, 4-40 chars, checked by security rules |
| | Terms | must be ticked |
| S17 Login | E-mail / password | format / required (older short passwords still allowed) |
| S13 / S15 Patient form | Name, NIC, mobile | shared rules; NIC must not already exist |
| | Date of birth | required, not in the future, max 120 years |
| | DOB and gender vs NIC | must match |
| | Address / allergies / emergency contact | max 200 / 200 / 100 |
| S14 Visit | Department | required, 3-50 |
| | Doctor | optional, letters only |
| | Diagnosis / notes | max 300 / 500 |
| S16 Archive / restore | Note | required for restore; "Other" required; max 200 |
| Profile | Edit profile | same rules as the patient form; NIC and e-mail locked |
| | Change password | current password re-checked, new password rules, must differ |

## Nethmini K (IT23669130) - Schedule, notifications, settings S18-S22

| Screen | Field | Rule |
|---|---|---|
| S18 / S20 Session | Hospital | required (add one from the form if none exist) |
| | Department / doctor / room | 3-50 / letters 3-80 / max 30 |
| | Start / end | end after start, at least 30 minutes |
| | Start time already passed | blocked |
| | Capacity | 1-300, not below the number already booked |
| | Capacity x average minutes | must fit in the session hours |
| | Avg. minutes | 2-60 |
| | Token prefix | 1-2 letters |
| | Notes | max 300 |
| | Time clash (doctor / room) | warning with "Create anyway" |
| S21 Cancel session | Reason | required; "Other" required; detail max 200 |
| Hospitals | Name | 5-80, unique |
| | District | required (25 districts) |
| | Address | 3-120 |
| | Telephone | optional, `0` + 9 digits |
| S22 Settings | Language, text size, contrast | fixed choices only |
