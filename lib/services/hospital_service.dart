import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/hospital.dart';
import 'db.dart';

/// Hospital directory management (staff). Patients only read hospitals; they
/// choose one when booking.
class HospitalService {
  /// READ - find a hospital with the same name (case-insensitive).
  static Future<Hospital?> _byName(String name, {String? exceptId}) async {
    final q = await Db.hospitals.get();
    for (final d in q.docs) {
      if (d.id == exceptId) continue;
      final h = Hospital.fromDoc(d);
      if (h.name.trim().toLowerCase() == name.trim().toLowerCase()) return h;
    }
    return null;
  }

  /// CREATE - add a hospital. Names must be unique.
  static Future<String> create({
    required String name,
    required String district,
    required String address,
    String phone = '',
    required String staffUid,
  }) async {
    if (await _byName(name) != null) {
      throw AppException('duplicate', 'A hospital called "${name.trim()}" already exists.');
    }
    final ref = await Db.hospitals.add({
      'name': name.trim(),
      'district': district,
      'address': address.trim(),
      'phone': phone.replaceAll(' ', ''),
      'createdBy': staffUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// UPDATE - edit a hospital. Its clinic sessions keep the old name until
  /// they are edited, so the new name is copied onto the upcoming ones.
  static Future<void> update(
    Hospital old, {
    required String name,
    required String district,
    required String address,
    String phone = '',
  }) async {
    if (await _byName(name, exceptId: old.id) != null) {
      throw AppException('duplicate', 'A hospital called "${name.trim()}" already exists.');
    }
    final batch = Db.fs.batch();
    batch.update(Db.hospitals.doc(old.id), {
      'name': name.trim(),
      'district': district,
      'address': address.trim(),
      'phone': phone.replaceAll(' ', ''),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (name.trim() != old.name) {
      final sessions = await Db.sessions.where('hospitalId', isEqualTo: old.id).get();
      for (final s in sessions.docs) {
        batch.update(s.reference, {'hospitalName': name.trim()});
      }
      final appts = await Db.appointments.where('hospitalId', isEqualTo: old.id).get();
      for (final a in appts.docs) {
        batch.update(a.reference, {'hospitalName': name.trim()});
      }
    }
    await batch.commit();
  }

  /// DELETE - only when no clinic session was ever created for it.
  static Future<void> delete(Hospital h) async {
    final any = await Db.sessions.where('hospitalId', isEqualTo: h.id).limit(1).get();
    if (any.docs.isNotEmpty) {
      throw const AppException('in-use', 'This hospital has clinic sessions, so it cannot be deleted.');
    }
    await Db.hospitals.doc(h.id).delete();
  }
}
