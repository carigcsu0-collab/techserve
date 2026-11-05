import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_models.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../services/error_messages.dart';

/// Users tab of the admin shell: search, then open a user to review progress
/// and quiz attempts or change their role.
class AdminUsersTab extends ConsumerStatefulWidget {
  const AdminUsersTab({super.key});

  @override
  ConsumerState<AdminUsersTab> createState() => _AdminUsersTabState();
}

class _AdminUsersTabState extends ConsumerState<AdminUsersTab> {
  final _search = TextEditingController();
  List<ManagedUser> _users = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users =
          await ref.read(apiServiceProvider).fetchUsers(query: _query);
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _submitSearch(String value) {
    _query = value.trim();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              controller: _search,
              hintText: 'Search name or email',
              leading: const Icon(Icons.search),
              trailing: [
                if (_search.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      _submitSearch('');
                    },
                  ),
              ],
              onSubmitted: _submitSearch,
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final u = _users[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase()),
            ),
            title: Text(u.name),
            subtitle: Text(u.email),
            trailing: Chip(
              label: Text(u.isAdmin ? 'Admin' : 'Learner'),
              visualDensity: VisualDensity.compact,
            ),
            onTap: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => AdminUserDetailScreen(userId: u.id),
                ),
              );
              if (changed == true) _load();
            },
          );
        },
      ),
    );
  }
}

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final int userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  UserDetail? _detail;
  String? _error;
  bool _saving = false;
  bool _roleChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail =
          await ref.read(apiServiceProvider).fetchUserDetail(widget.userId);
      if (mounted) setState(() => _detail = detail);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _setRole(bool makeAdmin) async {
    final detail = _detail;
    if (detail == null) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(apiServiceProvider).updateUserRole(
            detail.user.id,
            makeAdmin ? 'admin' : 'user',
          );
      if (!mounted) return;
      setState(() {
        _roleChanged = true;
        _detail = UserDetail(
          user: updated,
          totalLessons: detail.totalLessons,
          completedCount: detail.completedCount,
          completedTitles: detail.completedTitles,
          attempts: detail.attempts,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = ref.watch(authProvider).value;
    final detail = _detail;

    return Scaffold(
        appBar: AppBar(
          title: const Text('User'),
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_roleChanged),
          ),
        ),
        body: _error != null
            ? Center(child: Text(_error!))
            : detail == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(detail.user.name,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(detail.user.email),
                      const SizedBox(height: 16),
                      Card(
                        child: SwitchListTile(
                          title: const Text('Administrator'),
                          subtitle: Text(
                            me?.id == detail.user.id
                                ? "You can't change your own role."
                                : 'Admins can manage lessons and users.',
                          ),
                          value: detail.user.isAdmin,
                          onChanged: _saving || me?.id == detail.user.id
                              ? null
                              : _setRole,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Progress', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: detail.totalLessons == 0
                            ? 0
                            : detail.completedCount / detail.totalLessons,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${detail.completedCount} of ${detail.totalLessons} '
                        'lessons completed',
                      ),
                      if (detail.completedTitles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final t in detail.completedTitles)
                          Text('✓ $t'),
                      ],
                      const SizedBox(height: 24),
                      Text('Quiz attempts',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (detail.attempts.isEmpty)
                        const Text('No quiz attempts yet.'),
                      for (final a in detail.attempts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            a.passed ? Icons.check_circle : Icons.cancel,
                            color: a.passed ? Colors.green : Colors.red,
                          ),
                          title: Text(a.lessonTitle),
                          subtitle: Text(
                            'Score ${a.score}%'
                            '${a.createdAt == null ? '' : ' · ${_date(a.createdAt!)}'}',
                          ),
                        ),
                    ],
                  ),
      );
  }
}

String _date(DateTime d) {
  final local = d.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
