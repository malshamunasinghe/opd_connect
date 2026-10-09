import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/logic.dart';
import '../models/patient.dart';
import 'db.dart';

/// Account and health-profile management for the signed-in user
/// (edit profile, change password, e-mail verification).
class ProfileService {
  static User get _user {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw const AppException('signed-out', 'Please sign in again.');
    return u;
  }

  /// READ - the patient's own health record (live).
  static Stream<Patient?> myRecord(String patientId) => Db.patients.doc(patientId).snapshots().map(
        (d) => d.exists ? Patient.fromDoc(d) : null,
      );

  /// UPDATE - name and phone on the account, plus the personal and health
  /// details on the linked patient record. The NIC cannot be changed by the
  /// patient (staff verify it at the counter), which the security rules also
  /// enforce.
  static Future<void> updateProfile({
    required String uid,
    String? patientId,
    required String name,
    required String phone,
    DateTime? dob,
    String? gender,
    String address = '',
    String bloodGroup = '',
    String allergies = '',
    String emergencyContact = '',
  }) async {
    final batch = Db.fs.batch();
    batch.update(Db.users.doc(uid), {
      'name': name.trim(),
      'phone': phone.replaceAll(' ', ''),
    });
    if (patientId != null) {
      batch.update(Db.patients.doc(patientId), {
        'fullName': name.trim(),
        'nameLower': name.trim().toLowerCase(),
        'phone': phone.replaceAll(' ', ''),
        'dob': dob == null ? null : Timestamp.fromDate(dob),
        'gender': gender ?? '',
        'address': address.trim(),
        'bloodGroup': bloodGroup,
        'allergies': allergies.trim(),
        'emergencyContact': emergencyContact.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _user.updateDisplayName(name.trim()).catchError((_) {});
  }

  /// UPDATE - change password. Firebase requires a recent sign-in, so the
  /// current password is checked first.
  static Future<void> changePassword({required String current, required String next}) async {
    final user = _user;
    if (user.email == null) {
      throw const AppException('no-email', 'This account has no e-mail address.');
    }
    if (current == next) {
      throw const AppException('same', 'The new password must be different from the current one.');
    }
    final err = Validators.newPassword(next);
    if (err != null) throw AppException('weak', err);
    await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: current));
    await user.updatePassword(next);
  }

  /// READ - re-check whether the e-mail has been verified since last time.
  static Future<bool> refreshVerified() async {
    final user = _user;
    await user.reload();
    return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  }

  static Future<void> resendVerification() => _user.sendEmailVerification();
}
