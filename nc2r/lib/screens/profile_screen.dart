import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../services/error_messages.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: () => _changeAvatar(context, ref, user.avatarUrl != null),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: theme.colorScheme.primary,
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    onBackgroundImageError: user.avatarUrl != null
                        ? (error, stackTrace) {}
                        : null,
                    child: user.avatarUrl != null
                        ? null
                        : Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: theme.colorScheme.surface,
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Center(
            child: Text(
              user.email,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          if (user.bio != null) ...[
            const SizedBox(height: 12),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (user.location != null || user.phone != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (user.location != null) user.location!,
                if (user.phone != null) user.phone!,
              ].join('  •  '),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Edit profile'),
                  subtitle: const Text('Name, bio, phone and location'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editProfile(context, ref, user),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changePassword(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text(
                'Sign out',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () => _confirmSignOut(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final form = await showDialog<_ProfileForm>(
      context: context,
      builder: (_) => _EditProfileDialog(user: user),
    );
    if (form == null || !context.mounted) return;

    try {
      await ref
          .read(authProvider.notifier)
          .updateProfileDetails(
            name: form.name,
            bio: form.bio,
            phone: form.phone,
            location: form.location,
          );
      if (context.mounted) _show(context, 'Profile updated.');
    } catch (e) {
      if (context.mounted) _show(context, friendlyError(e));
    }
  }

  Future<void> _changeAvatar(
    BuildContext context,
    WidgetRef ref,
    bool hasAvatar,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose photo'),
              onTap: () => Navigator.pop(sheetContext, 'choose'),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    try {
      final notifier = ref.read(authProvider.notifier);
      if (choice == 'remove') {
        await notifier.removeAvatar();
        if (context.mounted) _show(context, 'Profile photo removed.');
        return;
      }

      final result = await FilePicker.pickFile(type: FileType.image);
      final path = result?.path;
      if (path == null || !context.mounted) return;

      await notifier.uploadAvatar(path);
      if (context.mounted) _show(context, 'Profile photo updated.');
    } catch (e) {
      if (context.mounted) _show(context, friendlyError(e));
    }
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final form = await showDialog<_PasswordForm>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (form == null || !context.mounted) return;

    try {
      await ref
          .read(apiServiceProvider)
          .changePassword(
            currentPassword: form.current,
            password: form.password,
            passwordConfirmation: form.confirmation,
          );
      if (context.mounted) {
        _show(context, 'Password updated. Other devices were signed out.');
      }
    } catch (e) {
      if (context.mounted) _show(context, friendlyError(e));
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to continue learning.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Leave the profile screen so the auth gate's login screen is visible.
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    await ref.read(authProvider.notifier).logout();
  }

  void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileForm {
  final String name;
  final String bio;
  final String phone;
  final String location;

  const _ProfileForm({
    required this.name,
    required this.bio,
    required this.phone,
    required this.location,
  });
}

class _EditProfileDialog extends StatefulWidget {
  final AppUser user;

  const _EditProfileDialog({required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _bio = TextEditingController(text: widget.user.bio ?? '');
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  late final _location = TextEditingController(
    text: widget.user.location ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    Navigator.pop(
      context,
      _ProfileForm(
        name: name,
        bio: _bio.text.trim(),
        phone: _phone.text.trim(),
        location: _location.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bio,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phone,
              maxLength: 32,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _location,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _PasswordForm {
  final String current;
  final String password;
  final String confirmation;

  const _PasswordForm(this.current, this.password, this.confirmation);
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _save() {
    if (_current.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (_password.text.length < 8) {
      setState(
        () => _error = 'The new password must be at least 8 characters.',
      );
      return;
    }
    if (_password.text != _confirmation.text) {
      setState(() => _error = 'The new passwords do not match.');
      return;
    }
    Navigator.pop(
      context,
      _PasswordForm(_current.text, _password.text, _confirmation.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmation,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Update')),
      ],
    );
  }
}
