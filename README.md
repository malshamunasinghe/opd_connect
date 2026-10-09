# OPD Connect

**Appointment booking and queue management for Sri Lankan government hospital OPDs.**
IT3060 Human Computer Interaction, Milestone 03, Group WE_81 (SLIIT, 2026).

OPD Connect is the working Android app built from our Milestone 02 Figma prototype. Patients book OPD clinic appointments and watch their place in the queue live on their phone. Reception staff check in walk-ins, call the next patient, flag priority cases and keep central patient records. The whole patient side runs in English, Sinhala or Tamil, with large-text and high-contrast modes.

| | |
|---|---|
| Platform | Android (Flutter 3.47, Dart 3.13) |
| Backend | Firebase Authentication + Cloud Firestore (real-time listeners, offline cache) |
| State | `provider` |
| Screens | 22 interfaces (S01–S22) across 4 modules, each with ≥ 2 CRUD operations |
| Tests | 25 automated unit tests (`flutter test`) + manual functional test cases in `docs/` |

---

## Architecture (frontend and backend)

| Layer | What it is | Where it lives |
|---|---|---|
| **Frontend** | Flutter UI: screens, theme, shared widgets, localisation | `lib/features/` (auth, patient, reception, records, schedule), `lib/core/`, `lib/app.dart`, `lib/main.dart` |
| **Business logic / data access** | Services that talk to Firebase (auth, booking, queue, schedule, patients, seed data) | `lib/services/`, `lib/models/` |
| **Backend** | Firebase Authentication + Cloud Firestore, hosted by Google (no separate server) | `firestore.rules`, `firebase.json`, `lib/firebase_options.dart` |

The screens never touch Firestore directly. They call the services in `lib/services/`, which read and write Firestore. Firestore pushes real-time updates back to the screens, which is how the live queue works.

---

## 1. Prerequisites

1. **Flutter SDK 3.47 or newer**: https://docs.flutter.dev/get-started/install/windows
   Add `C:\flutter\bin` to your PATH and run `flutter doctor`.
2. **Android Studio** (for the Android SDK + an emulator), or a real Android phone with USB debugging on.
   Then run `flutter doctor --android-licenses` and accept all licenses.
3. **Node.js** (for the Firebase CLI): https://nodejs.org
4. A **Google account** for Firebase. The free Spark plan is enough.

## 2. Firebase setup (one time, about 10 minutes)

1. Go to https://console.firebase.google.com and click **Add project** (e.g. `opd-connect-we81`).
2. **Authentication** → *Get started* → enable **Email/Password**.
3. **Firestore Database** → *Create database* → choose a location (e.g. `asia-south1`) → start in **production mode**.
4. Install the CLIs and connect the app:
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   cd opd_connect
   flutterfire configure --project=<your-project-id> --platforms=android
   ```
   This **overwrites `lib/firebase_options.dart`** and adds `android/app/google-services.json`.
5. **Deploy the security rules**:
   ```bash
   firebase use <your-project-id>
   firebase deploy --only firestore:rules
   ```
   (Or paste `firestore.rules` into *Firestore → Rules* and click *Publish*.)
6. **Create the staff access codes.** In *Firestore → Data*:
   - Start collection `config` → document ID `access`
   - Field `staffCode` (string), e.g. `OPD-STAFF-2026`
   - Field `adminCode` (string), e.g. `OPD-ADMIN-2026`

   Staff/admin sign-up requires this code. The security rules check it, and the app can never read it.

## 3. Run the app

```bash
cd opd_connect
flutter pub get
flutter run            # with an emulator running or a phone connected
```

### First-run walkthrough
1. **Create a staff account**: *Create an account* → *OPD staff* → enter the `staffCode`.
2. As staff, open **Settings → Load demo data**. This adds 4 hospitals, 2 weeks of clinic sessions and 5 sample patients.
3. Sign out and **create a patient account** (with a valid NIC, e.g. `199512345678`).
4. Patient: **Book appointment** → hospital → clinic/day → confirm → token (e.g. `A-001`).
5. On a second device or emulator, sign in as staff → **Queue** tab → pick today's session → **Call next**.
   The patient's live queue screen updates by itself (waiting → near turn → your turn).

## 4. Build the installable APK

```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`. Copy it to a phone and install it (allow *Install unknown apps*).
The release build is signed with the debug key, which is fine for coursework and demos.

## 5. Run the tests

```bash
flutter test            # 17 unit tests: queue order, wait estimate, tokens, NIC/phone validation, scheduling, translations
flutter analyze         # static analysis (should report: No issues found)
```

---

## 6. Project structure

```
lib/
  main.dart                 Firebase init, offline persistence
  app.dart                  Auth gate + role-based routing (S17), app-wide settings
  core/                     Design system (theme, widgets), strings (EN/SI/TA), pure logic
  models/                   Firestore data classes
  services/                 All Firestore reads/writes, one service per module
  features/
    auth/                   S17                     Weerasinghe W.D.S.U
    patient/                S01–S07                 Lakmali M.A.D.M
    reception/              S08–S12                 P.A.J. Sithmini
    records/                S13–S16                 Weerasinghe W.D.S.U
    schedule/               S18–S22                 Nethmini K
