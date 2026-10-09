import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_settings.dart';
import '../../core/logic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/clinic_session.dart';
import '../../services/booking_service.dart';
import 'book_slot_screen.dart';

/// Clinics: every open clinic at every hospital in one list, grouped by day.
/// For today's clinics it shows the live queue (token being served, people
/// waiting) so a patient can decide where to go before booking.
class ClinicsScreen extends StatefulWidget {
  const ClinicsScreen({super.key});

  @override
  State<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends State<ClinicsScreen> {
  late final Stream<List<ClinicSession>> _stream = BookingService.allOpenSessions();
  final _search = TextEditingController();
  String _query = '';
  String? _hospital;
  String? _department;
  bool _onlyAvailable = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _dayLabel(AppSettings s, DateTime d) {
    final diff = DateKeys.dayOnly(d).difference(DateKeys.dayOnly(DateTime.now())).inDays;
    if (diff == 0) return '${s.t('today')} · ${formatDay(d)}';
    if (diff == 1) return '${s.t('tomorrow')} · ${formatDay(d)}';
    return formatDay(d);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('clinics'))),
      body: StreamView<List<ClinicSession>>(
        stream: _stream,
        loadingMessage: s.t('loading'),
        builder: (context, all) {
          final hospitals = all.map((x) => x.hospitalName).toSet().toList()..sort();
          final departments = all.map((x) => x.department).toSet().toList()..sort();
          final shown = all.where((x) {
            if (_hospital != null && x.hospitalName != _hospital) return false;
            if (_department != null && x.department != _department) return false;
            if (_onlyAvailable && x.isFull) return false;
            if (_query.isEmpty) return true;
            return x.department.toLowerCase().contains(_query) ||
                x.doctorName.toLowerCase().contains(_query) ||
                x.hospitalName.toLowerCase().contains(_query);
          }).toList();

          final rows = <Object>[];
          String? lastKey;
          for (final x in shown) {
            if (x.dateKey != lastKey) {
              rows.add(_dayLabel(s, x.date));
              lastKey = x.dateKey;
            }
            rows.add(x);
          }

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: s.t('searchClinics'),
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    FilterChip(
                      label: Text(s.t('availableOnly')),
                      selected: _onlyAvailable,
                      onSelected: (v) => setState(() => _onlyAvailable = v),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String?>(
                      tooltip: 'Hospital',
                      onSelected: (v) => setState(() => _hospital = v),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: null, child: Text(s.t('allHospitals'))),
                        for (final h in hospitals) PopupMenuItem(value: h, child: Text(h)),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.local_hospital_outlined, size: 18),
                        label: Text(_hospital ?? s.t('allHospitals')),
                        deleteIcon: const Icon(Icons.arrow_drop_down),
                        onDeleted: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String?>(
                      tooltip: 'Clinic',
                      onSelected: (v) => setState(() => _department = v),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: null, child: Text(s.t('allClinics'))),
                        for (final d in departments) PopupMenuItem(value: d, child: Text(d)),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.medical_services_outlined, size: 18),
                        label: Text(_department ?? s.t('allClinics')),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: shown.isEmpty
                  ? EmptyView(
                      icon: Icons.event_busy,
                      message: all.isEmpty ? s.t('noSessions') : s.t('noMatchClinics'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        if (row is String) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(row,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ClinicCard(session: row as ClinicSession, s: s),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _ClinicCard extends StatelessWidget {
  final ClinicSession session;
  final AppSettings s;
  const _ClinicCard({required this.session, required this.s});

  @override
  Widget build(BuildContext context) {
    final x = session;
    final t = Theme.of(context).textTheme;
    final isToday = x.dateKey == DateKeys.of(DateTime.now());
    final ratio = x.capacity == 0 ? 1.0 : x.bookedCount / x.capacity;
    final color = x.isFull ? AppColors.danger : (x.placesLeft <= 5 ? AppColors.accent : AppColors.success);
    final started = isToday && x.currentTokenLabel != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(x.department, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
            Pill(x.isFull ? s.t('full') : '${x.placesLeft} ${s.t('placesLeftShort')}', color: color),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.local_hospital_outlined, size: 16, color: AppColors.n600),
            const SizedBox(width: 4),
            Expanded(child: Text(x.hospitalName, style: t.bodySmall)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.schedule, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('${x.startTime} – ${x.endTime}', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            const Icon(Icons.person_outline, size: 18, color: AppColors.n600),
            const SizedBox(width: 4),
            Expanded(child: Text(x.doctorName, style: t.bodyMedium, overflow: TextOverflow.ellipsis)),
          ]),
          if (x.room.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.meeting_room_outlined, size: 18, color: AppColors.n600),
              const SizedBox(width: 6),
              Text(x.room, style: t.bodySmall),
            ]),
          ],
          const SizedBox(height: 10),
          MeterBar(value: ratio, color: color),
          const SizedBox(height: 4),
          Text(s.tf('bookedOf', {'a': '${x.bookedCount}', 'b': '${x.capacity}'}), style: t.bodySmall),
          if (isToday) ...[
            const SizedBox(height: 8),
            InfoBanner(
              icon: started ? Icons.campaign : Icons.hourglass_empty,
              color: started ? AppColors.success : AppColors.n600,
              message: started
                  ? s.tf('liveNow', {'token': x.currentTokenLabel ?? '', 'n': '${x.waitingIds.length}'})
                  : s.tf('notStartedWaiting', {'n': '${x.waitingIds.length}'}),
            ),
          ],
          const SizedBox(height: 12),
          PrimaryButton(
            x.isFull ? s.t('full') : s.t('bookAppointment'),
            icon: x.isFull ? null : Icons.event_available,
            onPressed: x.isFull ? null : () => showBookingReview(context, x),
          ),
        ]),
      ),
    );
  }
}
