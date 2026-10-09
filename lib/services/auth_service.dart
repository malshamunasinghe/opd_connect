import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/logic.dart';
import '../models/patient.dart';
import '../models/user_profile.dart';
import 'db.dart';

/// S17 - login, registration and role-based access (NF1, NF2).
/// Owner: Weerasinghe W.D.S.U (IT23685802)
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Stream<User?> authChanges() => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  /// READ - the signed-in user's profile and role.
  static Stream<UserProfile?> profileStream(String uid) =>
      Db.users.doc(uid).snapshots().map((d) => d.exists ? UserProfile.fromDoc(d) : null);

  static Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  /// CREATE - a new account plus its profile document.
  ///
  /// Staff/admin accounts must supply the access code stored in
  /// `config/access` (readable only by security rules, never by the app), so
  /// a patient cannot give themselves staff rights.
  static Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    String nic = '',
    String accessCode = '',
    String language = 'en',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    try {
      await user.updateDisplayName(name.trim());
      final profile = <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.replaceAll(' ', ''),
        'role': role,
        'language': language,
        'textScale': 1.0,
        'highContrast': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (role != Roles.patient) profile['accessCode'] = accessCode.trim();
      await Db.users.doc(user.uid).set(profile);

      if (role == Roles.patient) {
        // Every app patient also gets a centralised record (F3) so reception
        // sees the same person when they arrive.
        final patientRef = Db.patients.doc();
        final nicNorm = Validators.normaliseNic(nic);
        await patientRef.set({
          ...Patient.editableData(
            fullName: name,
            nic: nicNorm,
            phone: phone,
            dob: nicNorm.isEmpty ? null : Validators.dobFromNic(nicNorm),
            gender: nicNorm.isEmpty ? '' : (Validators.genderFromNic(nicNorm) ?? ''),
            address: '',
            bloodGroup: '',
            allergies: '',
            emergencyContact: '',
            preferredLanguage: language,
          ),
          'archived': false,
          'linkedUid': user.uid,
          'createdBy': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await Db.users.doc(user.uid).update({'patientId': patientRef.id});
      }
    } on FirebaseException catch (e) {
      // Roll back the auth account so the user can try again cleanly.
      await user.delete();
      if (e.code == 'permission-denied' && role != Roles.patient) {
        throw const AppException('bad-code', 'The staff access code is not valid.');
      }
      rethrow;
    }
    // Outside the try: a failed e-mail (e.g. rate limit) must not roll back
    // an account that was created successfully. It can be resent from S22.
    await user.sendEmailVerification().catchError((_) {});
  }

  static Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  static Future<void> signOut() => _auth.signOut();
}
