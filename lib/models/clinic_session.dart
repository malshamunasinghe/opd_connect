import 'package:cloud_firestore/cloud_firestore.dart';

/// One clinic session (a doctor running a clinic on a given day).
/// The session document also carries the live queue: [waitingIds] is the
/// ordered list of appointment ids still waiting, and [currentServingId] is
/// the appointment currently with the doctor. Patients read only this
/// document to see their position, so they never need to read other
/// patients' appointments (NF1).
class ClinicSession {
  final String id;
  final String hospitalId;
  final String hospitalName;
  final String department;
  final String doctorName;
  final String room;
  final DateTime date;
  final String dateKey;
  final String startTime;
  final String endTime;
  final int capacity;
  final int bookedCount;
  final int lastToken;
  final String tokenPrefix;
  final int avgConsultMinutes;
  final String status; // active | cancelled
  final String? cancelReason;
  final bool remindersEnabled;
  final int reminderHoursBefore;
  final List<String> waitingIds;
  final String? currentServingId;
  final String? currentTokenLabel;
  final String notes;
  final int delayMinutes; // clinic is running late by this much
  final bool paused; // queue paused (break, emergency)
  final String pauseReason;
  final String announcement; // latest message from reception

  const ClinicSession({
    required this.id,
    required this.hospitalId,
    required this.hospitalName,
    required this.department,
    required this.doctorName,
    required this.room,
    required this.date,
    required this.dateKey,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.bookedCount,
    required this.lastToken,
    required this.tokenPrefix,
    required this.avgConsultMinutes,
    required this.status,
    this.cancelReason,
    required this.remindersEnabled,
    required this.reminderHoursBefore,
    required this.waitingIds,
    this.currentServingId,
    this.currentTokenLabel,
    this.notes = '',
    this.delayMinutes = 0,
    this.paused = false,
    this.pauseReason = '',
    this.announcement = '',
  });

  bool get isActive => status == 'active';
  bool get isFull => bookedCount >= capacity;
  int get placesLeft => (capacity - bookedCount).clamp(0, capacity);

  factory ClinicSession.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ClinicSession(
      id: doc.id,
      hospitalId: d['hospitalId'] ?? '',
      hospitalName: d['hospitalName'] ?? '',
      department: d['department'] ?? '',
      doctorName: d['doctorName'] ?? '',
      room: d['room'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateKey: d['dateKey'] ?? '',
      startTime: d['startTime'] ?? '08:00',
      endTime: d['endTime'] ?? '12:00',
      capacity: ((d['capacity'] as num?) ?? 0).toInt(),
      bookedCount: ((d['bookedCount'] as num?) ?? 0).toInt(),
      lastToken: ((d['lastToken'] as num?) ?? 0).toInt(),
      tokenPrefix: d['tokenPrefix'] ?? 'A',
      avgConsultMinutes: ((d['avgConsultMinutes'] as num?) ?? 8).toInt(),
      status: d['status'] ?? 'active',
      cancelReason: d['cancelReason'],
      remindersEnabled: d['remindersEnabled'] ?? true,
      reminderHoursBefore: ((d['reminderHoursBefore'] as num?) ?? 24).toInt(),
      waitingIds: List<String>.from(d['waitingIds'] ?? const []),
      currentServingId: d['currentServingId'],
      currentTokenLabel: d['currentTokenLabel'],
      notes: d['notes'] ?? '',
      delayMinutes: ((d['delayMinutes'] as num?) ?? 0).toInt(),
      paused: d['paused'] ?? false,
      pauseReason: d['pauseReason'] ?? '',
      announcement: d['announcement'] ?? '',
    );
  }

  /// Fields written when staff create a session (S18).
  static Map<String, dynamic> newSessionData({
    required String hospitalId,
    required String hospitalName,
    required String department,
    required String doctorName,
    required String room,
    required DateTime date,
    required String dateKey,
    required String startTime,
    required String endTime,
    required int capacity,
    required String tokenPrefix,
    required int avgConsultMinutes,
    required bool remindersEnabled,
    required int reminderHoursBefore,
    required String createdBy,
    String notes = '',
  }) =>
      {
        'hospitalId': hospitalId,
        'hospitalName': hospitalName,
        'department': department,
        'doctorName': doctorName,
        'room': room,
        'date': Timestamp.fromDate(date),
        'dateKey': dateKey,
        'startTime': startTime,
        'endTime': endTime,
        'capacity': capacity,
        'bookedCount': 0,
        'lastToken': 0,
        'tokenPrefix': tokenPrefix,
        'avgConsultMinutes': avgConsultMinutes,
        'status': 'active',
        'remindersEnabled': remindersEnabled,
        'reminderHoursBefore': reminderHoursBefore,
        'waitingIds': <String>[],
        'currentServingId': null,
        'currentTokenLabel': null,
        'notes': notes,
        'delayMinutes': 0,
        'paused': false,
        'pauseReason': '',
        'announcement': '',
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
