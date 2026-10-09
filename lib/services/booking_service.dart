import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/logic.dart';
import '../models/app_notification.dart';
import '../models/appointment.dart';
import '../models/clinic_session.dart';
import '../models/hospital.dart';
import '../models/user_profile.dart';
import 'db.dart';

/// Patient journey module S01-S07 (F1, F2, F4).
/// Owner: Lakmali M.A.D.M (IT23679344)
class BookingService {
  // ---------------------------------------------------------------- S01
  /// READ - hospitals available for booking.
  static Stream<List<Hospital>> hospitals() => Db.hospitals
      .snapshots()
      .map((q) => q.docs.map(Hospital.fromDoc).toList()..sort((a, b) => a.name.compareTo(b.name)));

  /// UPDATE - remember the hospital the patient picked so it is listed first
  /// next time (fewer decisions for repeat visitors - NF2).
  static Future<void> rememberHospital(String uid, String hospitalId) =>
      Db.users.doc(uid).update({'lastHospitalId': hospitalId});

  // ---------------------------------------------------------------- S02
  /// READ - upcoming, active sessions at a hospital. Only real clinic days
  /// are returned (Variant B: day cards, not a full calendar).
  static Stream<List<ClinicSession>> openSessions(String hospitalId) {
    return Db.sessions.where('hospitalId', isEqualTo: hospitalId).snapshots().map((q) {
      final today = DateKeys.dayOnly(DateTime.now());
      return q.docs
          .map(ClinicSession.fromDoc)
          .where((s) => s.isActive && !s.date.isBefore(today) && !DateKeys.hasEnded(s.date, s.endTime))
          .toList()
        ..sort((a, b) {
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : a.startTime.compareTo(b.startTime);
        });
    });
  }

