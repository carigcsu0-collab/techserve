import 'package:flutter/material.dart';

import 'admin_dashboard_tab.dart';
import 'admin_lessons_tab.dart';
import 'admin_qualifications_tab.dart';
import 'admin_users_tab.dart';

/// Admin home: Dashboard, Lessons, Qualifications and Users, switched with a
/// bottom navigation bar. Each tab keeps its state while another is shown.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          AdminDashboardTab(),
          AdminLessonsTab(),
          AdminQualificationsTab(),
          AdminUsersTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Lessons',
          ),
          NavigationDestination(
            icon: Icon(Icons.workspace_premium_outlined),
            selectedIcon: Icon(Icons.workspace_premium),
            label: 'Qualifications',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
        ],
      ),
    );
  }
}
