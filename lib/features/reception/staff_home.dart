import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../records/patient_list_screen.dart';
import '../schedule/schedule_screen.dart';
import '../schedule/settings_screen.dart';
import 'queue_dashboard_screen.dart';
import 'staff_overview_screen.dart';

/// Staff entry point. Uses the darker primary top bar (design system:
/// "Primary / Dark - staff-side top bars") so staff and patient screens are
/// never confused.
class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<CurrentUser>().profile?.isAdmin ?? false;
    final screens = [
      StaffOverviewScreen(onSwitchTab: (i) => setState(() => _tab = i)),
      const QueueDashboardScreen(),
      if (admin) const PatientListScreen(),
      const ScheduleScreen(),
      const SettingsScreen(),
    ];
    final destinations = [
      const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Overview'),
      const NavigationDestination(
          icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'Queue'),
      if (admin)
        const NavigationDestination(
            icon: Icon(Icons.folder_shared_outlined), selectedIcon: Icon(Icons.folder_shared), label: 'Patients'),
      const NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Schedule'),
      const NavigationDestination(
          icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ];

    if (!admin && _tab >= screens.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _tab = 0));
    }

    return Scaffold(
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.clamp(0, destinations.length - 1),
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: destinations,
      ),
    );
  }
}
