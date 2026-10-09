import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/logic.dart';
import '../models/app_notification.dart';
import '../models/appointment.dart';
import '../models/clinic_session.dart';
import '../models/patient.dart';
import 'db.dart';

/// Reception queue module S08-S12 (F2, F5).
/// Owner: P.A.J. Sithmini (IT23671874)
class QueueService {
  // ---------------------------------------------------------------- S08
  /// READ - today's sessions so the receptionist can pick a queue.
  static Stream<List<ClinicSession>> sessionsOn(DateTime day) => Db.sessions
      .where('dateKey', isEqualTo: DateKeys.of(day))
      .snapshots()
      .map((q) => q.docs.map(ClinicSession.fromDoc).toList()
        ..sort((a, b) {
          final c = a.hospitalName.compareTo(b.hospitalName);
          return c != 0 ? c : a.startTime.compareTo(b.startTime);
        }));

  /// READ - every appointment in a session (staff only).
  static Stream<List<Appointment>> sessionAppointments(String sessionId) => Db.appointments
      .where('sessionId', isEqualTo: sessionId)
      .snapshots()
      .map((q) => q.docs.map(Appointment.fromDoc).toList()..sort((a, b) => a.tokenNumber.compareTo(b.tokenNumber)));

  /// UPDATE - move a waiting patient one place up or down.
  static Future<void> move(String sessionId, String appointmentId, int delta) async {
    final ref = Db.sessions.doc(sessionId);
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(ref));
      tx.update(ref, {'waitingIds': QueueLogic.move(s.waitingIds, appointmentId, delta)});
    });
  }

  /// READ - the next date (today or later) that has an active clinic, so an
  /// empty day can offer "jump to the next clinic day".
  static Future<DateTime?> nextClinicDay(DateTime from) async {
    final q = await Db.sessions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateKeys.dayOnly(from)))
        .get();
    final days = q.docs.map(ClinicSession.fromDoc).where((s) => s.isActive).map((s) => DateKeys.dayOnly(s.date)).toList()
      ..sort();
    return days.isEmpty ? null : days.first;
  }

  /// CREATE - one notification for every patient (with the app) who still has
  /// an active booking in the session.
  static Future<int> _notifyActive(String sessionId, String title, String body) async {
    final q = await Db.appointments.where('sessionId', isEqualTo: sessionId).get();
    final batch = Db.fs.batch();
    var n = 0;
    for (final a in q.docs.map(Appointment.fromDoc).where((a) => a.isActive && a.patientUid != null)) {
      batch.set(
          Db.notifications.doc(),
          AppNotification.data(
            uid: a.patientUid!,
            title: title,
            body: body,
            type: NotificationTypes.sessionChanged,
            appointmentId: a.id,
          ));
      n++;
    }
    if (n > 0) await batch.commit();
    return n;
  }

  /// UPDATE - the doctor is running late (or back on time with 0). Every
  /// patient's expected time moves with it and they are told.
  static Future<int> setDelay(ClinicSession s, int minutes) async {
    if (minutes < 0 || minutes > 240) {
      throw const AppException('delay', 'Enter a delay between 0 and 240 minutes.');
    }
    await Db.sessions.doc(s.id).update({'delayMinutes': minutes});
    if (minutes == s.delayMinutes) return 0;
    return _notifyActive(
      s.id,
      minutes == 0 ? 'Clinic is back on time' : 'Clinic delayed by $minutes minutes',
      minutes == 0
          ? '${s.department} at ${s.hospitalName} is running on time again.'
          : '${s.department} at ${s.hospitalName} is running about $minutes minutes late. '
              'Your expected time has moved; you do not need to rush.',
    );
  }

  /// UPDATE - pause or resume calling patients (doctor break, emergency).
  static Future<int> setPaused(ClinicSession s, bool paused, {String reason = ''}) async {
    if (paused && reason.trim().isEmpty) {
      throw const AppException('reason', 'Give a short reason so patients know why.');
    }
    await Db.sessions.doc(s.id).update({
      'paused': paused,
      'pauseReason': paused ? reason.trim() : '',
    });
    return _notifyActive(
      s.id,
      paused ? 'Queue paused' : 'Queue resumed',
      paused
          ? '${s.department}: ${reason.trim()}. Please stay nearby; we will resume shortly.'
          : '${s.department}: the queue has resumed.',
    );
  }

  /// CREATE - send a free-text announcement to everyone booked in the clinic.
  static Future<int> broadcast(ClinicSession s, String message) async {
    final text = message.trim();
    if (text.length < 5) throw const AppException('message', 'Write a message of at least 5 characters.');
    if (text.length > 200) throw const AppException('message', 'Keep the message under 200 characters.');
    await Db.sessions.doc(s.id).update({'announcement': text});
    return _notifyActive(s.id, 'Message from ${s.hospitalName}', '${s.department}: $text');
  }

  /// UPDATE - skip a waiting patient back a few places (called, but not
  /// here yet). They are told, and keep their place in the queue.
  static Future<void> skip(Appointment a, {int places = 3}) async {
    final ref = Db.sessions.doc(a.sessionId);
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(ref));
      if (!s.waitingIds.contains(a.id)) {
        throw const AppException('not-waiting', 'That patient is no longer waiting.');
      }
      tx.update(ref, {'waitingIds': QueueLogic.skip(s.waitingIds, a.id, places: places)});
      tx.update(Db.appointments.doc(a.id), {'nearTurnNotified': false});
    });
    if (a.patientUid != null) {
      await Db.notifications.add(AppNotification.data(
        uid: a.patientUid!,
        title: 'Your turn was moved back - ${a.tokenLabel}',
        body: 'You were not at the clinic when called. You are now a few places later. '
            'Please stay near the waiting area and tell reception when you arrive.',
        type: NotificationTypes.nearTurn,
        appointmentId: a.id,
      ));
    }
  }

  /// UPDATE - call the patient who is currently being served again (they
  /// did not respond). Sends the "it's your turn" alert once more.
  static Future<void> recall(String sessionId) async {
    final snap = await Db.sessions.doc(sessionId).get();
    if (!snap.exists) return;
    final s = ClinicSession.fromDoc(snap);
    if (s.currentServingId == null) {
      throw const AppException('nobody', 'Nobody is being served right now.');
    }
    final cur = await Db.appointments.doc(s.currentServingId).get();
    if (!cur.exists) return;
    final a = Appointment.fromDoc(cur);
    await cur.reference.update({'calledAt': FieldValue.serverTimestamp()});
    if (a.patientUid != null) {
      await Db.notifications.add(AppNotification.data(
        uid: a.patientUid!,
        title: "Reminder: it's your turn - ${a.tokenLabel}",
        body: 'Please go to ${s.room.isEmpty ? 'the consultation room' : s.room} now.',
        type: NotificationTypes.nearTurn,
        appointmentId: a.id,
      ));
    }
  }

  /// UPDATE - reception confirms a booked patient is physically present.
  static Future<void> setArrived(String appointmentId, bool arrived) =>
      Db.appointments.doc(appointmentId).update({'arrived': arrived});

  // ---------------------------------------------------------------- S09
  /// READ - find an existing patient record by NIC or phone.
  static Future<Patient?> findPatient(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final byNic = await Db.patients.where('nic', isEqualTo: q.toUpperCase()).limit(1).get();
    if (byNic.docs.isNotEmpty) return Patient.fromDoc(byNic.docs.first);
    final byPhone = await Db.patients.where('phone', isEqualTo: q.replaceAll(' ', '')).limit(1).get();
    if (byPhone.docs.isNotEmpty) return Patient.fromDoc(byPhone.docs.first);
    return null;
  }

  /// CREATE - walk-in check-in, or a phone/assisted booking made by reception
  /// for a patient without the app (F1, [channel] = 'phone'). Issues the next
  /// token immediately.
  /// Walk-ins are accepted even when the session is full, because a
  /// government OPD cannot turn away a patient who is already there.
  static Future<String> walkIn({
    required ClinicSession session,
    required String name,
    required String phone,
    Patient? patient,
    bool priority = false,
    String? priorityReason,
    required String staffUid,
    required Set<String> currentPriorityIds,
    String channel = 'walkIn',
  }) async {
    final nameError = Validators.personName(name);
    if (nameError != null) throw AppException('name', nameError);
    final phoneError = Validators.optionalMobile(phone);
    if (phoneError != null) throw AppException('phone', phoneError);
    if (channel == 'phone' && phone.trim().isEmpty) {
      throw const AppException('phone', 'A phone booking needs a mobile number.');
    }
    if (channel == 'walkIn' && DateKeys.hasEnded(session.date, session.endTime)) {
      throw const AppException('ended', 'This clinic has already finished. Walk-ins can no longer be added.');
    }
    if (DateKeys.dayOnly(session.date).isBefore(DateKeys.dayOnly(DateTime.now()))) {
      throw const AppException('past', 'That clinic day has passed. Choose a current or future session.');
    }
    if (priority && (priorityReason ?? '').trim().isEmpty) {
      throw const AppException('reason', 'Choose a reason for priority.');
    }
    // The same person cannot hold two live tokens in one clinic.
    final existing = await Db.appointments.where('sessionId', isEqualTo: session.id).get();
    final dup = existing.docs.map(Appointment.fromDoc).any((a) =>
        a.isActive &&
        ((patient != null && a.patientId == patient.id) ||
            (a.patientPhone.isNotEmpty && a.patientPhone == phone.replaceAll(' ', '') && a.patientName.trim().toLowerCase() == name.trim().toLowerCase())));
    if (dup) {
      throw const AppException('duplicate', 'This patient already has a token in this clinic.');
    }
    final sessionRef = Db.sessions.doc(session.id);
    final apptRef = Db.appointments.doc();
    late String label;
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(sessionRef));
      if (!s.isActive) {
        throw const AppException('cancelled', 'This session has been cancelled.');
      }
      final token = s.lastToken + 1;
      label = QueueLogic.tokenLabel(s.tokenPrefix, token);
      tx.update(sessionRef, {
        'bookedCount': s.bookedCount + 1,
        'lastToken': token,
        'waitingIds': QueueLogic.insert(s.waitingIds, apptRef.id, priority: priority, priorityIds: currentPriorityIds),
      });
      tx.set(apptRef, {
        'patientUid': patient?.linkedUid,
        'patientId': patient?.id,
        'patientName': name.trim(),
        'patientPhone': phone.replaceAll(' ', ''),
        'sessionId': s.id,
        'hospitalId': s.hospitalId,
        'hospitalName': s.hospitalName,
        'department': s.department,
        'doctorName': s.doctorName,
        'date': Timestamp.fromDate(s.date),
        'dateKey': s.dateKey,
        'startTime': s.startTime,
        'tokenNumber': token,
        'tokenLabel': label,
        'status': AppointmentStatus.waiting,
        'channel': channel,
        'priority': priority,
        'priorityReason': priority ? priorityReason : null,
        'reminderEnabled': false,
        'reminderHoursBefore': s.reminderHoursBefore,
        'reminderSent': true,
        'arrived': channel == 'walkIn',
        'nearTurnNotified': false,
        'createdBy': staffUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return label;
  }

  // ---------------------------------------------------------------- S10
  /// UPDATE - flag (or un-flag) a patient as priority with a reason, and
  /// move them in the queue accordingly.
  static Future<void> setPriority({
    required Appointment appointment,
    required bool priority,
    String? reason,
    required Set<String> currentPriorityIds,
  }) async {
    final sessionRef = Db.sessions.doc(appointment.sessionId);
    final apptRef = Db.appointments.doc(appointment.id);
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(sessionRef));
      final others = Set<String>.from(currentPriorityIds)..remove(appointment.id);
      if (s.waitingIds.contains(appointment.id)) {
        final List<String> newOrder;
        if (priority) {
          newOrder = QueueLogic.insert(s.waitingIds, appointment.id, priority: true, priorityIds: others);
        } else {
          // Put back in token order among the non-priority patients.
          newOrder = List<String>.from(s.waitingIds)..remove(appointment.id);
          var pos = 0;
          while (pos < newOrder.length && others.contains(newOrder[pos])) {
            pos++;
          }
          newOrder.insert(pos, appointment.id);
        }
        tx.update(sessionRef, {'waitingIds': newOrder});
      }
      tx.update(apptRef, {
        'priority': priority,
        'priorityReason': priority ? reason : null,
        'priorityAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ---------------------------------------------------------------- S11
  /// UPDATE + CREATE - finish the current consultation (writing a visit to
  /// the patient record) and call the next patient in the queue.
  /// Returns the token label now being served, or null if the queue is empty.
  ///
  /// By default the patient at the front is called. Pass [appointmentId] to
  /// call a specific waiting patient instead (for example the first one who
  /// has checked in, when the front of the queue has not arrived).
  static Future<String?> callNext(String sessionId, {String? appointmentId}) async {
    final sessionRef = Db.sessions.doc(sessionId);
    String? nextLabel;
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(sessionRef));
      if (!s.isActive) {
        throw const AppException('cancelled', 'This session has been cancelled.');
      }
      if (s.paused) {
        throw const AppException('paused', 'The queue is paused. Resume it before calling the next patient.');
      }
      Appointment? current;
      Appointment? next;
      if (s.currentServingId != null) {
        final snap = await tx.get(Db.appointments.doc(s.currentServingId));
        if (snap.exists) current = Appointment.fromDoc(snap);
      }
      if (appointmentId != null && !s.waitingIds.contains(appointmentId)) {
        throw const AppException('not-waiting', 'That patient is no longer waiting. The list has been refreshed.');
      }
      final targetId = appointmentId ?? (s.waitingIds.isNotEmpty ? s.waitingIds.first : null);
      if (targetId != null) {
        final snap = await tx.get(Db.appointments.doc(targetId));
        if (snap.exists) next = Appointment.fromDoc(snap);
      }

      if (current != null && current.status == AppointmentStatus.serving) {
        tx.update(Db.appointments.doc(current.id), {
          'status': AppointmentStatus.completed,
          'completedAt': FieldValue.serverTimestamp(),
        });
        if (current.patientId != null) {
          tx.set(Db.visits(current.patientId!).doc(), {
            'date': Timestamp.fromDate(DateTime.now()),
            'appointmentId': current.id,
            'hospitalName': current.hospitalName,
            'department': current.department,
            'doctorName': current.doctorName,
            'tokenLabel': current.tokenLabel,
            'diagnosis': '',
            'notes': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      final remaining = List<String>.from(s.waitingIds);
      if (targetId != null) remaining.remove(targetId);
      if (next != null) {
        tx.update(Db.appointments.doc(next.id), {
          'status': AppointmentStatus.serving,
          'calledAt': FieldValue.serverTimestamp(),
        });
        nextLabel = next.tokenLabel;
      }
      tx.update(sessionRef, {
        'waitingIds': remaining,
        'currentServingId': next?.id,
        'currentTokenLabel': next?.tokenLabel,
      });
    });
    await _notifyQueueChanges(sessionId);
    return nextLabel;
  }

  /// UPDATE - finish the current consultation without calling anyone.
  static Future<void> completeCurrent(String sessionId) async {
    final sessionRef = Db.sessions.doc(sessionId);
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(sessionRef));
      if (s.currentServingId == null) return;
      final snap = await tx.get(Db.appointments.doc(s.currentServingId));
      if (snap.exists) {
        final a = Appointment.fromDoc(snap);
        tx.update(snap.reference, {
          'status': AppointmentStatus.completed,
          'completedAt': FieldValue.serverTimestamp(),
        });
        if (a.patientId != null) {
          tx.set(Db.visits(a.patientId!).doc(), {
            'date': Timestamp.fromDate(DateTime.now()),
            'appointmentId': a.id,
            'hospitalName': a.hospitalName,
            'department': a.department,
            'doctorName': a.doctorName,
            'tokenLabel': a.tokenLabel,
            'diagnosis': '',
            'notes': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      tx.update(sessionRef, {'currentServingId': null, 'currentTokenLabel': null});
    });
  }

  /// CREATE - "your turn" and "near turn" notifications for app patients.
  static Future<void> _notifyQueueChanges(String sessionId) async {
    final snap = await Db.sessions.doc(sessionId).get();
    if (!snap.exists) return;
    final s = ClinicSession.fromDoc(snap);
    final batch = Db.fs.batch();
    var writes = 0;

    if (s.currentServingId != null) {
      final cur = await Db.appointments.doc(s.currentServingId).get();
      if (cur.exists) {
        final a = Appointment.fromDoc(cur);
        if (a.patientUid != null) {
          batch.set(
              Db.notifications.doc(),
              AppNotification.data(
                uid: a.patientUid!,
                title: "It's your turn - ${a.tokenLabel}",
                body: 'Please go to ${s.room.isEmpty ? 'the consultation room' : s.room} now.',
                type: NotificationTypes.nearTurn,
                appointmentId: a.id,
              ));
          writes++;
        }
      }
    }

    final soon = s.waitingIds.take(QueueLogic.nearTurnThreshold + 1);
    for (final id in soon) {
      final doc = await Db.appointments.doc(id).get();
      if (!doc.exists) continue;
      final a = Appointment.fromDoc(doc);
      if (a.patientUid == null || a.nearTurnNotified) continue;
      final ahead = s.waitingIds.indexOf(a.id);
      batch.set(
          Db.notifications.doc(),
          AppNotification.data(
            uid: a.patientUid!,
            title: 'Your turn is near - ${a.tokenLabel}',
            body: '$ahead patient(s) ahead of you. Please return to the waiting area.',
            type: NotificationTypes.nearTurn,
            appointmentId: a.id,
          ));
      batch.update(doc.reference, {'nearTurnNotified': true});
      writes += 2;
    }
    if (writes > 0) await batch.commit();
  }

  // ---------------------------------------------------------------- S12
  /// UPDATE - mark a patient who did not respond as a no-show and close
  /// their token so the queue is not blocked by stale entries.
  static Future<void> markNoShow(Appointment a) async {
    final sessionRef = Db.sessions.doc(a.sessionId);
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(sessionRef));
      final update = <String, dynamic>{
        'waitingIds': List<String>.from(s.waitingIds)..remove(a.id),
      };
      if (s.currentServingId == a.id) {
        update['currentServingId'] = null;
        update['currentTokenLabel'] = null;
      }
      tx.update(sessionRef, update);
      tx.update(Db.appointments.doc(a.id), {
        'status': AppointmentStatus.noShow,
        'noShowAt': FieldValue.serverTimestamp(),
      });
    });
    await _notifyQueueChanges(a.sessionId);
  }

  /// UPDATE - a late patient returns: put them back at the end of the queue.
  static Future<void> requeue(Appointment a) async {
    final sessionRef = Db.sessions.doc(a.sessionId);
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(sessionRef));
      if (!s.isActive) {
        throw const AppException('cancelled', 'This session has been cancelled.');
      }
      tx.update(sessionRef, {
        'waitingIds': List<String>.from(s.waitingIds)
          ..remove(a.id)
          ..add(a.id),
      });
      tx.update(Db.appointments.doc(a.id), {
        'status': AppointmentStatus.waiting,
        'arrived': true,
        'nearTurnNotified': false,
      });
    });
  }

  /// DELETE - remove a token that was issued in error.
  static Future<void> deleteToken(Appointment a) async {
    final sessionRef = Db.sessions.doc(a.sessionId);
    await Db.fs.runTransaction((tx) async {
      final s = ClinicSession.fromDoc(await tx.get(sessionRef));
      final update = <String, dynamic>{
        'waitingIds': List<String>.from(s.waitingIds)..remove(a.id),
        'bookedCount': (s.bookedCount - 1).clamp(0, 1 << 30),
      };
      if (s.currentServingId == a.id) {
        update['currentServingId'] = null;
        update['currentTokenLabel'] = null;
      }
      tx.update(sessionRef, update);
      tx.delete(Db.appointments.doc(a.id));
    });
  }
}
