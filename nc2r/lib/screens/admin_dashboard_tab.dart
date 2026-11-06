import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../services/error_messages.dart';

/// Dashboard tab of the admin shell: headline numbers and recent activity.
class AdminDashboardTab extends ConsumerStatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  ConsumerState<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends ConsumerState<AdminDashboardTab> {
  DashboardStats? _stats;
  List<AuditEntry> _recent = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiServiceProvider).fetchDashboard();
      if (!mounted) return;
      setState(() {
        _stats = data.stats;
        _recent = data.recent;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity log',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminActivityScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: _loading && _stats == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _stats == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Overview',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      _statGrid(_stats!),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Recent activity',
                                style: theme.textTheme.titleMedium),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminActivityScreen(),
                              ),
                            ),
                            child: const Text('See all'),
                          ),
                        ],
                      ),
                      if (_recent.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No admin activity yet.'),
                        ),
                      for (final entry in _recent) _ActivityTile(entry: entry),
                    ],
                  ),
                ),
    );
  }

  Widget _statGrid(DashboardStats s) {
    final items = <(IconData, String, String)>[
      (Icons.people_alt_outlined, 'Users', '${s.users}'),
      (Icons.admin_panel_settings_outlined, 'Admins', '${s.admins}'),
      (Icons.menu_book_outlined, 'Lessons', '${s.lessons}'),
      (Icons.quiz_outlined, 'Quiz attempts', '${s.quizSubmissions}'),
      (Icons.verified_outlined, 'Pass rate', '${s.passRate}%'),
      (Icons.insights_outlined, 'Avg score',
          '${s.averageScore.toStringAsFixed(0)}%'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        for (final (icon, label, value) in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 22),
                  Text(value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Full activity log of admin actions.
class AdminActivityScreen extends ConsumerStatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  ConsumerState<AdminActivityScreen> createState() =>
      _AdminActivityScreenState();
}

class _AdminActivityScreenState extends ConsumerState<AdminActivityScreen> {
  List<AuditEntry>? _logs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final logs = await ref.read(apiServiceProvider).fetchAuditLogs();
      if (mounted) setState(() => _logs = logs);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _logs;
    return Scaffold(
      appBar: AppBar(title: const Text('Activity log')),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : logs == null
              ? const Center(child: CircularProgressIndicator())
              : logs.isEmpty
                  ? const Center(child: Text('No activity recorded yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: logs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _ActivityTile(entry: logs[i]),
                      ),
                    ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final AuditEntry entry;

  const _ActivityTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final when = entry.createdAt?.toLocal();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.history, size: 18)),
      title: Text(entry.description.isEmpty ? entry.action : entry.description),
      subtitle: Text(
        [
          if (entry.adminName != null) entry.adminName!,
          if (when != null)
            '${when.year}-${when.month.toString().padLeft(2, '0')}-'
                '${when.day.toString().padLeft(2, '0')} '
                '${when.hour.toString().padLeft(2, '0')}:'
                '${when.minute.toString().padLeft(2, '0')}',
        ].join(' · '),
      ),
    );
  }
}
