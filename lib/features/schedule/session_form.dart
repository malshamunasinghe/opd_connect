import 'package:flutter/material.dart';

import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../models/hospital.dart';
import '../../services/booking_service.dart';
import 'hospitals_screen.dart';

/// Values collected by the session form (S18 create / S20 edit).
class SessionFormValues {
  final Hospital? hospital;
  final String department;
  final String doctorName;
  final String room;
  final DateTime date;
  final String startTime;
  final String endTime;
  final int capacity;
  final String tokenPrefix;
  final int avgConsultMinutes;
  final bool remindersEnabled;
  final int reminderHoursBefore;
  final String notes;

  const SessionFormValues({
    required this.hospital,
    required this.department,
    required this.doctorName,
    required this.room,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.tokenPrefix,
    required this.avgConsultMinutes,
    required this.remindersEnabled,
    required this.reminderHoursBefore,
    required this.notes,
  });
}

/// Shared clinic-session form. Owner: Nethmini K (IT23669130)
class SessionForm extends StatefulWidget {
  final ClinicSession? initial;
  final DateTime? initialDate;
  final String submitLabel;
  final bool busy;
  final ValueChanged<SessionFormValues> onSubmit;

  const SessionForm({
    super.key,
    this.initial,
    this.initialDate,
    required this.submitLabel,
    required this.busy,
    required this.onSubmit,
  });

  @override
  State<SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<SessionForm> {
  static const departments = [
    'General OPD',
    'Medical Clinic',
    'Diabetic Clinic',
    'Eye Clinic',
    'Paediatric Clinic',
    'Dental Clinic'
  ];
  static const reminderOptions = [2, 6, 12, 24, 48];

  final _formKey = GlobalKey<FormState>();
  final _hospitalsStream = BookingService.hospitals();
  late final TextEditingController _dept;
  late final TextEditingController _doctor;
  late final TextEditingController _room;
  late final TextEditingController _capacity;
  late final TextEditingController _prefix;
  late final TextEditingController _avg;
  late final TextEditingController _notes;
  String? _hospitalId;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late bool _reminders;
  late int _reminderHours;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _dept = TextEditingController(text: s?.department ?? 'General OPD');
    _doctor = TextEditingController(text: s?.doctorName ?? '');
    _room = TextEditingController(text: s?.room ?? '');
    _capacity = TextEditingController(text: '${s?.capacity ?? 30}');
    _prefix = TextEditingController(text: s?.tokenPrefix ?? 'A');
    _avg = TextEditingController(text: '${s?.avgConsultMinutes ?? 8}');
    _notes = TextEditingController(text: s?.notes ?? '');
    _hospitalId = s?.hospitalId;
    _date = s?.date ?? widget.initialDate ?? DateKeys.dayOnly(DateTime.now().add(const Duration(days: 1)));
    _start = _parse(s?.startTime ?? '08:00');
    _end = _parse(s?.endTime ?? '12:00');
    _reminders = s?.remindersEnabled ?? true;
    _reminderHours = reminderOptions.contains(s?.reminderHoursBefore) ? s!.reminderHoursBefore : 24;
  }

