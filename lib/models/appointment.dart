import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentStatus {
  static const waiting = 'waiting';
  static const serving = 'serving';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const noShow = 'noShow';

  static const active = [waiting, serving];
}

class Appointment {
  final String id;
  final String? patientUid; // null for walk-ins without the app
  final String? patientId; // patients/{id} record
  final String patientName;
  final String patientPhone;
  final String sessionId;
  final String hospitalId;
  final String hospitalName;
  final String department;
  final String doctorName;
  final DateTime date;
  final String dateKey;
  final String startTime;
  final int tokenNumber;
  final String tokenLabel;
  final String status;
  final String channel; // app | walkIn | phone
  final bool priority;
  final String? priorityReason;
  final bool reminderEnabled;
  final int reminderHoursBefore;
  final bool reminderSent;
  final bool arrived;
  final bool nearTurnNotified;
  final String? cancelReason;
  final String visitReason;
  final String bookedFor; // self | other
  final String relation;
  final int? patientAge;
  final String patientNic;
  final String patientGender;
  final DateTime? createdAt;
  final DateTime? calledAt;
  final DateTime? completedAt;

  const Appointment({
    required this.id,
    this.patientUid,
    this.patientId,
    required this.patientName,
    required this.patientPhone,
    required this.sessionId,
    required this.hospitalId,
    required this.hospitalName,
    required this.department,
    required this.doctorName,
    required this.date,
    required this.dateKey,
    required this.startTime,
    required this.tokenNumber,
    required this.tokenLabel,
    required this.status,
    required this.channel,
    required this.priority,
    this.priorityReason,
    required this.reminderEnabled,
    this.reminderHoursBefore = 24,
    this.reminderSent = false,
    required this.arrived,
    required this.nearTurnNotified,
    this.cancelReason,
    this.visitReason = '',
    this.bookedFor = 'self',
    this.relation = '',
    this.patientAge,
    this.patientNic = '',
    this.patientGender = '',
    this.createdAt,
    this.calledAt,
    this.completedAt,
  });

  bool get isActive => AppointmentStatus.active.contains(status);

  /// Short booking reference shown on S03 (U1 fix from Milestone 02 testing).
  String get reference => 'OPD-${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';

  factory Appointment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Appointment(
      id: doc.id,
      patientUid: d['patientUid'],
      patientId: d['patientId'],
      patientName: d['patientName'] ?? '',
      patientPhone: d['patientPhone'] ?? '',
      sessionId: d['sessionId'] ?? '',
      hospitalId: d['hospitalId'] ?? '',
      hospitalName: d['hospitalName'] ?? '',
      department: d['department'] ?? '',
      doctorName: d['doctorName'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateKey: d['dateKey'] ?? '',
      startTime: d['startTime'] ?? '',
      tokenNumber: ((d['tokenNumber'] as num?) ?? 0).toInt(),
      tokenLabel: d['tokenLabel'] ?? '',
      status: d['status'] ?? AppointmentStatus.waiting,
      channel: d['channel'] ?? 'app',
      priority: d['priority'] ?? false,
      priorityReason: d['priorityReason'],
      reminderEnabled: d['reminderEnabled'] ?? true,
      reminderHoursBefore: ((d['reminderHoursBefore'] as num?) ?? 24).toInt(),
      reminderSent: d['reminderSent'] ?? false,
      arrived: d['arrived'] ?? false,
      nearTurnNotified: d['nearTurnNotified'] ?? false,
      cancelReason: d['cancelReason'],
      visitReason: d['visitReason'] ?? '',
      bookedFor: d['bookedFor'] ?? 'self',
      relation: d['relation'] ?? '',
      patientAge: (d['patientAge'] as num?)?.toInt(),
      patientNic: d['patientNic'] ?? '',
      patientGender: d['patientGender'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      calledAt: (d['calledAt'] as Timestamp?)?.toDate(),
      completedAt: (d['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}
