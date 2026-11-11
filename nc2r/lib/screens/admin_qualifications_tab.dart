import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/qualification.dart';
import '../providers/api_provider.dart';
import '../providers/lesson_provider.dart';
import '../services/error_messages.dart';
import 'admin_exams_screen.dart';

/// Qualifications tab of the admin shell: create, edit, reorder, delete.
class AdminQualificationsTab extends ConsumerStatefulWidget {
  const AdminQualificationsTab({super.key});

  @override
  ConsumerState<AdminQualificationsTab> createState() =>
      _AdminQualificationsTabState();
}

class _AdminQualificationsTabState
    extends ConsumerState<AdminQualificationsTab> {
  /// Ids in the order just dragged, until the save completes.
  List<int>? _pendingOrder;

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }

  void _refresh() {
    ref.invalidate(adminQualificationsProvider);
    ref.invalidate(qualificationsProvider);
  }

  Future<void> _reorder(List<Qualification> list, int oldIndex, int newIndex) async {
    final ids = list.map((q) => q.id).toList();
    if (newIndex > oldIndex) newIndex -= 1;
    ids.insert(newIndex, ids.removeAt(oldIndex));

    setState(() => _pendingOrder = ids);
    try {
      await ref.read(apiServiceProvider).reorderQualifications(ids);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _pendingOrder = null);
      _refresh();
    }
  }

  Future<void> _delete(Qualification q) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete qualification?'),
        content: Text(
          q.lessonCount > 0
              ? '"${q.title}" has ${q.lessonCount} lesson(s). Move or delete '
                  'them first. The server will refuse this delete.'
              : '"${q.title}" will be permanently removed.',
        ),
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
      await ref.read(apiServiceProvider).deleteQualification(q.id);
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit({Qualification? existing}) async {
    final result = await showDialog<_QualificationInput>(
      context: context,
      builder: (_) => _QualificationDialog(existing: existing),
    );
    if (result == null || !mounted) return;

    try {
      final api = ref.read(apiServiceProvider);
      if (existing == null) {
        await api.createQualification(
          title: result.title,
          description: result.description,
        );
      } else {
        await api.updateQualification(
          existing.id,
          title: result.title,
          description: result.description,
        );
      }
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminQualificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Qualifications')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New qualification'),
        onPressed: () => _edit(),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(friendlyError(error), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No qualifications yet. Tap New qualification.'),
            );
          }
          final visible = _pendingOrder == null
              ? list
              : [
                  for (final id in _pendingOrder!)
                    ...list.where((q) => q.id == id),
                ];
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 96, top: 8),
            buildDefaultDragHandles: false,
            itemCount: visible.length,
            onReorder: (o, n) => _reorder(visible, o, n),
            itemBuilder: (context, index) {
              final q = visible[index];
              return Card(
                key: ValueKey(q.id),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(q.title),
                  subtitle: Text('${q.lessonCount} lesson(s)'),
                  onTap: () => _edit(existing: q),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fact_check_outlined),
                        tooltip: 'Pre-test & post-test',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminExamsScreen(
                                qualificationId: q.id, title: q.title),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        onPressed: () => _delete(q),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.drag_handle),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QualificationInput {
  final String title;
  final String description;

  const _QualificationInput({
    required this.title,
    required this.description,
  });
}

class _QualificationDialog extends StatefulWidget {
  final Qualification? existing;

  const _QualificationDialog({this.existing});

  @override
  State<_QualificationDialog> createState() => _QualificationDialogState();
}

class _QualificationDialogState extends State<_QualificationDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description =
        TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'New qualification'
          : 'Edit qualification'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
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
              _QualificationInput(
                title: _title.text.trim(),
                description: _description.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