test/logic_test.dart        Automated functional tests
firestore.rules             Role-based security rules (NF1)
docs/                       Test cases, traceability matrix, usability test kit, report guide
```

## 7. Screens and owners

| ID | Screen | Owner | CRUD |
|---|---|---|---|
| S01 | Book: hospital selection | Lakmali | R hospitals · U last-used hospital |
| S02 | Book: clinic day & time + review | Lakmali | R sessions · C appointment · U session queue |
| S03 | Booking confirmation & token | Lakmali | R appointment · U reminder on/off |
| S04 | My appointments (upcoming/past) | Lakmali | R appointments · D past entry |
| S05 | Reschedule appointment | Lakmali | R sessions · U appointment + both sessions |
| S06 | Cancel appointment (reason) | Lakmali | R appointment · U status + release place |
| S07a/b/c | Live queue: waiting / near turn / your turn | Lakmali | R live queue · U "I'm at the hospital" |
| S08 | Reception queue dashboard | Sithmini | R queue · U order / arrived |
| S09 | Walk-in check-in & token | Sithmini | R patient lookup · C appointment/token |
| S10 | Priority flag & reorder | Sithmini | R flag · U priority + reason / remove |
| S11 | Call next patient | Sithmini | R queue · U statuses · C visit + notifications |
| S12 | No-show & close token | Sithmini | R tokens · U no-show / re-queue · D token |
| S13 | New patient registration | Weerasinghe | R duplicate NIC · C patient + audit |
| S14 | Patient profile & visit history | Weerasinghe | R profile/visits · C/U/D visit |
| S15 | Edit patient details | Weerasinghe | R record · U record + audit |
| S16 | Archive / restore with audit note | Weerasinghe | R audit · U archived · C audit |
| S17 | Login, registration, roles | Weerasinghe | C account/profile · R role · U password reset |
| S18 | Create clinic session | Nethmini | R clash check · C session |
| S19 | Weekly schedule + notification centre | Nethmini | R schedule/notifications · U read · D notification |
| S20 | Edit session & reminder settings | Nethmini | R session · U session · C change notices · D unused session |
| S21 | Cancel session + auto-notify | Nethmini | U session/appointments · C notifications |
| S22 | Language, text size, contrast | Nethmini | R settings · U settings |

## 8. Troubleshooting

| Problem | Fix |
|---|---|
| App shows "Firebase setup required" | Run `flutterfire configure` (step 2.4) and rebuild. |
| "You do not have permission" | Rules not deployed (step 2.5), or a patient account is trying to use staff features. |
| "The staff access code is not valid" | Create `config/access` with `staffCode` (step 2.6) and type it exactly. |
| No hospitals when booking | Sign in as staff → Settings → **Load demo data**. |
| Gradle / license errors | `flutter doctor --android-licenses`, and install *Android SDK Command-line Tools* in Android Studio → SDK Manager. |