  @override
  void dispose() {
    for (final c in [_dept, _doctor, _room, _capacity, _prefix, _avg, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  static TimeOfDay _parse(String hhmm) {
    final m = DateKeys.minutesOf(hhmm) ?? 480;
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  static String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final today = DateKeys.dayOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool start) async {
    final t = await showTimePicker(context: context, initialTime: start ? _start : _end);
    if (t != null) setState(() => start ? _start = t : _end = t);
  }

  void _submit(List<Hospital> hospitals) {
    if (!_formKey.currentState!.validate()) return;
    final startMin = _start.hour * 60 + _start.minute;
    final endMin = _end.hour * 60 + _end.minute;
    if (startMin >= endMin) {
      showSnack(context, 'End time must be after start time', error: true);
      return;
    }
    if (endMin - startMin < 30) {
      showSnack(context, 'A clinic session must run for at least 30 minutes', error: true);
      return;
    }
    final avg = int.parse(_avg.text.trim());
    final cap = int.parse(_capacity.text.trim());
    if (cap * avg > (endMin - startMin) * 2) {
      showSnack(
          context,
          'Capacity is too high: $cap patients x $avg min does not fit in this session '
          '(${endMin - startMin} min). Lower the capacity or extend the hours.',
          error: true);
      return;
    }
    // A session that has already ended (or started) today cannot be created
    // or moved into the past; editing other details of a past session is fine.
    final startsAt = DateKeys.startOf(_date, _fmt(_start));
    final timeChanged = !_editing ||
        DateKeys.of(_date) != widget.initial!.dateKey ||
        _fmt(_start) != widget.initial!.startTime;
    if (timeChanged && startsAt.isBefore(DateTime.now())) {
      showSnack(context, 'The start time has already passed. Choose a later time or date.', error: true);
      return;
    }
    final hospital = hospitals.where((h) => h.id == _hospitalId).firstOrNull;
    if (!_editing && hospital == null) {
      showSnack(context, 'Choose a hospital', error: true);
      return;
    }
    widget.onSubmit(SessionFormValues(
      hospital: hospital,
      department: _dept.text.trim(),
      doctorName: _doctor.text.trim(),
      room: _room.text.trim(),
      date: DateKeys.dayOnly(_date),
      startTime: _fmt(_start),
      endTime: _fmt(_end),
      capacity: int.parse(_capacity.text.trim()),
      tokenPrefix: _prefix.text.trim().toUpperCase(),
      avgConsultMinutes: int.parse(_avg.text.trim()),
      remindersEnabled: _reminders,
      reminderHoursBefore: _reminderHours,
      notes: _notes.text.trim(),
    ));
  }

  String? _intValidator(String? v, {int min = 1, int max = 500}) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a number';
    if (n < min || n > max) return 'Must be between $min and $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final booked = widget.initial?.bookedCount ?? 0;
    return StreamView<List<Hospital>>(
      stream: _hospitalsStream,
      builder: (context, hospitals) => Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_editing)
              InfoRow('Hospital', widget.initial!.hospitalName, icon: Icons.local_hospital_outlined)
            else if (hospitals.isEmpty)
              InfoBanner(
                icon: Icons.local_hospital_outlined,
                color: AppColors.accent,
                message: 'No hospitals have been added yet. Add a hospital first, then create its clinic.',
                action: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalFormScreen())),
                  child: const Text('Add hospital'),
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _hospitalId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Hospital *'),
                items: [
                  for (final h in hospitals)
                    DropdownMenuItem(value: h.id, child: Text(h.name, overflow: TextOverflow.ellipsis)),
                ],
                validator: (v) => v == null ? 'Choose a hospital' : null,
                onChanged: (v) => setState(() => _hospitalId = v),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalFormScreen())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Hospital not listed? Add it'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            AppInput(
              label: 'Clinic / department *',
              controller: _dept,
              validator: (v) => Validators.text(v, field: 'Department', min: 3, max: 50),
            ),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final d in departments) ActionChip(label: Text(d), onPressed: () => setState(() => _dept.text = d)),
            ]),
            const SizedBox(height: 16),
            AppInput(
              label: 'Doctor *',
              hint: 'Dr. N. Perera',
              controller: _doctor,
              capitalization: TextCapitalization.words,
              validator: (v) => Validators.personName(v, 'Doctor name'),
            ),
            AppInput(
              label: 'Room',
              hint: 'OPD Room 1',
              controller: _room,
              validator: (v) => Validators.text(v, field: 'Room', max: 30),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Date'),
              subtitle: Text(formatDay(_date), style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            Row(children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Start'),
                  subtitle: Text(_fmt(_start), style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => _pickTime(true),
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('End'),
                  subtitle: Text(_fmt(_end), style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => _pickTime(false),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: AppInput(
                  label: 'Capacity *',
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  validator: (v) => _intValidator(v, min: booked == 0 ? 1 : booked, max: 300),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppInput(
                  label: 'Avg. minutes',
                  controller: _avg,
                  keyboardType: TextInputType.number,
                  validator: (v) => _intValidator(v, min: 2, max: 60),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: AppInput(
                  label: 'Prefix',
                  controller: _prefix,
                  enabled: !_editing || (widget.initial?.lastToken ?? 0) == 0,
                  validator: (v) => RegExp(r'^[A-Za-z]{1,2}$').hasMatch((v ?? '').trim()) ? null : '1-2 letters',
                ),
              ),
            ]),
            if (booked > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('$booked patient(s) already booked - capacity cannot go below this.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _reminders,
              onChanged: (v) => setState(() => _reminders = v),
              title: const Text('Send appointment reminders'),
              subtitle: const Text('Patients who opted in get a reminder before the clinic'),
            ),
            if (_reminders)
              DropdownButtonFormField<int>(
                initialValue: _reminderHours,
                decoration: const InputDecoration(labelText: 'Remind patients'),
                items: [
                  for (final h in reminderOptions) DropdownMenuItem(value: h, child: Text('$h hours before')),
                ],
                onChanged: (v) => setState(() => _reminderHours = v ?? 24),
              ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Notes for staff',
              controller: _notes,
              maxLines: 2,
              validator: (v) => Validators.text(v, field: 'Notes', max: 300),
            ),
            const SizedBox(height: 8),
            PrimaryButton(widget.submitLabel, onPressed: () => _submit(hospitals), loading: widget.busy),
          ],
        ),
      ),
    );
  }
}
