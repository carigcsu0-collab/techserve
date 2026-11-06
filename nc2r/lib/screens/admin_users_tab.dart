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

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }

  Future<void> _openEditor({ManagedUser? existing}) async {
    final result = await showDialog<_UserInput>(
      context: context,
      builder: (_) => _UserDialog(existing: existing),
    );
    if (result == null || !mounted) return;

    try {
      final api = ref.read(apiServiceProvider);
      if (existing == null) {
        await api.createUser(
          name: result.name,
          email: result.email,
          password: result.password ?? '',
          role: result.role,
        );
      } else {
        await api.updateUser(
          existing.id,
          name: result.name,
          email: result.email,
          role: result.role,
          password: result.password,
        );
      }
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(ManagedUser u) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('"${u.name}" (${u.email}) will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(apiServiceProvider).deleteUser(u.id);
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add user'),
      ),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(u.isAdmin ? 'Admin' : 'Learner'),
                  visualDensity: VisualDensity.compact,
                ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (value) {
                    if (value == 'edit') _openEditor(existing: u);
                    if (value == 'delete') _delete(u);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
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

class _UserInput {
  final String name;
  final String email;
  final String role;
  final String? password;

  const _UserInput({
    required this.name,
    required this.email,
    required this.role,
    this.password,
  });
}

class _UserDialog extends StatefulWidget {
  final ManagedUser? existing;

  const _UserDialog({this.existing});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _password = TextEditingController();
  late String _role;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _email = TextEditingController(text: widget.existing?.email ?? '');
    _role = widget.existing?.role ?? 'user';
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'New user' : 'Edit user'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Learner')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'user'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _isNew ? 'Password' : 'New password (optional)',
                  helperText: _isNew ? 'At least 8 characters' : null,
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (_isNew && value.length < 8) {
                    return 'At least 8 characters';
                  }
                  if (!_isNew && value.isNotEmpty && value.length < 8) {
                    return 'At least 8 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(
              _UserInput(
                name: _name.text.trim(),
                email: _email.text.trim(),
                role: _role,
                password: _password.text.isEmpty ? null : _password.text,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
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
