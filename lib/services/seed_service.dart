import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/logic.dart';
import '../models/clinic_session.dart';
import '../models/patient.dart';
import 'db.dart';

/// Loads demo hospitals, two weeks of clinic sessions and sample patient
/// records so the app can be demonstrated and usability-tested straight
/// after setup. Staff only (enforced by Firestore rules).
class SeedService {
  static const _hospitals = [
    {
      'id': 'negombo-dgh',
      'name': 'District General Hospital, Negombo',
      'district': 'Gampaha',
      'address': 'Colombo Road, Negombo'
    },
    {
      'id': 'gampaha-dgh',
      'name': 'District General Hospital, Gampaha',
      'district': 'Gampaha',
      'address': 'Hospital Road, Gampaha'
    },
    {
      'id': 'colombo-south',
      'name': 'Colombo South Teaching Hospital',
      'district': 'Colombo',
      'address': 'Kalubowila, Dehiwala'
    },
    {
      'id': 'kandy-th',
      'name': 'National Hospital, Kandy',
      'district': 'Kandy',
      'address': 'William Gopallawa Mawatha, Kandy'
    },
  ];

  // Fictional doctors - no real clinician names are used.
  static const _clinics = [
    {
      'department': 'General OPD',
      'doctor': 'Dr. N. Perera',
      'room': 'OPD Room 1',
      'prefix': 'A',
      'start': '08:00',
      'end': '12:00',
      'capacity': 40,
      'avg': 6
    },
    {
      'department': 'Medical Clinic',
      'doctor': 'Dr. S. Fernando',
      'room': 'Clinic Room 3',
      'prefix': 'M',
      'start': '09:00',
      'end': '12:30',
      'capacity': 25,
      'avg': 10
    },
    {
      'department': 'Diabetic Clinic',
      'doctor': 'Dr. R. Jayawardena',
      'room': 'Clinic Room 5',
      'prefix': 'D',
      'start': '13:00',
      'end': '16:00',
      'capacity': 20,
      'avg': 12
    },
  ];

  static Future<bool> isEmpty() async => (await Db.hospitals.limit(1).get()).docs.isEmpty;

  static Future<int> seed(String staffUid) async {
    // At most ~160 writes, well under Firestore's 500-write batch limit.
    var writes = 0;
    final batch = Db.fs.batch();

    for (final h in _hospitals) {
      batch.set(Db.hospitals.doc(h['id']), {
        'name': h['name'],
        'district': h['district'],
        'address': h['address'],
      });
      writes++;
    }

    final today = DateKeys.dayOnly(DateTime.now());
    for (var day = 0; day < 14; day++) {
      final date = today.add(Duration(days: day));
      if (date.weekday == DateTime.sunday) continue;
      for (final h in _hospitals) {
        for (final c in _clinics) {
          // Specialist clinics run on alternate days only - "clinic days".
          if (c['department'] != 'General OPD' && date.day.isOdd != (c['prefix'] == 'M')) continue;
          batch.set(
            Db.sessions.doc(),
            ClinicSession.newSessionData(
              hospitalId: h['id']!,
              hospitalName: h['name']!,
              department: c['department'] as String,
              doctorName: c['doctor'] as String,
              room: c['room'] as String,
              date: date,
              dateKey: DateKeys.of(date),
              startTime: c['start'] as String,
              endTime: c['end'] as String,
              capacity: c['capacity'] as int,
              tokenPrefix: c['prefix'] as String,
              avgConsultMinutes: c['avg'] as int,
              remindersEnabled: true,
              reminderHoursBefore: 24,
              createdBy: staffUid,
            ),
          );
          writes++;
        }
      }
    }

    const samples = [
      ['Harmanis Munasinghe', '195612345678', '0771234567', 'Male', 'O+', 'Penicillin', 'si'],
      ['Kamala Wickramasinghe', '625431234V', '0712345678', 'Female', 'A+', '', 'si'],
      ['Selvaraj Kumar', '198823456789', '0759876543', 'Male', 'B+', '', 'ta'],
      ['Nimali Silva', '199567891234', '0761122334', 'Female', 'AB-', 'Sulfa drugs', 'en'],
      ['Mohamed Rizwan', '780123456V', '0784455667', 'Male', 'O-', '', 'ta'],
    ];
    for (final p in samples) {
      final ref = Db.patients.doc();
      batch.set(ref, {
        ...Patient.editableData(
          fullName: p[0],
          nic: p[1],
          phone: p[2],
          dob: Validators.dobFromNic(p[1]),
          gender: p[3],
          address: 'Negombo',
          bloodGroup: p[4],
          allergies: p[5],
          emergencyContact: '',
          preferredLanguage: p[6],
        ),
        'archived': false,
        'createdBy': staffUid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(Db.visits(ref.id).doc(), {
        'date': Timestamp.fromDate(today.subtract(const Duration(days: 30))),
        'hospitalName': _hospitals.first['name'],
        'department': 'General OPD',
        'doctorName': 'Dr. N. Perera',
        'tokenLabel': 'A-014',
        'diagnosis': 'Follow-up review',
        'notes': 'Imported from paper register',
        'createdAt': FieldValue.serverTimestamp(),
      });
      writes += 2;
    }

    await batch.commit();
    return writes;
  }
}
