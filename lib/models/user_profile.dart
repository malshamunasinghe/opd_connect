import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles for role-based access (S17, NF1).
class Roles {
  static const patient = 'patient';
  static const staff = 'staff';
  static const admin = 'admin';

  static bool isStaff(String role) => role == staff || role == admin;}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? patientId;
  final String? lastHospitalId;
  final String language;
  final double textScale;
  final bool highContrast;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.patientId,
    this.lastHospitalId,
    this.language = 'en',
    this.textScale = 1.0,
    this.highContrast = false,
  });

  bool get isStaff => Roles.isStaff(role);
  bool get isAdmin => role == Roles.admin;

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      name: d['name'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      role: d['role'] ?? Roles.patient,
      patientId: d['patientId'],
      lastHospitalId: d['lastHospitalId'],
      language: d['language'] ?? 'en',
      textScale: (d['textScale'] ?? 1.0).toDouble(),
      highContrast: d['highContrast'] ?? false,
    );
  }
}
