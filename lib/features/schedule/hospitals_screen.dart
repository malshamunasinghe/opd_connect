import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/hospital.dart';
import '../../services/booking_service.dart';
import '../../services/hospital_service.dart';

/// Staff: the list of hospitals patients can book at. Add, edit, delete.
/// CRUD: CREATE / READ / UPDATE / DELETE hospitals.
class HospitalsScreen extends StatefulWidget {
  const HospitalsScreen({super.key});

  @override
  State<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends State<HospitalsScreen> {
  late final Stream<List<Hospital>> _stream = BookingService.hospitals();

  Future<void> _open([Hospital? h]) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => HospitalFormScreen(hospital: h)));

  Future<void> _delete(Hospital h) async {
    final ok = await confirm(context,
        title: 'Delete ${h.name}?',
        message: 'This cannot be undone. A hospital that already has clinic sessions cannot be deleted.',
        confirmLabel: 'Delete',
        danger: true);
    if (ok && mounted) await runGuarded(context, () => HospitalService.delete(h), success: 'Hospital deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hospitals')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Add hospital'),
      ),
      body: StreamView<List<Hospital>>(
        stream: _stream,
        builder: (context, list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.local_hospital_outlined,
              message: 'No hospitals yet.\nAdd the first hospital so clinics can be scheduled and patients can book.',
              actionLabel: 'Add hospital',
              onAction: () => _open(),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final h = list[i];
              return Card(
                child: ListTile(
                  minVerticalPadding: 12,
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.n50,
                    child: Icon(Icons.local_hospital, color: AppColors.primary),
                  ),
                  title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([h.address, h.district, h.phone].where((e) => e.isNotEmpty).join(' · ')),
                  onTap: () => _open(h),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? _open(h) : _delete(h),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Add or edit one hospital.
class HospitalFormScreen extends StatefulWidget {
  final Hospital? hospital;
  const HospitalFormScreen({super.key, this.hospital});

  @override
  State<HospitalFormScreen> createState() => _HospitalFormScreenState();
}

class _HospitalFormScreenState extends State<HospitalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.hospital?.name ?? '');
  late final _address = TextEditingController(text: widget.hospital?.address ?? '');
  late final _phone = TextEditingController(text: widget.hospital?.phone ?? '');
  late String? _district = Hospital.districts.contains(widget.hospital?.district) ? widget.hospital!.district : null;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final h = widget.hospital;
    final ok = await runGuarded(
      context,
      () => h == null
          ? HospitalService.create(
              name: _name.text,
              district: _district!,
              address: _address.text,
              phone: _phone.text,
              staffUid: me(context).uid,
            )
          : HospitalService.update(h, name: _name.text, district: _district!, address: _address.text, phone: _phone.text),
      success: h == null ? 'Hospital added' : 'Hospital updated',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.hospital != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit hospital' : 'Add hospital')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppInput(
              label: 'Hospital name *',
              hint: 'e.g. District General Hospital, Negombo',
              controller: _name,
              capitalization: TextCapitalization.words,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Hospital name is required';
                if (s.length < 5) return 'Enter the full hospital name';
                if (s.length > 80) return 'Name must be 80 characters or fewer';
                return null;
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _district,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'District *'),
              items: [for (final d in Hospital.districts) DropdownMenuItem(value: d, child: Text(d))],
              validator: (v) => v == null ? 'Choose the district' : null,
              onChanged: (v) => setState(() => _district = v),
            ),
            const SizedBox(height: 16),
            AppInput(
              label: 'Town / address *',
              hint: 'e.g. Chilaw Road, Negombo',
              controller: _address,
              maxLines: 2,
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return 'Address is required';
                if (s.length < 3) return 'Address is too short';
                if (s.length > 120) return 'Address must be 120 characters or fewer';
                return null;
              },
            ),
            AppInput(
              label: 'Telephone (optional)',
              hint: '0311234567',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: Validators.optionalMobile,
            ),
            const SizedBox(height: 8),
            PrimaryButton(editing ? 'Save changes' : 'Add hospital', icon: Icons.check, onPressed: _save, loading: _busy),
          ],
        ),
      ),
    );
  }
}
