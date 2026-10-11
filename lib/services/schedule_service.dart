import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/logic.dart';
import '../models/app_notification.dart';
import '../models/appointment.dart';
import '../models/clinic_session.dart';
import '../models/user_profile.dart';
import 'db.dart';

/// Clinic schedule, notifications and accessibility module S18-S22
/// (F1, F4, NF2, NF3).
/// Owner: Nethmini K (IT23669130)
class ScheduleService {
  // ---------------------------------------------------------------- S18
  /// READ - sessions on the same day that clash with the proposed one
  /// (same hospital and the same doctor or room, overlapping times).
  static Future<List<ClinicSession>> conflicts({
    required String hospitalId,
    required String dateKey,
    required String doctorName,
    required String room,
    required String startTime,
    required String endTime,
    String? exceptId,
  }) async {
    final q = await Db.sessions.where('dateKey', isEqualTo: dateKey).get();
    return q.docs.map(ClinicSession.fromDoc).where((s) {
      if (s.id == exceptId || !s.isActive || s.hospitalId != hospitalId) return false;
      final sameDoctor = s.doctorName.trim().toLowerCase() == doctorName.trim().toLowerCase();
      final sameRoom = room.trim().isNotEmpty && s.room.trim().toLowerCase() == room.trim().toLowerCase();
      return (sameDoctor || sameRoom) && DateKeys.overlaps(s.startTime, s.endTime, startTime, endTime);
    }).toList();
  }

  /// CREATE - a new clinic session.
  static Future<String> create(Map<String, dynamic> data) async {
    final ref = await Db.sessions.add(data);
    return ref.id;
  }

  // ---------------------------------------------------------------- S19
  /// READ - all sessions in the week starting [weekStart].
  static Stream<List<ClinicSession>> week(DateTime weekStart) {
    final start = DateKeys.dayOnly(weekStart);
    final end = start.add(const Duration(days: 7));
    return Db.sessions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((q) => q.docs.map(ClinicSession.fromDoc).toList()
          ..sort((a, b) {
            final c = a.date.compareTo(b.date);
            return c != 0 ? c : a.startTime.compareTo(b.startTime);
          }));
  }

  static Stream<ClinicSession?> session(String id) =>
      Db.sessions.doc(id).snapshots().map((d) => d.exists ? ClinicSession.fromDoc(d) : null);

