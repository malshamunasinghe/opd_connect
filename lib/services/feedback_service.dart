import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import 'db.dart';

/// A patient's rating of a finished visit. One rating per appointment (the
/// document id is the appointment id), so it can be given once.
class VisitFeedback {
  final String appointmentId;
  final int rating;
  final String comment;
  const VisitFeedback({required this.appointmentId, required this.rating, required this.comment});

  factory VisitFeedback.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return VisitFeedback(
      appointmentId: d.id,
      rating: ((m['rating'] as num?) ?? 0).toInt(),
      comment: m['comment'] ?? '',
    );
  }
}

class FeedbackService {
  static CollectionReference<Map<String, dynamic>> get _col => Db.fs.collection('feedback');

  /// READ - the rating for one appointment, live (null until given).
  static Stream<VisitFeedback?> forAppointment(String appointmentId) =>
      _col.doc(appointmentId).snapshots().map((d) => d.exists ? VisitFeedback.fromDoc(d) : null);

  /// CREATE - rate a completed visit (1-5 stars plus an optional comment).
  static Future<void> submit(Appointment a, {required int rating, String comment = ''}) async {
    if (a.status != AppointmentStatus.completed) {
      throw const AppException('not-done', 'You can rate a visit after it is completed.');
    }
    if (rating < 1 || rating > 5) {
      throw const AppException('rating', 'Choose between 1 and 5 stars.');
    }
    if (comment.trim().length > 300) {
      throw const AppException('comment', 'Comment must be 300 characters or fewer.');
    }
    await _col.doc(a.id).set({
      'appointmentId': a.id,
      'patientUid': a.patientUid,
      'hospitalId': a.hospitalId,
      'department': a.department,
      'doctorName': a.doctorName,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// READ - ratings in the last [days] days (staff reports).
  static Future<List<VisitFeedback>> recent(int days) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final q = await _col.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since)).get();
    return q.docs.map(VisitFeedback.fromDoc).toList();
  }
}
