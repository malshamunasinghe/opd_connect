import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../models/hospital.dart';
import '../../models/patient.dart';
import '../../services/booking_service.dart';
import '../../services/db.dart';
import 'booking_confirmation_screen.dart';

/// Opens step 3 (patient details + review) for [session]. Shared by the
/// booking flow and the Clinics browser.
Future<void> showBookingReview(BuildContext context, ClinicSession session) async {
  final s = context.read<AppSettings>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ReviewSheet(session: session, s: s, parentContext: context),
  );
}

/// S02 - Date and time slot selection (step 2 of 3) plus the review step
/// (step 3 of 3). Only real clinic days are shown: pick a clinic, pick a day
/// from the date strip, then pick a session.
/// Owner: Lakmali M.A.D.M (IT23679344)
/// CRUD: READ open sessions; CREATE appointment (transaction that also
///       UPDATES the session's token counter and live queue).
class BookSlotScreen extends StatelessWidget {
  final Hospital hospital;
  const BookSlotScreen({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('bookAppointment'))),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StepIndicator(current: 2, total: 3, stepWord: s.t('step')),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.local_hospital, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(hospital.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(s.t('chooseDay'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Expanded(
            child: SessionPicker(
              hospitalId: hospital.id,
              onPick: (session) => showBookingReview(context, session),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Clinic chips + date strip + session cards. Shared by S02 (book) and S05
/// (reschedule).
class SessionPicker extends StatefulWidget {
  final String hospitalId;
  final String? initialDepartment;
  final String? excludeSessionId;
  final ValueChanged<ClinicSession> onPick;

  /// Reschedule only: the clinic being moved. If it has no other open day,
  /// a banner explains why it is missing from the clinic chips.
  final String? currentDepartment;

  const SessionPicker({
    super.key,
    required this.hospitalId,
    required this.onPick,
    this.initialDepartment,
    this.excludeSessionId,
    this.currentDepartment,
  });

  @override
  State<SessionPicker> createState() => _SessionPickerState();
}

class _SessionPickerState extends State<SessionPicker> {
  late final Stream<List<ClinicSession>> _stream = BookingService.openSessions(widget.hospitalId);
  String? _department;
  String? _dateKey;
  bool _onlyAvailable = false;

  @override
  void initState() {
    super.initState();
    _department = widget.initialDepartment;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return StreamView<List<ClinicSession>>(
      stream: _stream,
      loadingMessage: s.t('loading'),
      builder: (context, all) {
        final sessions = all.where((x) => x.id != widget.excludeSessionId).toList();
        if (sessions.isEmpty) {
          return EmptyView(icon: Icons.event_busy, message: s.t('noSessions'));
        }
        final departments = sessions.map((x) => x.department).toSet().toList()..sort();
        final dept = departments.contains(_department) ? _department! : departments.first;
        final ofDept = sessions.where((x) => x.department == dept).toList();

        // One entry per calendar day that has a session of this clinic.
        final dayKeys = ofDept.map((x) => x.dateKey).toSet().toList()..sort();
        final dayKey = dayKeys.contains(_dateKey) ? _dateKey! : dayKeys.first;
        var shown = ofDept.where((x) => x.dateKey == dayKey).toList();
        if (_onlyAvailable) shown = shown.where((x) => !x.isFull).toList();
        final allFull = ofDept.where((x) => x.dateKey == dayKey).every((x) => x.isFull);

        final current = widget.currentDepartment;
        final currentMissing = current != null && !departments.contains(current);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (currentMissing) ...[
            InfoBanner(
              icon: Icons.info_outline,
              color: AppColors.accent,
              message: s.tf('noOtherDays', {'clinic': current}),
            ),
            const SizedBox(height: 12),
          ],
          Text(s.t('chooseClinic'), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final d in departments)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(Icons.medical_services_outlined,
                        size: 18, color: d == dept ? AppColors.primary : AppColors.n600),
                    label: Text(d),
                    selected: d == dept,
                    onSelected: (_) => setState(() {
                      _department = d;
                      _dateKey = null;
                    }),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dayKeys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final key = dayKeys[i];
                final day = ofDept.firstWhere((x) => x.dateKey == key).date;
                final daySessions = ofDept.where((x) => x.dateKey == key);
                return _DayChip(
                  date: day,
                  selected: key == dayKey,
                  full: daySessions.every((x) => x.isFull),
                  todayLabel: s.t('today'),
                  onTap: () => setState(() => _dateKey = key),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: Text(_dayHeading(s, shown.isEmpty ? ofDept.first.date : shown.first.date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            FilterChip(
              label: Text(s.t('availableOnly')),
              selected: _onlyAvailable,
              onSelected: (v) => setState(() => _onlyAvailable = v),
            ),
          ]),
          const SizedBox(height: 8),
          if (allFull)
            // Error state from M02: explain, and point to an alternative.
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoBanner(icon: Icons.info_outline, message: s.t('sessionFull'), color: AppColors.accent),
            ),
          Expanded(
            child: shown.isEmpty
                ? EmptyView(icon: Icons.event_busy, message: s.t('noSessionsDay'))
                : ListView.separated(
                    // Bottom padding shows part of the next card, hinting that
                    // the list scrolls (M02 issue U4).
                    padding: const EdgeInsets.only(bottom: 48),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _SessionCard(
                      session: shown[i],
                      s: s,
                      onPick: () => widget.onPick(shown[i]),
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  String _dayHeading(AppSettings s, DateTime d) {
    final today = DateKeys.dayOnly(DateTime.now());
    final diff = DateKeys.dayOnly(d).difference(today).inDays;
    if (diff == 0) return '${s.t('today')} · ${formatDay(d)}';
    if (diff == 1) return '${s.t('tomorrow')} · ${formatDay(d)}';
    return formatDay(d);
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final bool full;
  final String todayLabel;
  final VoidCallback onTap;
  const _DayChip({
    required this.date,
    required this.selected,
    required this.full,
    required this.todayLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = DateKeys.dayOnly(date) == DateKeys.dayOnly(DateTime.now());
    final fg = selected ? Colors.white : (full ? AppColors.n400 : AppColors.n900);
    return Semantics(
      button: true,
      selected: selected,
      label: '${formatDay(date)}${full ? ', full' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        onTap: onTap,
        child: Container(
          width: 64,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(AppSizes.radius),
            border: Border.all(color: selected ? AppColors.primary : AppColors.n200),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(isToday ? todayLabel : DateFormat('EEE').format(date),
                style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
            Text(DateFormat('d').format(date), style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(DateFormat('MMM').format(date), style: TextStyle(color: fg, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ClinicSession session;
  final AppSettings s;
  final VoidCallback onPick;
  const _SessionCard({required this.session, required this.s, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final x = session;
    final t = Theme.of(context).textTheme;
    final full = x.isFull;
    final ratio = x.capacity == 0 ? 1.0 : x.bookedCount / x.capacity;
    final color = full ? AppColors.danger : (x.placesLeft <= 5 ? AppColors.accent : AppColors.success);
    final seen = BookingService.estimatedSeenAt(x);
    return Opacity(
      opacity: full ? 0.6 : 1,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          onTap: full ? null : onPick,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.schedule, size: 20, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('${x.startTime} – ${x.endTime}', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Pill(full ? s.t('full') : '${x.placesLeft} ${s.t('slotsLeft')}', color: color),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.person_outline, size: 20, color: AppColors.n600),
                const SizedBox(width: 6),
                Expanded(child: Text(x.doctorName, style: t.bodyMedium)),
                if (x.room.isNotEmpty) ...[
                  const Icon(Icons.meeting_room_outlined, size: 18, color: AppColors.n600),
                  const SizedBox(width: 4),
                  Text(x.room, style: t.bodySmall),
                ],
              ]),
              const SizedBox(height: 10),
              MeterBar(value: ratio, color: color),
              const SizedBox(height: 4),
              Text(s.tf('bookedOf', {'a': '${x.bookedCount}', 'b': '${x.capacity}'}), style: t.bodySmall),
              if (!full) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.hourglass_bottom, size: 16, color: AppColors.n600),
                  const SizedBox(width: 6),
                  Text('${s.t('estimatedSeen')}: ~${DateFormat('h:mm a').format(seen)}', style: t.bodySmall),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  final ClinicSession session;
  final AppSettings s;
  final BuildContext parentContext;
  const _ReviewSheet({required this.session, required this.s, required this.parentContext});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  static const _relations = ['Child', 'Parent', 'Spouse', 'Sibling', 'Grandparent', 'Other'];

  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late final TextEditingController _name = TextEditingController(text: me(context).name);
  late final TextEditingController _phone = TextEditingController(text: me(context).phone);
  final _age = TextEditingController();
  final _nic = TextEditingController();
  Patient? _record;
  bool _forSelf = true;
  String _relation = _relations.first;
  String _gender = '';
  bool _reminder = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  /// Fill the patient's own details from their health record so they do not
  /// have to type them again.
  Future<void> _loadRecord() async {
    final id = me(context).patientId;
    if (id == null) return;
    try {
      final snap = await Db.patients.doc(id).get();
      if (!snap.exists || !mounted) return;
      final r = Patient.fromDoc(snap);
      setState(() {
        _record = r;
        if (_forSelf) _fillSelf();
      });
    } catch (_) {
      // Pre-filling is a convenience; the form still works without it.
    }
  }

  void _fillSelf() {
    final r = _record;
    _name.text = me(context).name;
    _phone.text = me(context).phone;
    _nic.text = r?.nic ?? '';
    _gender = const ['Male', 'Female', 'Other'].contains(r?.gender) ? r!.gender : '';
    _age.text = r?.age == null ? '' : '${r!.age}';
  }

  @override
  void dispose() {
    _reason.dispose();
    _name.dispose();
    _phone.dispose();
    _age.dispose();
    _nic.dispose();
    super.dispose();
  }

  void _setForSelf(bool self) {
    setState(() {
      _forSelf = self;
      if (self) {
        _fillSelf();
      } else {
        _name.clear();
        _nic.clear();
        _age.clear();
        _gender = '';
      }
    });
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender.isEmpty) {
      showSnack(context, widget.s.t('selectGender'), error: true);
      return;
    }
    setState(() => _busy = true);
    final profile = me(context);
    final nav = Navigator.of(widget.parentContext);
    try {
      final id = await BookingService.book(
        user: profile,
        session: widget.session,
        reminder: _reminder,
        visitReason: _reason.text,
        patientName: _name.text,
        patientPhone: _phone.text,
        relation: _forSelf ? '' : _relation,
        patientAge: int.tryParse(_age.text.trim()),
        patientNic: _nic.text,
        patientGender: _gender,
      );
      if (!mounted) return;
      Navigator.pop(context);
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => BookingConfirmationScreen(appointmentId: id)),
        (r) => r.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final msg = e is AppException && e.code == 'full' ? widget.s.t('sessionFull') : friendlyError(e);
      showSnack(context, msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final x = widget.session;
    final seen = BookingService.estimatedSeenAt(x);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            StepIndicator(current: 3, total: 3, stepWord: s.t('step')),
            const SizedBox(height: 16),
            Text(s.t('confirmBooking'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            InfoRow(s.t('hospital'), x.hospitalName, icon: Icons.local_hospital_outlined),
            InfoRow(s.t('clinic'), x.department, icon: Icons.medical_services_outlined),
            InfoRow(s.t('doctor'), x.doctorName, icon: Icons.person_outline),
            InfoRow(s.t('date'), formatDay(x.date), icon: Icons.event),
            InfoRow(s.t('time'), '${x.startTime} – ${x.endTime}', icon: Icons.schedule),
            if (x.room.isNotEmpty) InfoRow(s.t('room'), x.room, icon: Icons.meeting_room_outlined),
            InfoRow(s.t('expectedShort'), '~${DateFormat('h:mm a').format(seen)}', icon: Icons.hourglass_bottom),
            const Divider(height: 24),
            Text(s.t('patientDetails'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(s.t('myself')), icon: const Icon(Icons.person)),
                ButtonSegment(value: false, label: Text(s.t('someoneElse')), icon: const Icon(Icons.family_restroom)),
              ],
              selected: {_forSelf},
              onSelectionChanged: (v) => _setForSelf(v.first),
            ),
            const SizedBox(height: 16),
            if (!_forSelf) ...[
              DropdownButtonFormField<String>(
                initialValue: _relation,
                decoration: InputDecoration(labelText: s.t('relationship')),
                items: [for (final r in _relations) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => setState(() => _relation = v ?? _relation),
              ),
              const SizedBox(height: 16),
            ],
            AppInput(
              label: _forSelf ? s.t('patientName') : s.t('patientFullName'),
              controller: _name,
              capitalization: TextCapitalization.words,
              validator: (v) => Validators.personName(v, 'Name'),
            ),
            AppInput(
              label: _forSelf ? s.t('mobileNumber') : s.t('contactNumber'),
              hint: '07XXXXXXXX',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: Validators.mobile,
            ),
            AppInput(
              label: _forSelf ? s.t('nicNumber') : s.t('nicOptionalChild'),
              hint: '851234567V or 198512345678',
              controller: _nic,
              enabled: !(_forSelf && (_record?.nic.isNotEmpty ?? false)),
              validator: _forSelf ? Validators.nic : Validators.optionalNic,
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: AppInput(
                  label: s.t('ageYears'),
                  controller: _age,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null) return 'Enter the age';
                    if (n < 0 || n > 120) return 'Age must be 0–120';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('gender-$_gender'),
                    initialValue: _gender.isEmpty ? null : _gender,
                    decoration: InputDecoration(labelText: s.t('genderReq')),
                    items: [
                      DropdownMenuItem(value: 'Male', child: Text(s.t('male'))),
                      DropdownMenuItem(value: 'Female', child: Text(s.t('female'))),
                      DropdownMenuItem(value: 'Other', child: Text(s.t('other'))),
                    ],
                    onChanged: (v) => setState(() => _gender = v ?? ''),
                  ),
                ),
              ),
            ]),
            AppInput(
              label: s.t('reasonForVisit'),
              hint: s.t('reasonHint'),
              controller: _reason,
              maxLines: 2,
              validator: (v) => Validators.text(v, field: 'Reason', max: 200),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _reminder,
              onChanged: x.remindersEnabled ? (v) => setState(() => _reminder = v) : null,
              title: Text(s.t('remindMe')),
              subtitle: x.remindersEnabled ? Text(s.tf('hoursBeforeClinic', {'n': '${x.reminderHoursBefore}'})) : null,
            ),
            InfoBanner(
              icon: Icons.badge_outlined,
              message: s.t('bringNic'),
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            PrimaryButton(s.t('confirmBooking'), onPressed: _confirm, loading: _busy),
            const SizedBox(height: 8),
            SecondaryButton(s.t('back'), onPressed: _busy ? null : () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}
