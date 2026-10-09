import 'package:flutter/material.dart';

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
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        StaffOverviewScreen(onSwitchTab: (i) => setState(() => _tab = i)),
        const QueueDashboardScreen(),
        const PatientListScreen(),
        const ScheduleScreen(),
        const SettingsScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(
              icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'Queue'),
          NavigationDestination(
              icon: Icon(Icons.folder_shared_outlined), selectedIcon: Icon(Icons.folder_shared), label: 'Patients'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Schedule'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
