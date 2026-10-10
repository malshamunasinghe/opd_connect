import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../records/my_health_screen.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';

/// Profile: who you are, your health details and account actions.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CurrentUser>().profile;
    if (p == null) return const Scaffold(body: LoadingView());
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(context.watch<AppSettings>().t('profile'))),
      body: p.patientId == null
          ? _Body(profile: p, record: null, verified: user?.emailVerified ?? false)
          : StreamView<Patient?>(
              stream: ProfileService.myRecord(p.patientId!),
              builder: (context, record) =>
                  _Body(profile: p, record: record, verified: user?.emailVerified ?? false),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  final UserProfile profile;
  final Patient? record;
  final bool verified;
  const _Body({required this.profile, required this.record, required this.verified});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = record;
    final s = context.watch<AppSettings>();
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(children: [
            InitialsAvatar(profile.name, radius: 40),
            const SizedBox(height: 12),
            Text(profile.name,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(profile.email, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              Pill(profile.isAdmin ? 'Admin' : (profile.isStaff ? 'OPD staff' : s.t('patientRole')),
                  color: Colors.white, icon: Icons.badge_outlined),
              Pill(verified ? 'E-mail verified' : 'E-mail not verified',
                  color: verified ? Colors.white : AppColors.accent,
                  icon: verified ? Icons.verified : Icons.warning_amber),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SecondaryButton(s.t('editProfile'), icon: Icons.edit_outlined, onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(record: r)));
            }),
            if (r != null && !profile.isStaff) ...[
              const SizedBox(height: 12),
              Card(
                child: MenuTile(
                  icon: Icons.history,
                  title: s.t('visitHistory'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyHealthScreen())),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SectionTitle(s.t('contact')),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  InfoRow(s.t('mobile'), profile.phone, icon: Icons.phone_outlined),
                  InfoRow(s.t('email'), profile.email, icon: Icons.email_outlined),
                  if (r != null) InfoRow(s.t('address'), r.address, icon: Icons.home_outlined),
                ]),
              ),
            ),
            if (r != null) ...[
              SectionTitle(s.t('healthDetails')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    InfoRow('NIC', r.nic, icon: Icons.badge_outlined),
                    InfoRow(s.t('dob'), r.dob == null ? '' : '${formatDay(r.dob!)} (${r.age} yrs)', icon: Icons.cake_outlined),
                    InfoRow(s.t('genderLabel'), r.gender, icon: Icons.wc),
                    InfoRow(s.t('bloodGroup'), r.bloodGroup, icon: Icons.bloodtype_outlined),
                    InfoRow(s.t('allergies'), r.allergies.isEmpty ? s.t('noneRecorded') : r.allergies, icon: Icons.warning_amber_outlined),
                    InfoRow(s.t('emergencyContact'), r.emergencyContact, icon: Icons.contact_phone_outlined),
                  ]),
                ),
              ),
            ],
            SectionTitle(s.t('accountSection')),
            Card(
              child: Column(children: [
                MenuTile(
                  icon: Icons.lock_outline,
                  title: s.t('changePassword'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                ),
                const Divider(height: 1),
                if (!verified) ...[
                  MenuTile(
                    icon: Icons.mark_email_unread_outlined,
                    title: s.t('verifyEmailBtn'),
                    subtitle: 'Send the verification link again',
                    color: AppColors.accent,
                    onTap: () => runGuarded(context, ProfileService.resendVerification, success: 'Verification e-mail sent'),
                  ),
                  const Divider(height: 1),
                ],
                MenuTile(
                  icon: Icons.help_outline,
                  title: s.t('help'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.logout,
                  title: s.t('signOut'),
                  color: AppColors.danger,
                  onTap: () async {
                    final ok = await confirm(context,
                        title: s.t('signOutQ'), message: s.t('signOutMsg'), confirmLabel: s.t('signOut'), danger: true);
                    if (ok && context.mounted) await signOutAndReset(context);
                  },
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Your health information is private. Only you and the hospital staff treating you can see it.',
                style: t.bodySmall),
          ]),
        ),
      ],
    );
  }
}
