import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../models/patient.dart';
import '../models/user_profile.dart';
import 'db.dart';

/// Patient records and access control module S13-S17 (F3, NF1).
/// Owner: Weerasinghe W.D.S.U (IT23685802)
class PatientService {
  /// READ - all patient records (staff). Sorted and filtered on the client.
  static Stream<List<Patient>> allPatients() => Db.patients.snapshots().map((q) => q.docs.map(Patient.fromDoc).toList()
    ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())));

  static Stream<Patient?> patient(String id) =>
      Db.patients.doc(id).snapshots().map((d) => d.exists ? Patient.fromDoc(d) : null);

  /// Simple local search over name, NIC and phone.
  static List<Patient> filter(List<Patient> all, String query, {required bool archived}) {
    final q = query.trim().toLowerCase();
    return all.where((p) {
      if (p.archived != archived) return false;
      if (q.isEmpty) return true;
      return p.fullName.toLowerCase().contains(q) || p.nic.toLowerCase().contains(q) || p.phone.contains(q);
    }).toList();
  }

  // ---------------------------------------------------------------- S13
  /// READ - duplicate check: is this NIC already registered?
  static Future<Patient?> findByNic(String nic, {String? exceptId}) async {
    final q = await Db.patients.where('nic', isEqualTo: nic.trim().toUpperCase()).get();
    for (final d in q.docs) {
      if (d.id != exceptId) return Patient.fromDoc(d);
    }
    return null;
  }

  /// CREATE - new patient registration (replaces the paper register).
  static Future<String> create(Map<String, dynamic> data, UserProfile staff) async {
    final existing = await findByNic(data['nic'] as String);
    if (existing != null) {
      throw AppException(
          'duplicate', 'A patient with NIC ${data['nic']} is already registered (${existing.fullName}).');
    }
    final ref = Db.patients.doc();
    final batch = Db.fs.batch();
    batch.set(ref, {
      ...data,
      'archived': false,
      'createdBy': staff.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(Db.auditLogs.doc(), _audit(ref.id, 'create', 'Record created', staff));
    await batch.commit();
    return ref.id;
  }

  // ---------------------------------------------------------------- S14
  /// READ - visit history, newest first.
  static Stream<List<Visit>> visits(String patientId) => Db.visits(patientId)
      .snapshots()
      .map((q) => q.docs.map(Visit.fromDoc).toList()..sort((a, b) => b.date.compareTo(a.date)));

  /// READ - booked appointments for the patient, newest first.
  static Stream<List<Appointment>> bookedAppointments(String patientId) => Db.appointments
      .where('patientId', isEqualTo: patientId)
      .snapshots()
      .map((q) => q.docs.map(Appointment.fromDoc).toList()..sort((a, b) => b.date.compareTo(a.date)));

  /// CREATE - add a visit manually (e.g. a visit recorded on paper).
  static Future<void> addVisit(String patientId, Map<String, dynamic> data) =>
      Db.visits(patientId).add({...data, 'createdAt': FieldValue.serverTimestamp()});

  /// UPDATE - diagnosis / notes on a visit.
  static Future<void> updateVisit(String patientId, String visitId, Map<String, dynamic> data) =>
      Db.visits(patientId).doc(visitId).update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  /// DELETE - remove a visit entered by mistake.
  static Future<void> deleteVisit(String patientId, String visitId) => Db.visits(patientId).doc(visitId).delete();

  /// DELETE - permanently remove a patient record. Admin-only action.
  static Future<void> deletePatient(String patientId) async {
    final batch = Db.fs.batch();
    final patientRef = Db.patients.doc(patientId);

    final visits = await patientRef.collection('visits').get();
    for (final doc in visits.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(patientRef);
    await batch.commit();
  }

  // ---------------------------------------------------------------- S15
  /// UPDATE - edit patient details. Every edit is written to the audit log
  /// with the list of changed fields (NF1 accountability).
  static Future<void> update(Patient old, Map<String, dynamic> data, UserProfile staff) async {
    final dup = await findByNic(data['nic'] as String, exceptId: old.id);
    if (dup != null) {
      throw AppException('duplicate', 'NIC ${data['nic']} belongs to ${dup.fullName}.');
    }
    final changed = <String>[];
    void cmp(String field, Object? before) {
      if ('${data[field] ?? ''}' != '${before ?? ''}') changed.add(field);
    }

    cmp('fullName', old.fullName);
    cmp('nic', old.nic);
    cmp('phone', old.phone);
    cmp('gender', old.gender);
    cmp('address', old.address);
    cmp('bloodGroup', old.bloodGroup);
    cmp('allergies', old.allergies);
    cmp('emergencyContact', old.emergencyContact);
    cmp('preferredLanguage', old.preferredLanguage);
    final oldDob = old.dob == null ? null : Timestamp.fromDate(old.dob!);
    if ((data['dob'] as Timestamp?)?.seconds != oldDob?.seconds) changed.add('dob');
    if (changed.isEmpty) return;

    final batch = Db.fs.batch();
    batch.update(Db.patients.doc(old.id), {
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': staff.uid,
    });
    batch.set(Db.auditLogs.doc(), _audit(old.id, 'update', 'Changed: ${changed.join(', ')}', staff));
    await batch.commit();
  }

  // ---------------------------------------------------------------- S16
  /// UPDATE + CREATE - archive (soft delete) with a mandatory audit note.
  /// Records are never hard-deleted so clinical history is preserved.
  static Future<void> archive(Patient p, String note, UserProfile staff) async {
    final batch = Db.fs.batch();
    batch.update(Db.patients.doc(p.id), {
      'archived': true,
      'archiveNote': note.trim(),
      'archivedBy': staff.uid,
      'archivedAt': FieldValue.serverTimestamp(),
    });
    batch.set(Db.auditLogs.doc(), _audit(p.id, 'archive', note.trim(), staff));
    await batch.commit();
  }

  /// UPDATE - restore an archived record.
  static Future<void> restore(Patient p, String note, UserProfile staff) async {
    final batch = Db.fs.batch();
    batch.update(Db.patients.doc(p.id), {
      'archived': false,
      'archiveNote': null,
      'restoredBy': staff.uid,
      'restoredAt': FieldValue.serverTimestamp(),
    });
    batch.set(Db.auditLogs.doc(), _audit(p.id, 'restore', note.trim(), staff));
    await batch.commit();
  }

  /// READ - audit trail for one patient, newest first.
  static Stream<List<AuditEntry>> audit(String patientId) => Db.auditLogs
      .where('patientId', isEqualTo: patientId)
      .snapshots()
      .map((q) => q.docs.map(AuditEntry.fromDoc).toList()
        ..sort((a, b) => (b.at ?? DateTime(2100)).compareTo(a.at ?? DateTime(2100))));

  static Map<String, dynamic> _audit(String patientId, String action, String note, UserProfile by) => {
        'patientId': patientId,
        'action': action,
        'note': note,
        'byUid': by.uid,
        'byName': by.name,
        'at': FieldValue.serverTimestamp(),
      };
}
