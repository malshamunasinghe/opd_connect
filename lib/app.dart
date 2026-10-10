import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_settings.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/patient/patient_home.dart';
import 'features/reception/staff_home.dart';
import 'models/user_profile.dart';
import 'services/auth_service.dart';
import 'widgets/hospital_background.dart';

/// The signed-in user, provided above MaterialApp so every pushed route can
/// read it with `context.read<CurrentUser>()`.
class CurrentUser {
  final User? user;
  final UserProfile? profile;
  const CurrentUser(this.user, this.profile);

  bool get signedIn => user != null;
}

/// Shortcut used by screens that are only reachable after sign-in.
UserProfile me(BuildContext context) => context.read<CurrentUser>().profile!;

/// Closes any open screens, then signs out, so the next user starts clean.
Future<void> signOutAndReset(BuildContext context) async {
  Navigator.of(context).popUntil((r) => r.isFirst);
  context.read<AppSettings>().reset();
  await AuthService.signOut();
}

class OpdApp extends StatelessWidget {
  const OpdApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The widget tree shape stays the same whether or not someone is signed
    // in, so one MaterialApp (and its Navigator) lives for the whole session.
    // That lets the registration screen stay open and show an error if
    // account creation fails part-way.
    return StreamBuilder<User?>(
      stream: AuthService.authChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        return StreamBuilder<UserProfile?>(
          stream: user == null ? Stream<UserProfile?>.value(null) : AuthService.profileStream(user.uid),
          builder: (context, profSnap) => _AppShell(
            current: CurrentUser(user, user == null ? null : profSnap.data),
            waiting: authSnap.connectionState == ConnectionState.waiting,
          ),
        );
      },
    );
  }
}

class _AppShell extends StatefulWidget {
  final CurrentUser current;
  final bool waiting;
  const _AppShell({required this.current, required this.waiting});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  String? _appliedFor;

  /// Applies the accessibility settings saved on the profile (S22) once per
  /// change, so they follow the user across devices.
  void _syncSettings() {
    final p = widget.current.profile;
    if (p == null) {
      _appliedFor = null; // re-apply when the same user signs in again
      return;
    }
    final key = '${p.uid}|${p.language}|${p.textScale}|${p.highContrast}';
    if (key == _appliedFor) return;
    _appliedFor = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppSettings>().apply(
            lang: p.language,
            textScale: p.textScale,
            highContrast: p.highContrast,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    _syncSettings();
    final settings = context.watch<AppSettings>();
    final profile = widget.current.profile;
    final staff = profile?.isStaff ?? false;

    return Provider<CurrentUser>.value(
      value: widget.current,
      child: MaterialApp(
        title: 'OPD Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(highContrast: settings.highContrast, staff: staff),
        // The in-app text size (S22) multiplies the phone's own accessibility
        // font size instead of replacing it.
        builder: (context, child) {
          final system = MediaQuery.textScalerOf(context).scale(14) / 14;
          final scale = (system * settings.textScale).clamp(1.0, 2.2);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: HospitalBackground(child: child!),
          );
        },
        home: _RootGate(waiting: widget.waiting),
      ),
    );
  }
}

/// S17 role-based routing: patients and staff never share an entry point.
class _RootGate extends StatelessWidget {
  final bool waiting;
  const _RootGate({required this.waiting});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<CurrentUser>();
    if (waiting) return const _Splash();
    if (!current.signedIn) return const LoginScreen();
    final profile = current.profile;
    if (profile == null) return const _Splash(showSignOut: true);
    return profile.isStaff
        ? StaffHome(key: ValueKey('staff-${profile.uid}'))
        : PatientHome(key: ValueKey('patient-${profile.uid}'));
  }
}

class _Splash extends StatelessWidget {
  final bool showSignOut;
  const _Splash({this.showSignOut = false});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_hospital, size: 72, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('OPD Connect', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            if (showSignOut) ...[
              const SizedBox(height: 16),
              const Text('Setting up your account…'),
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 8, 32, 0),
                child: Text(
                  'If this takes more than a few seconds, your profile may have been removed by the hospital. '
                  'Please contact the ICT unit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
              ),
              TextButton(onPressed: AuthService.signOut, child: const Text('Sign out')),
            ],
          ]),
        ),
      );
}
