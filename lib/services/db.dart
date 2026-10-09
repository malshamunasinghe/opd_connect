import 'package:cloud_firestore/cloud_firestore.dart';

/// Central place for Firestore collection references.
///
/// Every query in the app uses at most equality filters or a single-field
/// range, and sorting is done on the client, so no composite indexes have
/// to be created in the Firebase console.
class Db {
  static FirebaseFirestore get fs => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get users => fs.collection('users');
  static CollectionReference<Map<String, dynamic>> get hospitals => fs.collection('hospitals');
  static CollectionReference<Map<String, dynamic>> get sessions => fs.collection('sessions');
  static CollectionReference<Map<String, dynamic>> get appointments => fs.collection('appointments');
  static CollectionReference<Map<String, dynamic>> get patients => fs.collection('patients');
  static CollectionReference<Map<String, dynamic>> get notifications => fs.collection('notifications');
  static CollectionReference<Map<String, dynamic>> get auditLogs => fs.collection('auditLogs');

  static CollectionReference<Map<String, dynamic>> visits(String patientId) =>
      patients.doc(patientId).collection('visits');
}

/// A user-facing error raised by service methods. [code] lets screens pick a
/// translated message; [message] is the English fallback.
class AppException implements Exception {
  final String code;
  final String message;
  const AppException(this.code, this.message);

  @override
  String toString() => message;
}

/// Turns Firebase and app errors into a short sentence for a SnackBar.
String friendlyError(Object e) {
  if (e is AppException) return e.message;
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
        return 'No connection. Your change will sync when you are back online.';
      case 'not-found':
        return 'That record no longer exists.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters with letters and numbers.';
      case 'wrong-password-current':
        return 'Your current password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact the hospital ICT unit.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
    }
    return e.message ?? 'Something went wrong (${e.code}).';
  }
  return e.toString();
}
