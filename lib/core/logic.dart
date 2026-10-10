/// Pure business rules with no Firebase dependency, so they can be covered
/// by unit tests (test/logic_test.dart) as part of the functional test suite.
class QueueLogic {
  /// Formats a token as shown on the M02 prototype, e.g. A-052.
  static String tokenLabel(String prefix, int number) => '$prefix-${number.toString().padLeft(3, '0')}';

  /// Number of patients ahead of [appointmentId] in the ordered waiting list.
  /// Returns -1 when the appointment is not waiting (served, cancelled...).
  static int patientsAhead(List<String> waitingIds, String appointmentId) => waitingIds.indexOf(appointmentId);

  /// Estimated wait in minutes (F2). The patient currently with the doctor
  /// is counted as half a consultation on average.
  static int estimatedWaitMinutes({
    required int patientsAhead,
    required int avgConsultMinutes,
    required bool someoneBeingServed,
  }) {
    if (patientsAhead < 0) return 0;
    final inRoom = someoneBeingServed ? (avgConsultMinutes / 2).round() : 0;
    return patientsAhead * avgConsultMinutes + inRoom;
  }

  /// The clock time the patient is expected to be called. Before the clinic
  /// opens the count starts from its start time, afterwards from [now].
  static DateTime expectedAt({
    required DateTime now,
    required DateTime clinicStart,
    required int patientsAhead,
    required int avgConsultMinutes,
    required bool someoneBeingServed,
  }) {
    final base = (someoneBeingServed || now.isAfter(clinicStart)) ? now : clinicStart;
    return base.add(Duration(
      minutes: estimatedWaitMinutes(
        patientsAhead: patientsAhead,
        avgConsultMinutes: avgConsultMinutes,
        someoneBeingServed: someoneBeingServed,
      ),
    ));
  }

  /// Which step of the visit the patient is on, for the progress timeline:
  /// 0 booked, 1 checked in, 2 turn is near, 3 with the doctor, 4 done.
  static int journeyStep({required String status, required bool arrived, required QueueState state}) {
    if (status == 'completed') return 4;
    if (status == 'serving' || state == QueueState.yourTurn) return 3;
    if (state == QueueState.nearTurn) return 2;
    return arrived ? 1 : 0;
  }

  /// Near-turn threshold used for the amber S07b state and the notification.
  static const nearTurnThreshold = 2;

  static QueueState stateFor({
    required String appointmentId,
    required String? currentServingId,
    required List<String> waitingIds,
  }) {
    if (currentServingId == appointmentId) return QueueState.yourTurn;
    final ahead = patientsAhead(waitingIds, appointmentId);
    if (ahead < 0) return QueueState.notInQueue;
    if (ahead <= nearTurnThreshold) return QueueState.nearTurn;
    return QueueState.waiting;
  }

  /// Inserts [id] into the waiting list. Priority patients (S10) go after
  /// any existing priority patients but ahead of everyone else.
  static List<String> insert(
    List<String> waitingIds,
    String id, {
    bool priority = false,
    Set<String> priorityIds = const {},
  }) {
    final list = List<String>.from(waitingIds)..remove(id);
    if (!priority) return list..add(id);
    var pos = 0;
    while (pos < list.length && priorityIds.contains(list[pos])) {
      pos++;
    }
    list.insert(pos, id);
    return list;
  }

  /// Moves [id] one place up (-1) or down (+1) in the list.
  static List<String> move(List<String> waitingIds, String id, int delta) {
    final list = List<String>.from(waitingIds);
    final i = list.indexOf(id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return list;
    list[i] = list[j];
    list[j] = id;
    return list;
  }

  /// Skips a patient back by [places] (they were called but are not here yet).
  /// They keep their place in the queue instead of losing it, just later.
  static List<String> skip(List<String> waitingIds, String id, {int places = 3}) {
    final list = List<String>.from(waitingIds);
    final i = list.indexOf(id);
    if (i < 0) return list;
    list.removeAt(i);
    list.insert((i + places).clamp(0, list.length), id);
    return list;
  }

  /// Whether a session still has capacity for another booking.
  static bool hasCapacity(int bookedCount, int capacity) => bookedCount < capacity;
}

enum QueueState { waiting, nearTurn, yourTurn, notInQueue }

class HistoryLogic {
  static List<String> hospitalNamesInOrder(Iterable<String> values) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final value in values) {
      final name = value.trim();
      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
      ordered.add(name);
    }
    return ordered;
  }
}

/// Input validation shared by registration, check-in and record screens.
class Validators {
  /// Sri Lankan NIC: old format 9 digits + V/X, new format 12 digits.
  static final _oldNic = RegExp(r'^[0-9]{9}[vVxX]$');
  static final _newNic = RegExp(r'^[0-9]{12}$');
  static final _mobile = RegExp(r'^0[0-9]{9}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static final _name = RegExp(r"^[\p{L}][\p{L}\p{M} .'\-]*$", unicode: true);

  static String? nic(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'NIC is required';
    if (!_oldNic.hasMatch(s) && !_newNic.hasMatch(s)) {
      return 'Enter a valid NIC (e.g. 851234567V or 198512345678)';
    }
    // The number must also encode a real birth date that is not in the future.
    final dob = dobFromNic(s);
    if (dob == null || dob.isAfter(DateTime.now())) {
      return 'This NIC number is not valid. Please check the digits.';
    }
    return null;
  }

