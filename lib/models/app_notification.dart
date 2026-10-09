import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationTypes {
  static const booking = 'booking';
  static const reminder = 'reminder';
  static const nearTurn = 'nearTurn';
  static const sessionChanged = 'sessionChanged';
  static const sessionCancelled = 'sessionCancelled';
}

class AppNotification {
  final String id;
  final String uid;
  final String title;
  final String body;
  final String type;
  final bool read;
  final String? appointmentId;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    this.appointmentId,
    this.createdAt,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      uid: d['uid'] ?? '',
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: d['type'] ?? '',
      read: d['read'] ?? false,
      appointmentId: d['appointmentId'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> data({
    required String uid,
    required String title,
    required String body,
    required String type,
    String? appointmentId,
  }) =>
      {
        'uid': uid,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'appointmentId': appointmentId,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
