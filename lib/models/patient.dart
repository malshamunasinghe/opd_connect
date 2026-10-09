import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralised patient record (F3).
class Patient {
  final String id;
  final String fullName;
  final String nic;
  final String phone;
  final DateTime? dob;
  final String gender;
  final String address;
  final String bloodGroup;
  final String allergies;
  final String emergencyContact;
  final String preferredLanguage;
  final bool archived;
  final String? archiveNote;
  final String? linkedUid;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Patient({
    required this.id,
    required this.fullName,
    required this.nic,
    required this.phone,
    this.dob,
    required this.gender,
    required this.address,
    required this.bloodGroup,
    required this.allergies,
    required this.emergencyContact,
    required this.preferredLanguage,
    required this.archived,
    this.archiveNote,
    this.linkedUid,
    this.createdAt,
    this.updatedAt,
  });

  int? get age {
    if (dob == null) return null;
    final now = DateTime.now();
    var a = now.year - dob!.year;
    if (now.month < dob!.month || (now.month == dob!.month && now.day < dob!.day)) a--;
    return a;
  }

  factory Patient.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Patient(
      id: doc.id,
      fullName: d['fullName'] ?? '',
      nic: d['nic'] ?? '',
      phone: d['phone'] ?? '',
      dob: (d['dob'] as Timestamp?)?.toDate(),
      gender: d['gender'] ?? '',
      address: d['address'] ?? '',
      bloodGroup: d['bloodGroup'] ?? '',
      allergies: d['allergies'] ?? '',
      emergencyContact: d['emergencyContact'] ?? '',
      preferredLanguage: d['preferredLanguage'] ?? 'en',
      archived: d['archived'] ?? false,
      archiveNote: d['archiveNote'],
      linkedUid: d['linkedUid'],
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Editable fields, used by both S13 (create) and S15 (update).
  static Map<String, dynamic> editableData({
    required String fullName,
    required String nic,
    required String phone,
    DateTime? dob,
    required String gender,
    required String address,
    required String bloodGroup,
    required String allergies,
    required String emergencyContact,
    required String preferredLanguage,
  }) =>
      {
        'fullName': fullName.trim(),
        'nic': nic.trim().toUpperCase(),
        'phone': phone.replaceAll(' ', ''),
        'dob': dob == null ? null : Timestamp.fromDate(dob),
        'gender': gender,
        'address': address.trim(),
        'bloodGroup': bloodGroup,
        'allergies': allergies.trim(),
        'emergencyContact': emergencyContact.trim(),
        'preferredLanguage': preferredLanguage,
        'nameLower': fullName.trim().toLowerCase(),
      };
}

class Visit {
  final String id;
  final DateTime date;
  final String hospitalName;
  final String department;
  final String doctorName;
  final String tokenLabel;
  final String diagnosis;
  final String notes;

  const Visit({
    required this.id,
    required this.date,
    required this.hospitalName,
    required this.department,
    required this.doctorName,
    required this.tokenLabel,
    required this.diagnosis,
    required this.notes,
  });

  factory Visit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Visit(
      id: doc.id,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hospitalName: d['hospitalName'] ?? '',
      department: d['department'] ?? '',
      doctorName: d['doctorName'] ?? '',
      tokenLabel: d['tokenLabel'] ?? '',
      diagnosis: d['diagnosis'] ?? '',
      notes: d['notes'] ?? '',
    );
  }
}

class AuditEntry {
  final String id;
  final String action;
  final String note;
  final String byName;
  final DateTime? at;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.note,
    required this.byName,
    this.at,
  });

  factory AuditEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AuditEntry(
      id: doc.id,
      action: d['action'] ?? '',
      note: d['note'] ?? '',
      byName: d['byName'] ?? '',
      at: (d['at'] as Timestamp?)?.toDate(),
    );
  }
}
