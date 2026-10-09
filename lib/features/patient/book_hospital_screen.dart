import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../models/hospital.dart';
import '../../services/booking_service.dart';
import 'book_slot_screen.dart';

/// S01 - Book appointment: hospital selection (step 1 of 3). F1, NF2.
/// One decision per screen. Each hospital shows how many clinics are open
/// today so the patient can see where they can be seen soonest.
/// Owner: Lakmali M.A.D.M (IT23679344)
/// CRUD: READ hospitals and today's clinics; UPDATE the patient's last-used
///       hospital.
class BookHospitalScreen extends StatefulWidget {
  const BookHospitalScreen({super.key});

  @override
  State<BookHospitalScreen> createState() => _BookHospitalScreenState();
}

class _BookHospitalScreenState extends State<BookHospitalScreen> {
  final _search = TextEditingController();
  late final _hospitals = BookingService.hospitals();
  late final _today = BookingService.clinicsToday();
  String _query = '';
  String? _district;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _choose(Hospital h) async {
    final uid = me(context).uid;
    // Fire-and-forget: remembering the choice must not slow the flow down.
    BookingService.rememberHospital(uid, h.id).catchError((_) {});
    await Navigator.push(context, MaterialPageRoute(builder: (_) => BookSlotScreen(hospital: h)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final lastId = context.watch<CurrentUser>().profile?.lastHospitalId;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('bookAppointment'))),
      body: StreamView<List<Hospital>>(
        stream: _hospitals,
        loadingMessage: s.t('loading'),
        builder: (context, hospitals) => StreamView<List<ClinicSession>>(
          stream: _today,
          builder: (context, todays) {
            final districts = hospitals.map((h) => h.district).where((d) => d.isNotEmpty).toSet().toList()..sort();
            final list = hospitals
                .where((h) =>
                    (_district == null || h.district == _district) &&
                    (_query.isEmpty ||
                        h.name.toLowerCase().contains(_query) ||
                        h.district.toLowerCase().contains(_query) ||
                        h.address.toLowerCase().contains(_query)))
                .toList()
              ..sort((a, b) {
                // Last-used first, then the ones with clinics today, then A-Z.
                int rank(Hospital h) => h.id == lastId ? 0 : (todays.any((t) => t.hospitalId == h.id) ? 1 : 2);
                final c = rank(a).compareTo(rank(b));
                return c != 0 ? c : a.name.compareTo(b.name);
              });

            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  StepIndicator(current: 1, total: 3, stepWord: s.t('step')),
                  const SizedBox(height: 16),
                  Text(s.t('chooseHospital'), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: s.t('searchHospital'),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _search.clear();
                                _query = '';
                              }),
                            ),
                    ),
                  ),
                  if (districts.length > 1) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s.t('all')),
                            selected: _district == null,
                            onSelected: (_) => setState(() => _district = null),
                          ),
                        ),
                        for (final d in districts)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(d),
                              selected: _district == d,
                              onSelected: (_) => setState(() => _district = _district == d ? null : d),
                            ),
                          ),
                      ]),
                    ),
                  ],
                ]),
              ),
              Expanded(
                child: list.isEmpty
                    ? EmptyView(
                        icon: Icons.local_hospital_outlined,
                        message: hospitals.isEmpty
                            ? s.t('noHospitalsYet')
                            : s.t('noHospitalsMatch'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final h = list[i];
                          final open = todays.where((t) => t.hospitalId == h.id).toList();
                          return _HospitalCard(
                            hospital: h,
                            isLast: h.id == lastId,
                            openToday: open.length,
                            placesToday: open.fold<int>(0, (a, b) => a + b.placesLeft),
                            lastLabel: s.t('lastUsed'),
                            onTap: () => _choose(h),
                          );
                        },
                      ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final Hospital hospital;
  final bool isLast;
  final int openToday;
  final int placesToday;
  final String lastLabel;
  final VoidCallback onTap;
  const _HospitalCard({
    required this.hospital,
    required this.isLast,
    required this.openToday,
    required this.placesToday,
    required this.lastLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      shape: isLast
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radius),
              side: const BorderSide(color: AppColors.primary, width: 1.5))
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.n50,
                child: Icon(Icons.local_hospital, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (isLast)
                    Text(lastLabel,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(hospital.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text([hospital.address, hospital.district].where((e) => e.isNotEmpty).join(' · '),
                      style: t.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right, size: 28),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (openToday > 0)
                Pill(context.watch<AppSettings>().tf('clinicsTodayPill', {'n': '$openToday', 'm': '$placesToday'}),
                    color: AppColors.success, icon: Icons.bolt)
              else
                Pill(context.watch<AppSettings>().t('noClinicsPill'), color: AppColors.n600, icon: Icons.event_busy),
            ]),
          ]),
        ),
      ),
    );
  }
}