  /// A person's name: letters (any script, so Sinhala and Tamil work),
  /// spaces and . ' - only, 3 to 80 characters.
  static String? personName(String? v, [String field = 'Name']) {
    final s = (v ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return '$field is required';
    if (s.length < 3) return '$field must be at least 3 characters';
    if (s.length > 80) return '$field must be 80 characters or fewer';
    if (!_name.hasMatch(s)) return '$field can only contain letters, spaces and . \' -';
    return null;
  }

  /// Free text with an upper length limit. Empty is allowed unless [min] > 0.
  static String? text(String? v, {required String field, int min = 0, int max = 200}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return min > 0 ? '$field is required' : null;
    if (s.length < min) return '$field must be at least $min characters';
    if (s.length > max) return '$field must be $max characters or fewer';
    return null;
  }

  /// Optional mobile number: blank is fine, otherwise it must be valid.
  static String? optionalMobile(String? v) => (v ?? '').trim().isEmpty ? null : mobile(v);

  /// Strength rule used when CREATING a password (registration).
  static String? newPassword(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Use at least 8 characters';
    if (s.length > 64) return 'Use 64 characters or fewer';
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'[0-9]').hasMatch(s)) {
      return 'Include at least one letter and one number';
    }
    if (s.contains(' ')) return 'Password cannot contain spaces';
    return null;
  }

  /// Sign-in only checks that something was typed, so accounts made under an
  /// older, looser rule can still sign in.
  static String? passwordRequired(String? v) => (v ?? '').isEmpty ? 'Password is required' : null;

  /// Date of birth for a patient record: required, in the past, not > 120 years.
  static String? dob(DateTime? d) {
    if (d == null) return 'Date of birth is required';
    final now = DateTime.now();
    if (d.isAfter(now)) return 'Date of birth cannot be in the future';
    if (now.year - d.year > 120) return 'Please check the date of birth';
    return null;
  }

  static String? optionalNic(String? v) => (v ?? '').trim().isEmpty ? null : nic(v);

  static String? mobile(String? v) {
    final s = (v ?? '').replaceAll(' ', '');
    if (s.isEmpty) return 'Mobile number is required';
    if (!_mobile.hasMatch(s)) return 'Enter a 10-digit number starting with 0';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    if (!_email.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    if ((v ?? '').length < 6) return 'Use at least 6 characters';
    return null;
  }

  static String? required(String? v, [String field = 'This field']) =>
      (v ?? '').trim().isEmpty ? '$field is required' : null;

  static String normaliseNic(String nic) => nic.trim().toUpperCase();

  /// Derives date of birth from a Sri Lankan NIC. Day-of-year > 500 means
  /// female. Returns null if the NIC is not valid.
  static DateTime? dobFromNic(String nic) {
    final s = nic.trim();
    int year;
    int days;
    if (_oldNic.hasMatch(s)) {
      year = 1900 + int.parse(s.substring(0, 2));
      days = int.parse(s.substring(2, 5));
    } else if (_newNic.hasMatch(s)) {
      year = int.parse(s.substring(0, 4));
      days = int.parse(s.substring(4, 7));
    } else {
      return null;
    }
    if (days > 500) days -= 500;
    if (days < 1 || days > 366) return null;
    // NIC day numbering treats every February as having 29 days.
    const monthDays = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    var month = 0;
    while (month < 12 && days > monthDays[month]) {
      days -= monthDays[month];
      month++;
    }
    if (month >= 12) return null;
    return DateTime(year, month + 1, days);
  }

  static String? genderFromNic(String nic) {
    final s = nic.trim();
    String part;
    if (_oldNic.hasMatch(s)) {
      part = s.substring(2, 5);
    } else if (_newNic.hasMatch(s)) {
      part = s.substring(4, 7);
    } else {
      return null;
    }
    return int.parse(part) > 500 ? 'Female' : 'Male';
  }
}

/// Date helpers. Sessions are stored with a `dateKey` (yyyy-MM-dd) so that
/// equality queries need no composite Firestore index.
class DateKeys {
  static String of(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime startOfWeek(DateTime d) => dayOnly(d).subtract(Duration(days: d.weekday - 1));

  /// Parses "08:30" into minutes after midnight; returns null if invalid.
  static int? minutesOf(String hhmm) {
    final m = RegExp(r'^([01]?[0-9]|2[0-3]):([0-5][0-9])$').firstMatch(hhmm.trim());
    if (m == null) return null;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  /// The moment a clinic on [date] ends, given its "HH:mm" [endTime].
  static DateTime endOf(DateTime date, String endTime) =>
      dayOnly(date).add(Duration(minutes: minutesOf(endTime) ?? 24 * 60));

  /// The moment a clinic on [date] starts, given its "HH:mm" [startTime].
  static DateTime startOf(DateTime date, String startTime) =>
      dayOnly(date).add(Duration(minutes: minutesOf(startTime) ?? 0));

  /// True when the clinic has already finished, so nobody can join it.
  static bool hasEnded(DateTime date, String endTime, [DateTime? now]) =>
      !endOf(date, endTime).isAfter(now ?? DateTime.now());

  /// True when two time ranges on the same day overlap (S18 conflict check).
  static bool overlaps(String aStart, String aEnd, String bStart, String bEnd) {
    final as = minutesOf(aStart), ae = minutesOf(aEnd);
    final bs = minutesOf(bStart), be = minutesOf(bEnd);
    if (as == null || ae == null || bs == null || be == null) return false;
    return as < be && bs < ae;
  }
}
