import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../core/app_settings.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../../core/widgets.dart';
import '../../services/db.dart';
import '../profile/change_password_screen.dart';
import '../profile/help_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/schedule_service.dart';
import '../../services/seed_service.dart';

/// S22 - Language, text size and contrast settings (NF2, NF3).
/// Changes preview live on this screen and are applied app-wide when saved.
/// Settings are stored on the user's profile so they follow them to any
/// device.
/// Owner: Nethmini K (IT23669130)
/// CRUD: READ saved settings; UPDATE settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _lang;
  late double _scale;
  late bool _contrast;
  bool _busy = false;
  bool _seeding = false;
  String? _syncedFrom;

  /// This tab is built at start-up (inside an IndexedStack), before the
  /// profile's saved settings arrive, so re-sync whenever the applied
  /// settings change.
  void _syncFrom(AppSettings s) {
    final key = '${s.lang}|${s.textScale}|${s.highContrast}';
    if (key == _syncedFrom) return;
    _syncedFrom = key;
    _lang = s.lang;
    _scale = s.textScale;
    _contrast = s.highContrast;
  }

  @override
  void initState() {
    super.initState();
    _syncFrom(context.read<AppSettings>());
  }

  bool get _dirty {
    final s = context.read<AppSettings>();
    return _lang != s.lang || _scale != s.textScale || _contrast != s.highContrast;
  }

  /// Applies the chosen language to the whole app at once and saves it to the
  /// profile, so every screen changes, not only this one.
  Future<void> _changeLanguage(String? v) async {
    if (v == null || v == _lang) return;
    final settings = context.read<AppSettings>();
    final uid = me(context).uid;
    setState(() => _lang = v);
    settings.apply(lang: v);
    try {
      await ScheduleService.saveSettings(uid,
          language: v, textScale: settings.textScale, highContrast: settings.highContrast);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _save() async {
    final settings = context.read<AppSettings>();
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      () => ScheduleService.saveSettings(me(context).uid, language: _lang, textScale: _scale, highContrast: _contrast),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      settings.apply(lang: _lang, textScale: _scale, highContrast: _contrast);
      showSnack(context, S.of(_lang, 'saved'));
    }
  }

  Future<void> _seed() async {
    final ok = await confirm(context,
        title: 'Load demo data?',
        message: 'Adds 4 hospitals, two weeks of clinic sessions and 5 sample patient records.',
        confirmLabel: 'Load');
    if (!ok || !mounted) return;
    setState(() => _seeding = true);
    try {
      final empty = await SeedService.isEmpty();
      if (!empty && mounted) {
        final again = await confirm(context,
            title: 'Data already exists',
            message: 'Hospitals are already loaded. Loading again adds another set of sessions and sample patients.',
            confirmLabel: 'Load anyway');
        if (!again) return;
      }
      if (!mounted) return;
      final n = await SeedService.seed(me(context).uid);
      if (mounted) showSnack(context, 'Demo data loaded ($n records)');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncFrom(context.watch<AppSettings>());
    final profile = context.watch<CurrentUser>().profile;
    String t(String k) => S.of(_lang, k);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (profile != null) ...[
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSizes.radius),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    InitialsAvatar(profile.name, radius: 28, background: AppColors.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(profile.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(profile.email, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Pill(profile.isAdmin ? 'Admin' : (profile.isStaff ? 'OPD staff' : t('patientRole'))),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(children: [
                MenuTile(
                  icon: Icons.edit_outlined,
                  title: t('editProfile'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.lock_outline,
                  title: t('changePassword'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                ),
                const Divider(height: 1),
                MenuTile(
                  icon: Icons.help_outline,
                  title: t('help'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
                ),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          SectionTitle(t('language')),
          // The language changes the whole app the moment it is chosen (and is
          // saved to the profile), instead of only previewing on this page.
          RadioGroup<String>(
            groupValue: _lang,
            onChanged: _changeLanguage,
            child: Column(children: [
              for (final code in S.supported)
                RadioListTile<String>(
                  value: code,
                  contentPadding: EdgeInsets.zero,
                  title: Text(S.languageNames[code]!, style: const TextStyle(fontSize: 18)),
                ),
            ]),
          ),
          const Divider(),
          SectionTitle(t('textSize')),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 1.0, label: Text('A', style: TextStyle(fontSize: 14))),
              ButtonSegment(value: 1.15, label: Text('A', style: TextStyle(fontSize: 18))),
              ButtonSegment(value: 1.3, label: Text('A', style: TextStyle(fontSize: 22))),
            ],
            selected: {_scale},
            onSelectionChanged: (v) => setState(() => _scale = v.first),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _contrast,
            onChanged: (v) => setState(() => _contrast = v),
            title: Text(t('highContrast')),
            secondary: const Icon(Icons.contrast),
          ),
          const SizedBox(height: 8),
          // Live preview of the unsaved choices (M02 S22 design).
          MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_scale)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _contrast ? Colors.white : AppColors.n50,
                border: Border.all(color: _contrast ? Colors.black : AppColors.n200, width: _contrast ? 2 : 1),
                borderRadius: BorderRadius.circular(AppSizes.radius),
              ),
              child: Text(t('preview'),
                  style: TextStyle(
                      fontSize: 16,
                      color: _contrast ? Colors.black : AppColors.n900,
                      fontWeight: _contrast ? FontWeight.bold : FontWeight.normal)),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(t('saveSettings'), onPressed: _dirty ? _save : null, loading: _busy),
          const SizedBox(height: 24),
          const Divider(),
          if (profile != null) ...[
            if (user != null && !user.emailVerified)
              Card(
                color: AppColors.accent.withValues(alpha: 0.12),
                child: ListTile(
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: const Text('Email not verified'),
                  subtitle: const Text('Check your inbox for the verification link.'),
                  trailing: TextButton(
                    onPressed: () =>
                        runGuarded(context, () => user.sendEmailVerification(), success: 'Verification email sent'),
                    child: const Text('Resend'),
                  ),
                ),
              ),
            if (profile.isStaff) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _seeding
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.dataset_outlined),
                title: const Text('Load demo data'),
                subtitle: const Text('Hospitals, clinic sessions and sample patients for testing'),
                onTap: _seeding ? null : _seed,
              ),
            ],
          ],
          const SizedBox(height: 8),
          SecondaryButton(t('signOut'), icon: Icons.logout, onPressed: () => signOutAndReset(context)),
        ],
      ),
    );
  }
}
