import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../models/patient.dart';
import '../../services/db.dart';
import '../../services/queue_service.dart';
import '../records/register_patient_screen.dart';
import 'priority_sheet.dart';

/// S09 - Walk-in check-in and token generation (F5).
/// Staff Q8: digital check-in and automatic queue numbers were the two most
/// requested staff features (83.3% each).
/// Owner: P.A.J. Sithmini (IT23671874)
/// CRUD: READ (look up an existing record by NIC/phone);
///       CREATE (appointment + token, inserted into the live queue).
class WalkInScreen extends StatefulWidget {
  final ClinicSession session;
  final Set<String> priorityIds;
  const WalkInScreen({super.key, required this.session, required this.priorityIds});

  @override
  State<WalkInScreen> createState() => _WalkInScreenState();
}

class _WalkInScreenState extends State<WalkInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lookup = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Patient? _patient;
  bool _searching = false;
  bool _searched = false;
  bool _priority = false;
  String _priorityReason = PriorityReasons.all.first;
  bool _busy = false;
  // A future clinic day can only be a phone/assisted booking (F1).
  late bool _byPhone = DateKeys.dayOnly(widget.session.date).isAfter(DateKeys.dayOnly(DateTime.now()));

  @override
  void dispose() {
    _lookup.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// The search box takes a NIC or a mobile number, nothing else.
  String? _lookupError(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    if (Validators.nic(s) == null || Validators.mobile(s) == null) return null;
    return 'Enter a valid NIC (851234567V / 198512345678) or a mobile number (07XXXXXXXX)';
  }

  Future<void> _find() async {
    if (_lookup.text.trim().isEmpty) {
      showSnack(context, 'Type a NIC or mobile number to search', error: true);
      return;
    }
    final err = _lookupError(_lookup.text);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    setState(() => _searching = true);
    try {
      final p = await QueueService.findPatient(_lookup.text);
      if (!mounted) return;
      setState(() {
        _patient = p;
        _searched = true;
        if (p != null) {
          _name.text = p.fullName;
          _phone.text = p.phone;
          // Elderly patients are suggested for priority (Staff Q5).
          if ((p.age ?? 0) >= 70 && !_priority) {
            _priority = true;
            _priorityReason = 'Elderly (70+)';
          }
        }
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _registerNew() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => RegisterPatientScreen(initialNic: _lookup.text.trim())),
    );
    if (id != null && mounted) {
      _lookup.text = _lookup.text.trim();
      await _find();
    }
  }

  Future<void> _issue() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_byPhone && DateKeys.hasEnded(widget.session.date, widget.session.endTime)) {
      showSnack(context, 'This clinic has already finished (${widget.session.endTime}). Walk-ins can no longer be added.',
          error: true);
      return;
    }
    if (widget.session.isFull) {
      final ok = await confirm(context,
          title: 'Clinic is full',
          message: '${widget.session.bookedCount} of ${widget.session.capacity} places are taken. '
              'Issue a token anyway?',
          confirmLabel: 'Issue anyway');
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final label = await QueueService.walkIn(
        session: widget.session,
        name: _name.text,
        phone: _phone.text,
        patient: _patient,
        priority: _priority,
        priorityReason: _priorityReason,
        staffUid: me(context).uid,
        currentPriorityIds: widget.priorityIds,
        channel: _byPhone ? 'phone' : 'walkIn',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
          title: const Text('Token issued'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TokenChip(label, fontSize: 40),
            const SizedBox(height: 12),
            Text('${_name.text.trim()}\n${widget.session.department} · ${widget.session.room}',
                textAlign: TextAlign.center),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Scaffold(
      appBar: AppBar(title: Text(_byPhone ? 'Phone / assisted booking' : 'Walk-in check-in')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${s.department} · ${s.hospitalName}', style: Theme.of(context).textTheme.bodySmall),
            Text('Next token: ${QueueLogic.tokenLabel(s.tokenPrefix, s.lastToken + 1)}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: AppInput(
                  label: 'Find patient (NIC or mobile)',
                  controller: _lookup,
                  hint: '851234567V / 0771234567',
                  validator: _lookupError,
                  onChanged: (_) {
                    // A new search invalidates the previous result.
                    if (_searched) setState(() => _searched = false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: 56,
                  height: 52,
                  child: IconButton.filled(
                    tooltip: 'Search',
                    onPressed: _searching ? null : _find,
                    icon: _searching
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                  ),
                ),
              ),
            ]),
            if (_searched && _patient != null)
              Card(
                color: AppColors.success.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.verified_user, color: AppColors.success),
                  title: Text(_patient!.fullName),
                  subtitle: Text('${_patient!.nic} · ${_patient!.age ?? '-'} yrs'
                      '${_patient!.allergies.isNotEmpty ? ' · Allergies: ${_patient!.allergies}' : ''}'),
                ),
              ),
            if (_searched && _patient == null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_search),
                  title: const Text('No record found'),
                  subtitle: const Text('Register them now, or issue a token with just a name.'),
                  trailing: TextButton(onPressed: _registerNew, child: const Text('Register')),
                ),
              ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Patient name',
              controller: _name,
              capitalization: TextCapitalization.words,
              validator: (v) => Validators.personName(v, 'Name'),
            ),
            AppInput(
              label: _byPhone ? 'Mobile number *' : 'Mobile number (optional)',
              hint: '07XXXXXXXX',
              controller: _phone,
              keyboardType: TextInputType.phone,
              // A phone / assisted booking must have a number so the patient can be told about changes.
              validator: _byPhone ? Validators.mobile : Validators.optionalMobile,
            ),
            if (_searched && _patient != null && _name.text.trim() != _patient!.fullName)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InfoBanner(
                  icon: Icons.warning_amber,
                  color: AppColors.accent,
                  message: 'The name differs from the record (${_patient!.fullName}). Check you have the right person.',
                ),
              ),
            if (widget.session.isFull)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: InfoBanner(
                  icon: Icons.event_seat,
                  color: AppColors.danger,
                  message: 'This clinic is full. A walk-in is still accepted, but it goes over capacity.',
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _byPhone,
              onChanged: (v) => setState(() => _byPhone = v),
              title: const Text('Booking by phone / on behalf of patient'),
              subtitle: const Text('Patient is not here yet - they will show this token on arrival'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _priority,
              onChanged: (v) => setState(() => _priority = v),
              title: const Text('Priority patient'),
              subtitle: const Text('Elderly, disabled, pregnant or urgent'),
            ),
            if (_priority)
              DropdownButtonFormField<String>(
                initialValue: _priorityReason,
                decoration: const InputDecoration(labelText: 'Priority reason'),
                items: [for (final r in PriorityReasons.all) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => setState(() => _priorityReason = v ?? _priorityReason),
              ),
            const SizedBox(height: 24),
            PrimaryButton('Issue token', icon: Icons.confirmation_number, onPressed: _issue, loading: _busy),
          ],
        ),
      ),
    );
  }
}