  /// READ - notifications for a user, newest first.
  static Stream<List<AppNotification>> notifications(String uid) =>
      Db.notifications.where('uid', isEqualTo: uid).snapshots().map((q) => q.docs.map(AppNotification.fromDoc).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2100)).compareTo(a.createdAt ?? DateTime(2100))));

  /// UPDATE - mark one notification as read.
  static Future<void> markRead(String id) => Db.notifications.doc(id).update({'read': true});

  /// UPDATE - mark every unread notification as read.
  static Future<void> markAllRead(List<AppNotification> items) async {
    final batch = Db.fs.batch();
    var n = 0;
    for (final i in items.where((i) => !i.read)) {
      batch.update(Db.notifications.doc(i.id), {'read': true});
      n++;
    }
    if (n > 0) await batch.commit();
  }

  /// DELETE - remove several notifications at once (e.g. "clear read").
  static Future<void> deleteMany(List<String> ids) async {
    // A Firestore batch holds at most 500 writes.
    for (var i = 0; i < ids.length; i += 400) {
      final batch = Db.fs.batch();
      for (final id in ids.skip(i).take(400)) {
        batch.delete(Db.notifications.doc(id));
      }
      await batch.commit();
    }
  }

  /// DELETE - dismiss a notification.
  static Future<void> deleteNotification(String id) => Db.notifications.doc(id).delete();

  // ---------------------------------------------------------------- S20
  /// UPDATE - edit a session and its reminder settings. If the date or time
  /// changes, every booked app patient is notified automatically (F4) and
  /// their appointment copies are updated.
  static Future<int> update(ClinicSession old, Map<String, dynamic> changes) async {
    final timeChanged =
        changes['dateKey'] != old.dateKey || changes['startTime'] != old.startTime || changes['endTime'] != old.endTime;
    final reminderChanged = changes['reminderHoursBefore'] != old.reminderHoursBefore ||
        changes['remindersEnabled'] != old.remindersEnabled;
    final doctorChanged = changes['doctorName'] != old.doctorName;

    final appts = await _activeAppointments(old.id);
    final batch = Db.fs.batch();
    batch.update(Db.sessions.doc(old.id), {...changes, 'updatedAt': FieldValue.serverTimestamp()});

    var notified = 0;
    for (final a in appts) {
      final apptChanges = <String, dynamic>{};
      if (timeChanged) {
        apptChanges['date'] = changes['date'];
        apptChanges['dateKey'] = changes['dateKey'];
        apptChanges['startTime'] = changes['startTime'];
        apptChanges['reminderSent'] = false;
      }
      if (doctorChanged) apptChanges['doctorName'] = changes['doctorName'];
      if (reminderChanged) {
        apptChanges['reminderHoursBefore'] = changes['reminderHoursBefore'];
        if (changes['remindersEnabled'] == false) apptChanges['reminderEnabled'] = false;
      }
      if (apptChanges.isNotEmpty) batch.update(Db.appointments.doc(a.id), apptChanges);

      if ((timeChanged || doctorChanged) && a.patientUid != null) {
        batch.set(
            Db.notifications.doc(),
            AppNotification.data(
              uid: a.patientUid!,
              title: 'Clinic changed - ${a.tokenLabel}',
              body: '${old.department} at ${old.hospitalName} is now on '
                  '${changes['dateKey']} at ${changes['startTime']}'
                  '${doctorChanged ? ' with ${changes['doctorName']}' : ''}.',
              type: NotificationTypes.sessionChanged,
              appointmentId: a.id,
            ));
        notified++;
      }
    }
    await batch.commit();
    return notified;
  }

  // ---------------------------------------------------------------- S21
  /// UPDATE + CREATE - cancel a session, cancel every booking in it and
  /// notify each affected patient automatically (F4).
  static Future<int> cancel(ClinicSession s, String reason) async {
    final appts = await _activeAppointments(s.id);
    final batch = Db.fs.batch();
    batch.update(Db.sessions.doc(s.id), {
      'status': 'cancelled',
      'cancelReason': reason,
      'waitingIds': <String>[],
      'currentServingId': null,
      'currentTokenLabel': null,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    var notified = 0;
    for (final a in appts) {
      batch.update(Db.appointments.doc(a.id), {
        'status': AppointmentStatus.cancelled,
        'cancelReason': 'Session cancelled by hospital: $reason',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      if (a.patientUid != null) {
        batch.set(
            Db.notifications.doc(),
            AppNotification.data(
              uid: a.patientUid!,
              title: 'Clinic cancelled - ${a.tokenLabel}',
              body: '${s.department} at ${s.hospitalName} on ${s.dateKey} was cancelled '
                  '($reason). Please book another day.',
              type: NotificationTypes.sessionCancelled,
              appointmentId: a.id,
            ));
        notified++;
      }
    }
    await batch.commit();
    return notified;
  }

  /// DELETE - remove a session created by mistake. Only allowed while no
  /// appointment has ever been made for it.
  static Future<void> delete(ClinicSession s) async {
    final any = await Db.appointments.where('sessionId', isEqualTo: s.id).limit(1).get();
    if (any.docs.isNotEmpty) {
      throw const AppException(
          'has-bookings', 'This session has bookings. Cancel it instead so patients are notified.');
    }
    await Db.sessions.doc(s.id).delete();
  }

  /// DELETE - admin only. Permanently removes a clinic session from the
  /// database together with every booking made for it. Patients who still
  /// had an active booking and use the app are notified first. Returns how
  /// many bookings were removed and how many patients were notified.
  ///
  /// The booking documents and notifications go first and the session last,
  /// so a failure part-way leaves the session visible and the delete can be
  /// retried. Patients' medical visit history is not touched.
  static Future<({int bookings, int notified})> deleteSessionPermanently(
      ClinicSession s, UserProfile admin) async {
    if (!admin.isAdmin) {
      throw const AppException('forbidden', 'Only an admin can permanently delete a clinic.');
    }
    final appts = (await Db.appointments.where('sessionId', isEqualTo: s.id).get()).docs.map(Appointment.fromDoc).toList();
    final ops = <void Function(WriteBatch)>[];

    var notified = 0;
    for (final a in appts) {
      if (a.isActive && a.patientUid != null) {
        ops.add((b) => b.set(
            Db.notifications.doc(),
            AppNotification.data(
              uid: a.patientUid!,
              title: 'Clinic removed - ${a.tokenLabel}',
              body: '${s.department} at ${s.hospitalName} on ${s.dateKey} was removed by the hospital. '
                  'Please book another day.',
              type: NotificationTypes.sessionCancelled,
            )));
        notified++;
      }
    }
    for (final a in appts) {
      ops.add((b) => b.delete(Db.appointments.doc(a.id)));
    }
    ops.add((b) => b.delete(Db.sessions.doc(s.id)));

    // A batch holds at most 500 writes; stay well under it.
    const chunk = 400;
    for (var i = 0; i < ops.length; i += chunk) {
      final batch = Db.fs.batch();
      for (final op in ops.skip(i).take(chunk)) {
        op(batch);
      }
      await batch.commit();
    }
    return (bookings: appts.length, notified: notified);
  }

  static Future<List<Appointment>> _activeAppointments(String sessionId) async {
    final q = await Db.appointments.where('sessionId', isEqualTo: sessionId).get();
    return q.docs.map(Appointment.fromDoc).where((a) => a.isActive).toList();
  }

  // ---------------------------------------------------------------- S22
  /// UPDATE - save language, text size and contrast to the user profile so
  /// they follow the user to any device.
  static Future<void> saveSettings(String uid,
          {required String language, required double textScale, required bool highContrast}) =>
      Db.users.doc(uid).update({
        'language': language,
        'textScale': textScale,
        'highContrast': highContrast,
      });
}
