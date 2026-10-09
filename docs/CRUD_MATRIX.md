# CRUD matrix per member

Each member owns separate screens and separate services, so each has its own CRUD operations
(the requirement is at least two per member). Queue and Clinic are two different modules with two
different owners and two different service classes.

## P.A.J. Sithmini (IT23671874) - Queue module, `lib/services/queue_service.dart`

| Screen | C | R | U | D | Where in the code |
|---|---|---|---|---|---|
| S08 Live queue console | | READ sessions and the live queue | UPDATE queue order, check-in flag, skip, recall, delay, pause | | `QueueService.sessionsOn`, `sessionAppointments`, `move`, `setArrived`, `skip`, `recall`, `setDelay`, `setPaused` |
| S09 Walk-in / phone booking | CREATE appointment + token | READ patient by NIC / mobile | | | `QueueService.findPatient`, `walkIn` |
| S10 Priority | | | UPDATE priority + queue position | | `QueueService.setPriority` |
| S11 Call next | CREATE visit record + notifications | READ current / next patient | UPDATE status of both patients, queue head | | `QueueService.callNext`, `completeCurrent` |
| S12 No-shows | | READ missed patients | UPDATE mark no-show, re-queue | **DELETE** a token issued in error | `QueueService.markNoShow`, `requeue`, `deleteToken` |
| Messages to patients | CREATE announcement notifications | | | | `QueueService.broadcast` |

Create, Read, Update and Delete are all covered by this module.

## Nethmini K (IT23669130) - Clinic module, `lib/services/schedule_service.dart` and `hospital_service.dart`

| Screen | C | R | U | D | Where in the code |
|---|---|---|---|---|---|
| S18 New clinic session | CREATE session | READ clashes (same doctor / room, same time) | | | `ScheduleService.conflicts`, `create` |
| S19 Weekly schedule | | READ the week's sessions (live) | | | `ScheduleService.week` |
| S20 Edit session | | READ clashes | UPDATE session + patients' copies, notifies booked patients | **DELETE** a session with no bookings | `ScheduleService.update`, `delete` |
| S21 Cancel session | CREATE cancellation notifications | | UPDATE session + every booking to cancelled | | `ScheduleService.cancel` |
| S19 Notification centre | | READ notifications | UPDATE mark read / all read | **DELETE** notification (swipe, or clear read) | `ScheduleService.notifications`, `markRead`, `markAllRead`, `deleteNotification`, `deleteMany` |
| S22 Settings | | READ saved settings | UPDATE language, text size, contrast | | `ScheduleService.saveSettings` |
| Hospitals | CREATE hospital | READ hospitals | UPDATE hospital (name copied to its sessions) | DELETE hospital with no sessions | `HospitalService.create`, `update`, `delete` |

Create, Read, Update and Delete are all covered by this module.

## Lakmali M.A.D.M (IT23679344) - Patient journey, `lib/services/booking_service.dart`

| Screen | C | R | U | D |
|---|---|---|---|---|
| S01 Hospital | | READ hospitals | UPDATE last-used hospital | |
| S02 Date / time + details | CREATE appointment (transaction) | READ open sessions | UPDATE session counters | |
| S03 Confirmation | | READ appointment | UPDATE reminder on / off | |
| S04 My appointments | | READ appointments | | DELETE a past entry from the list |
| S05 Reschedule | | READ sessions | UPDATE appointment + both sessions | |
| S06 Cancel | | READ appointment | UPDATE status + release the place | |
| S07 Live queue | CREATE visit rating | READ live queue | UPDATE "I'm at the hospital" | |

## Weerasinghe W.D.S.U (IT23685802) - Records and access, `auth_service.dart`, `patient_service.dart`, `profile_service.dart`

| Screen | C | R | U | D |
|---|---|---|---|---|
| S17 Register / login | CREATE account + profile + health record | READ credentials and role | UPDATE password reset | |
| S13 Register patient | CREATE patient record + audit entry | READ duplicate NIC check | | |
| S14 Patient profile / visits | CREATE visit | READ visit history | UPDATE diagnosis / notes | DELETE a visit entered by mistake |
| S15 Edit patient | | READ record | UPDATE details + audit entry | |
| S16 Archive / restore | CREATE audit note | READ archived records | UPDATE archive flag | (records are archived, never deleted) |
| Profile | | READ own profile | UPDATE own details, change password | |