  /// READ - every clinic running today at any hospital that is still open
  /// (not cancelled, not finished). Used by the home screen.
  static Stream<List<ClinicSession>> clinicsToday() => Db.sessions
      .where('dateKey', isEqualTo: DateKeys.of(DateTime.now()))
      .snapshots()
      .map((q) => q.docs
          .map(ClinicSession.fromDoc)
          .where((s) => s.isActive && !DateKeys.hasEnded(s.date, s.endTime))
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime)));

  /// READ - every clinic from today onwards at every hospital (for the
  /// "Clinics" browser). Finished and cancelled clinics are left out.
  static Stream<List<ClinicSession>> allOpenSessions() => Db.sessions
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateKeys.dayOnly(DateTime.now())))
      .snapshots()
      .map((q) => q.docs
          .map(ClinicSession.fromDoc)
          .where((s) => s.isActive && !DateKeys.hasEnded(s.date, s.endTime))
          .toList()
        ..sort((a, b) {
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : a.startTime.compareTo(b.startTime);
        }));

  /// Estimated time the patient will actually be seen if they book [session]
  /// now: clinic start + (people already booked x average consultation).
  static DateTime estimatedSeenAt(ClinicSession s) => DateKeys.startOf(s.date, s.startTime)
      .add(Duration(minutes: s.bookedCount * s.avgConsultMinutes));

  /// CREATE - books a place in [session]. Runs in a transaction so two
  /// patients can never receive the same token or overfill a session.
  /// Also UPDATES the session's counters and live queue.
  static Future<String> book({
    required UserProfile user,
    required ClinicSession session,
    required bool reminder,
    String visitReason = '',
    String? patientName,
    String? patientPhone,
    String relation = '',
    int? patientAge,
    String patientNic = '',
    String patientGender = '',
  }) async {
    if (Validators.optionalNic(patientNic) != null) {
      throw AppException('nic', Validators.optionalNic(patientNic)!);
    }
    if (patientAge != null && (patientAge < 0 || patientAge > 120)) {
      throw const AppException('age', 'Age must be between 0 and 120.');
    }
    if (visitReason.trim().length > 200) {
      throw const AppException('reason', 'The reason for the visit must be 200 characters or fewer.');
    }
    // A booking made for a relative is stored under the relative's name; it
    // is not linked to the account holder's own health record.
    final forSelf = relation.isEmpty;
    final name = (patientName ?? user.name).trim();
    final phone = (patientPhone ?? user.phone).replaceAll(' ', '');
    if (Validators.personName(name) != null) {
      throw AppException('name', Validators.personName(name)!);
    }
    if (Validators.mobile(phone) != null) {
      throw AppException('phone', Validators.mobile(phone)!);
    }
    await _guardBookable(user.uid, session, forSelf: forSelf, patientName: name);

    final sessionRef = Db.sessions.doc(session.id);
    final apptRef = Db.appointments.doc();
    late String tokenLabel;

    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(sessionRef));
      if (!s.isActive) {
        throw const AppException('cancelled', 'This clinic session has been cancelled.');
      }
      if (!QueueLogic.hasCapacity(s.bookedCount, s.capacity)) {
        throw const AppException('full', 'All places for this clinic day are taken.');
      }
      final token = s.lastToken + 1;
      tokenLabel = QueueLogic.tokenLabel(s.tokenPrefix, token);

      tx.update(sessionRef, {
        'bookedCount': s.bookedCount + 1,
        'lastToken': token,
        'waitingIds': FieldValue.arrayUnion([apptRef.id]),
      });
      tx.set(apptRef, {
        'patientUid': user.uid,
        'patientId': forSelf ? user.patientId : null,
        'patientName': name,
        'patientPhone': phone,
        'bookedFor': forSelf ? 'self' : 'other',
        'relation': relation,
        'patientAge': patientAge,
        'patientNic': Validators.normaliseNic(patientNic),
        'patientGender': patientGender,
        'sessionId': s.id,
        'hospitalId': s.hospitalId,
        'hospitalName': s.hospitalName,
        'department': s.department,
        'doctorName': s.doctorName,
        'date': Timestamp.fromDate(s.date),
        'dateKey': s.dateKey,
        'startTime': s.startTime,
        'tokenNumber': token,
        'tokenLabel': tokenLabel,
        'status': AppointmentStatus.waiting,
        'channel': 'app',
        'priority': false,
        'reminderEnabled': reminder && s.remindersEnabled,
        'reminderHoursBefore': s.reminderHoursBefore,
        'reminderSent': false,
        'arrived': false,
        'nearTurnNotified': false,
        'visitReason': visitReason.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await Db.notifications.add(AppNotification.data(
      uid: user.uid,
      title: 'Booking confirmed - $tokenLabel',
      body: '${session.department} at ${session.hospitalName} on '
          '${session.dateKey}, ${session.startTime}.',
      type: NotificationTypes.booking,
      appointmentId: apptRef.id,
    ));
    return apptRef.id;
  }

  /// Rules that apply to every new or moved booking: the clinic must not have
  /// finished, the patient must not already hold a place in it, and must not
  /// hold another active booking that overlaps it in time on the same day.
  /// [exceptAppointmentId] is the booking being rescheduled, if any.
  static Future<void> _guardBookable(
    String uid,
    ClinicSession session, {
    String? exceptAppointmentId,
    bool forSelf = true,
    String? patientName,
  }) async {
    if (!session.isActive) {
      throw const AppException('cancelled', 'This clinic session has been cancelled.');
    }
    if (DateKeys.hasEnded(session.date, session.endTime)) {
      throw const AppException('ended', 'This clinic has already finished. Please choose another day.');
    }
    final mine = await Db.appointments.where('patientUid', isEqualTo: uid).get();
    final active = mine.docs.map(Appointment.fromDoc).where((a) => a.isActive && a.id != exceptAppointmentId);
    if (forSelf) {
      if (active.any((a) => a.sessionId == session.id && a.bookedFor == 'self')) {
        throw const AppException('duplicate', 'You already have a booking for this clinic.');
      }
    } else if (active.any((a) =>
        a.sessionId == session.id &&
        a.bookedFor == 'other' &&
        a.patientName.trim().toLowerCase() == (patientName ?? '').trim().toLowerCase())) {
      throw AppException('duplicate', '${patientName ?? 'This person'} already has a booking for this clinic.');
    }
    // Overlapping times only matter for the account holder: they cannot be
    // in two clinics at once. Relatives are different people.
    if (!forSelf) return;
    for (final a in active.where((a) => a.dateKey == session.dateKey && a.bookedFor == 'self')) {
      final other = await Db.sessions.doc(a.sessionId).get();
      if (!other.exists) continue;
      final o = ClinicSession.fromDoc(other);
      if (DateKeys.overlaps(o.startTime, o.endTime, session.startTime, session.endTime)) {
        throw AppException(
            'overlap',
            'You already have a ${o.department} appointment at ${o.hospitalName} '
                '(${o.startTime}-${o.endTime}) that clashes with this time.');
      }
    }
  }

  // ---------------------------------------------------------------- S03
  /// READ - a single appointment, live.
  static Stream<Appointment?> appointment(String id) =>
      Db.appointments.doc(id).snapshots().map((d) => d.exists ? Appointment.fromDoc(d) : null);

  /// UPDATE - turn the visit reminder on or off (F4).
  static Future<void> setReminder(String appointmentId, bool on) =>
      Db.appointments.doc(appointmentId).update({'reminderEnabled': on, if (on) 'reminderSent': false});

  // ---------------------------------------------------------------- S04
  /// READ - all of this patient's appointments, newest first.
  static Stream<List<Appointment>> myAppointments(String uid) => Db.appointments
      .where('patientUid', isEqualTo: uid)
      .snapshots()
      .map((q) => q.docs.map(Appointment.fromDoc).toList()
        ..sort((a, b) {
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : a.startTime.compareTo(b.startTime);
        }));

  /// DELETE - remove a finished/cancelled appointment from the history list.
  static Future<void> deleteFromHistory(Appointment a) {
    if (a.isActive) {
      throw const AppException('active', 'Cancel the appointment before removing it.');
    }
    return Db.appointments.doc(a.id).delete();
  }

  // ---------------------------------------------------------------- S05
  /// UPDATE - move an appointment to another session. The old place is
  /// released and a new token issued, all in one transaction.
  static Future<void> reschedule(Appointment a, ClinicSession target) async {
    if (a.sessionId == target.id) {
      throw const AppException('same', 'That is already your current booking.');
    }
    if (a.status != AppointmentStatus.waiting) {
      throw const AppException('locked', 'This appointment can no longer be changed.');
    }
    if (a.patientUid != null) {
      await _guardBookable(a.patientUid!, target,
          exceptAppointmentId: a.id, forSelf: a.bookedFor == 'self', patientName: a.patientName);
    }
    final oldRef = Db.sessions.doc(a.sessionId);
    final newRef = Db.sessions.doc(target.id);
    final apptRef = Db.appointments.doc(a.id);

    await Db.fs.runTransaction((tx) async {
      final oldSnap = await tx.get(oldRef);
      final s = ClinicSession.fromDoc(await tx.get(newRef));
      if (!s.isActive) {
        throw const AppException('cancelled', 'That clinic session has been cancelled.');
      }
      if (!QueueLogic.hasCapacity(s.bookedCount, s.capacity)) {
        throw const AppException('full', 'All places for that clinic day are taken.');
      }
      final token = s.lastToken + 1;
      if (oldSnap.exists) {
        final old = ClinicSession.fromDoc(oldSnap);
        tx.update(oldRef, {
          'bookedCount': (old.bookedCount - 1).clamp(0, old.capacity),
          'waitingIds': FieldValue.arrayRemove([a.id]),
        });
      }
      tx.update(newRef, {
        'bookedCount': s.bookedCount + 1,
        'lastToken': token,
        'waitingIds': FieldValue.arrayUnion([a.id]),
      });
      tx.update(apptRef, {
        'sessionId': s.id,
        'hospitalId': s.hospitalId,
        'hospitalName': s.hospitalName,
        'department': s.department,
        'doctorName': s.doctorName,
        'date': Timestamp.fromDate(s.date),
        'dateKey': s.dateKey,
        'startTime': s.startTime,
        'tokenNumber': token,
        'tokenLabel': QueueLogic.tokenLabel(s.tokenPrefix, token),
        'reminderHoursBefore': s.reminderHoursBefore,
        'reminderSent': false,
        'arrived': false,
        'nearTurnNotified': false,
        'rescheduledAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------- S06
  /// UPDATE - cancel with a reason; the place returns to the pool (F5).
  static Future<void> cancel(Appointment a, String reason) async {
    if (reason.trim().isEmpty || reason.length > 200) {
      throw const AppException('reason', 'Give a reason of up to 200 characters.');
    }
    if (a.status != AppointmentStatus.waiting) {
      throw const AppException('locked', 'This appointment can no longer be cancelled.');
    }
    final sessionRef = Db.sessions.doc(a.sessionId);
    final apptRef = Db.appointments.doc(a.id);
    await Db.fs.runTransaction((tx) async {
      final snap = await tx.get(sessionRef);
      if (snap.exists) {
        final s = ClinicSession.fromDoc(snap);
        tx.update(sessionRef, {
          'bookedCount': (s.bookedCount - 1).clamp(0, s.capacity),
          'waitingIds': FieldValue.arrayRemove([a.id]),
        });
      }
      tx.update(apptRef, {
        'status': AppointmentStatus.cancelled,
        'cancelReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------- S07
  /// READ - the session document that carries the live queue (F2, NF4).
  static Stream<ClinicSession?> liveSession(String sessionId) =>
      Db.sessions.doc(sessionId).snapshots().map((d) => d.exists ? ClinicSession.fromDoc(d) : null);

  /// UPDATE - patient tells reception they have arrived.
  static Future<void> markArrived(String appointmentId) =>
      Db.appointments.doc(appointmentId).update({'arrived': true, 'arrivedAt': FieldValue.serverTimestamp()});

  // ------------------------------------------------------------ reminders
  /// Creates due reminder notifications for the patient's own appointments
  /// (F4). Runs when the patient app opens; an SMS gateway would replace
  /// this in production (see report: deviations).
  static Future<void> sendDueReminders(String uid, List<Appointment> appts) async {
    final now = DateTime.now();
    for (final a in appts) {
      if (!a.isActive || !a.reminderEnabled || a.reminderSent) continue;
      final start = startOf(a);
      if (start.isBefore(now)) continue;
      if (start.difference(now).inHours >= a.reminderHoursBefore) continue;
      final batch = Db.fs.batch();
      batch.set(
          Db.notifications.doc(),
          AppNotification.data(
            uid: uid,
            title: 'Reminder: ${a.department} - ${a.tokenLabel}',
            body: 'Your visit to ${a.hospitalName} is on ${a.dateKey} at ${a.startTime}.',
            type: NotificationTypes.reminder,
            appointmentId: a.id,
          ));
      batch.update(Db.appointments.doc(a.id), {'reminderSent': true});
      await batch.commit();
    }
  }

  static DateTime startOf(Appointment a) {
    final mins = DateKeys.minutesOf(a.startTime) ?? 0;
    return DateKeys.dayOnly(a.date).add(Duration(minutes: mins));
  }
}
