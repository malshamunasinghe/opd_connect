import 'package:flutter_test/flutter_test.dart';
import 'package:opd_connect/core/logic.dart';
import 'package:opd_connect/core/strings.dart';
import 'package:opd_connect/core/ui.dart';
import 'package:opd_connect/models/user_profile.dart';
import 'package:opd_connect/services/patient_service.dart';

/// Automated functional tests for the business rules behind the queue,
/// booking and record screens. IDs match docs/TEST_CASES.md (AT-xx).
void main() {
  group('Token numbers (S03, S09)', () {
    test('AT-01 token label is prefix + 3-digit number', () {
      expect(QueueLogic.tokenLabel('A', 52), 'A-052');
      expect(QueueLogic.tokenLabel('M', 7), 'M-007');
      expect(QueueLogic.tokenLabel('D', 123), 'D-123');
    });

    test('AT-02 capacity check blocks overbooking (S02 error state)', () {
      expect(QueueLogic.hasCapacity(39, 40), isTrue);
      expect(QueueLogic.hasCapacity(40, 40), isFalse);
      expect(QueueLogic.hasCapacity(0, 0), isFalse);
    });
  });

  group('Live queue position and wait (S07, F2)', () {
    final q = ['a1', 'a2', 'a3', 'a4', 'a5'];

    test('AT-03 patients ahead equals index in waiting list', () {
      expect(QueueLogic.patientsAhead(q, 'a1'), 0);
      expect(QueueLogic.patientsAhead(q, 'a4'), 3);
      expect(QueueLogic.patientsAhead(q, 'zz'), -1);
    });

    test('AT-04 estimated wait uses average consultation time', () {
      expect(QueueLogic.estimatedWaitMinutes(patientsAhead: 3, avgConsultMinutes: 10, someoneBeingServed: false), 30);
      expect(QueueLogic.estimatedWaitMinutes(patientsAhead: 3, avgConsultMinutes: 10, someoneBeingServed: true), 35);
      expect(QueueLogic.estimatedWaitMinutes(patientsAhead: -1, avgConsultMinutes: 10, someoneBeingServed: true), 0);
    });

    test('AT-05 queue state: waiting -> near turn -> your turn', () {
      expect(QueueLogic.stateFor(appointmentId: 'a5', currentServingId: null, waitingIds: q), QueueState.waiting);
      expect(QueueLogic.stateFor(appointmentId: 'a3', currentServingId: null, waitingIds: q), QueueState.nearTurn);
      expect(QueueLogic.stateFor(appointmentId: 'a1', currentServingId: null, waitingIds: q), QueueState.nearTurn);
      expect(QueueLogic.stateFor(appointmentId: 'x', currentServingId: 'x', waitingIds: q), QueueState.yourTurn);
      expect(QueueLogic.stateFor(appointmentId: 'gone', currentServingId: 'a0', waitingIds: q), QueueState.notInQueue);
    });
  });

  group('Queue ordering (S08, S10)', () {
    test('AT-06 normal patient is added at the end', () {
      expect(QueueLogic.insert(['a', 'b'], 'c'), ['a', 'b', 'c']);
    });

    test('AT-07 priority patient goes after existing priority patients only', () {
      final result = QueueLogic.insert(['p1', 'p2', 'a', 'b'], 'p3', priority: true, priorityIds: {'p1', 'p2'});
      expect(result, ['p1', 'p2', 'p3', 'a', 'b']);
    });

    test('AT-08 priority with no other priority patients goes first', () {
      expect(QueueLogic.insert(['a', 'b'], 'p', priority: true), ['p', 'a', 'b']);
    });

    test('AT-09 re-inserting an existing id does not duplicate it', () {
      expect(QueueLogic.insert(['a', 'b', 'c'], 'b'), ['a', 'c', 'b']);
    });

    test('AT-10 move up / down swaps neighbours and respects edges', () {
      expect(QueueLogic.move(['a', 'b', 'c'], 'b', -1), ['b', 'a', 'c']);
      expect(QueueLogic.move(['a', 'b', 'c'], 'b', 1), ['a', 'c', 'b']);
      expect(QueueLogic.move(['a', 'b', 'c'], 'a', -1), ['a', 'b', 'c']);
      expect(QueueLogic.move(['a', 'b', 'c'], 'c', 1), ['a', 'b', 'c']);
    });
  });

  group('Live queue timing (S07)', () {
    test('AT-26 expected call time counts from clinic start before it opens', () {
      final start = DateTime(2026, 10, 8, 9, 0);
      final early = QueueLogic.expectedAt(
        now: DateTime(2026, 10, 8, 7, 30),
        clinicStart: start,
        patientsAhead: 3,
        avgConsultMinutes: 10,
        someoneBeingServed: false,
      );
      expect(early, DateTime(2026, 10, 8, 9, 30));
      final later = QueueLogic.expectedAt(
        now: DateTime(2026, 10, 8, 10, 0),
        clinicStart: start,
        patientsAhead: 2,
        avgConsultMinutes: 10,
        someoneBeingServed: true,
      );
      expect(later, DateTime(2026, 10, 8, 10, 25)); // 2 x 10 + half a consultation
    });

    test('AT-27 journey step for the progress timeline', () {
      expect(QueueLogic.journeyStep(status: 'waiting', arrived: false, state: QueueState.waiting), 0);
      expect(QueueLogic.journeyStep(status: 'waiting', arrived: true, state: QueueState.waiting), 1);
      expect(QueueLogic.journeyStep(status: 'waiting', arrived: true, state: QueueState.nearTurn), 2);
      expect(QueueLogic.journeyStep(status: 'serving', arrived: true, state: QueueState.yourTurn), 3);
      expect(QueueLogic.journeyStep(status: 'completed', arrived: true, state: QueueState.notInQueue), 4);
    });
  });

  group('Skipping a patient (S08)', () {
    test('AT-25 a skipped patient moves back but keeps a place', () {
      expect(QueueLogic.skip(['a', 'b', 'c', 'd', 'e'], 'a'), ['b', 'c', 'd', 'a', 'e']);
      expect(QueueLogic.skip(['a', 'b'], 'a'), ['b', 'a']); // clamps at the end
      expect(QueueLogic.skip(['a', 'b', 'c'], 'zz'), ['a', 'b', 'c']);
      expect(QueueLogic.skip(['a', 'b', 'c', 'd'], 'b', places: 1), ['a', 'c', 'b', 'd']);
    });
  });

  group('Input validation (S13, S15, S17)', () {
    test('AT-11 NIC accepts old and new formats only', () {
      expect(Validators.nic('851234567V'), isNull);
      expect(Validators.nic('851234567x'), isNull);
      expect(Validators.nic('198512345678'), isNull);
      expect(Validators.nic('85123456V'), isNotNull);
      expect(Validators.nic('ABCDEFGHIJ'), isNotNull);
      expect(Validators.nic(''), isNotNull);
    });

    test('AT-12 mobile must be 10 digits starting with 0', () {
      expect(Validators.mobile('0771234567'), isNull);
      expect(Validators.mobile('077 123 4567'), isNull);
      expect(Validators.mobile('771234567'), isNotNull);
      expect(Validators.mobile('07712345678'), isNotNull);
    });

    test('AT-13 email and password rules', () {
      expect(Validators.email('a@b.lk'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('AT-14 date of birth and gender derived from NIC', () {
      // Old format: 85 -> 1985, day 032 -> 1 February.
      expect(Validators.dobFromNic('850321234V'), DateTime(1985, 2, 1));
      expect(Validators.genderFromNic('850321234V'), 'Male');
      // New format, female (day + 500): 1995, day 532 -> 1 February.
      expect(Validators.dobFromNic('199553212345'), DateTime(1995, 2, 1));
      expect(Validators.genderFromNic('199553212345'), 'Female');
      expect(Validators.dobFromNic('bad'), isNull);
    });
  });

  group('Stricter validation', () {
    test('AT-18 NIC must encode a real birth date', () {
      expect(Validators.nic('851234567V'), isNull);
      expect(Validators.nic('859994567V'), isNotNull); // day 999 does not exist
      expect(Validators.nic('209912345678'), isNotNull); // year in the future
    });

    test('AT-19 person names allow letters (incl. Sinhala/Tamil) but not digits', () {
      expect(Validators.personName('Nimal Perera'), isNull);
      expect(Validators.personName("D'Silva-Fernando"), isNull);
      expect(Validators.personName('නිමල් පෙරේරා'), isNull);
      expect(Validators.personName('நிமல்'), isNull);
      expect(Validators.personName('Ab'), isNotNull);
      expect(Validators.personName('Nimal123'), isNotNull);
      expect(Validators.personName('   '), isNotNull);
      expect(Validators.personName('A' * 81), isNotNull);
    });

    test('AT-20 new passwords need 8+ chars with a letter and a number', () {
      expect(Validators.newPassword('abcd1234'), isNull);
      expect(Validators.newPassword('abcdefgh'), isNotNull);
      expect(Validators.newPassword('12345678'), isNotNull);
      expect(Validators.newPassword('abc123'), isNotNull);
      expect(Validators.newPassword('abcd 1234'), isNotNull);
      // Sign-in accepts older, shorter passwords.
      expect(Validators.passwordRequired('abc123'), isNull);
      expect(Validators.passwordRequired(''), isNotNull);
    });

    test('AT-21 optional mobile, text length and date of birth', () {
      expect(Validators.optionalMobile(''), isNull);
      expect(Validators.optionalMobile('0771234567'), isNull);
      expect(Validators.optionalMobile('12345'), isNotNull);
      expect(Validators.text('x' * 201, field: 'Address'), isNotNull);
      expect(Validators.text('', field: 'Code', min: 4), isNotNull);
      expect(Validators.dob(null), isNotNull);
      expect(Validators.dob(DateTime.now().add(const Duration(days: 2))), isNotNull);
      expect(Validators.dob(DateTime(1985, 2, 1)), isNull);
    });
  });

  group('Scheduling (S18, S20)', () {
    test('AT-22 a clinic that has ended cannot be booked', () {
      final day = DateTime(2026, 10, 7);
      expect(DateKeys.hasEnded(day, '12:00', DateTime(2026, 10, 7, 12, 30)), isTrue);
      expect(DateKeys.hasEnded(day, '12:00', DateTime(2026, 10, 7, 9, 0)), isFalse);
      expect(DateKeys.hasEnded(day, '12:00', DateTime(2026, 10, 8, 1, 0)), isTrue);
      expect(DateKeys.hasEnded(day, '12:00', DateTime(2026, 10, 6, 23, 0)), isFalse);
    });

    test('AT-15 overlapping clinic times are detected', () {
      expect(DateKeys.overlaps('08:00', '12:00', '11:00', '13:00'), isTrue);
      expect(DateKeys.overlaps('08:00', '12:00', '12:00', '14:00'), isFalse);
      expect(DateKeys.overlaps('13:00', '16:00', '08:00', '12:00'), isFalse);
    });

    test('AT-16 date keys and week start', () {
      expect(DateKeys.of(DateTime(2026, 10, 6)), '2026-10-06');
      expect(DateKeys.startOfWeek(DateTime(2026, 10, 8)), DateTime(2026, 10, 5)); // Monday
      expect(DateKeys.minutesOf('08:30'), 510);
      expect(DateKeys.minutesOf('25:00'), isNull);
    });
  });

  group('Profile helpers', () {
    test('AT-23 initials for the avatar', () {
      expect(InitialsAvatar.initialsOf('Nimal Perera'), 'NP');
      expect(InitialsAvatar.initialsOf('Nimal'), 'N');
      expect(InitialsAvatar.initialsOf('  '), '?');
      expect(InitialsAvatar.initialsOf('Kamala D. Wickramasinghe'), 'KW');
    });

    test('AT-23a admin-only access flag is enforced by role', () {
      const admin = UserProfile(
        uid: 'u1',
        name: 'Admin User',
        email: 'admin@example.com',
        phone: '0770000000',
        role: Roles.admin,
      );
      const staff = UserProfile(
        uid: 'u2',
        name: 'Staff User',
        email: 'staff@example.com',
        phone: '0770000001',
        role: Roles.staff,
      );
      expect(admin.isAdmin, isTrue);
      expect(staff.isAdmin, isFalse);
      expect(admin.isStaff, isTrue);
      expect(staff.isStaff, isTrue);
    });

    test('AT-23b only admins can delete patient records', () {
      const admin = UserProfile(
        uid: 'u1',
        name: 'Admin User',
        email: 'admin@example.com',
        phone: '0770000000',
        role: Roles.admin,
      );
      const staff = UserProfile(
        uid: 'u2',
        name: 'Staff User',
        email: 'staff@example.com',
        phone: '0770000001',
        role: Roles.staff,
      );

      expect(PatientService.canDeletePatient(admin), isTrue);
      expect(PatientService.canDeletePatient(staff), isFalse);
      expect(PatientService.canDeletePatient(null), isFalse);
    });

    test('AT-23a admin-only access flag is enforced by role', () {
      const admin = UserProfile(
        uid: 'u1',
        name: 'Admin User',
        email: 'admin@example.com',
        phone: '0770000000',
        role: Roles.admin,
      );
      const staff = UserProfile(
        uid: 'u2',
        name: 'Staff User',
        email: 'staff@example.com',
        phone: '0770000001',
        role: Roles.staff,
      );
      expect(admin.isAdmin, isTrue);
      expect(staff.isAdmin, isFalse);
      expect(admin.isStaff, isTrue);
      expect(staff.isStaff, isTrue);
    });

    test('AT-23b hospital history keeps unique names in order', () {
      expect(HistoryLogic.hospitalNamesInOrder(['General Hospital', 'Kandy Teaching', 'General Hospital', '']), [
        'General Hospital',
        'Kandy Teaching',
      ]);
    });

    test('AT-24 password strength score rises with variety', () {
      expect(PasswordStrength.score('abc'), 0);
      expect(PasswordStrength.score('abcd1234'), 2);
      expect(PasswordStrength.score('Abcd1234'), 3);
      expect(PasswordStrength.score('Abcd1234!'), 4);
    });
  });

  group('Multi-language (S22, NF3)', () {
    test('AT-17 every string has English, Sinhala and Tamil', () {
      for (final key in ['bookAppointment', 'yourTurn', 'nearTurn', 'cancelConsequence', 'textSize']) {
        for (final lang in S.supported) {
          expect(S.of(lang, key), isNot(equals(key)), reason: '$key missing in $lang');
        }
      }
      // The whole table: every key must have English, Sinhala and Tamil text.
      for (final key in S.allKeys) {
        final en = S.of('en', key);
        expect(en.trim(), isNotEmpty, reason: '$key has no English text');
        for (final lang in ['si', 'ta']) {
          expect(S.of(lang, key).trim(), isNotEmpty, reason: '$key missing in $lang');
        }
        // Placeholders such as {n} must survive translation.
        for (final m in RegExp(r'\{(\w+)\}').allMatches(en)) {
          for (final lang in ['si', 'ta']) {
            expect(S.of(lang, key), contains(m.group(0)), reason: '$key lost ${m.group(0)} in $lang');
          }
        }
      }
      expect(S.of('si', 'bookAppointment'), isNot(S.of('en', 'bookAppointment')));
      expect(S.of('ta', 'bookAppointment'), isNot(S.of('en', 'bookAppointment')));
    });
  });
}
