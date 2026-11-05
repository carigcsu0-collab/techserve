import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/lesson.dart';
import '../providers/api_provider.dart';
import '../providers/lesson_provider.dart';
import '../services/error_messages.dart';

class AdminLessonFormScreen extends ConsumerStatefulWidget {
  final Lesson? lesson; // null = create
  final int nextOrderIndex;

  const AdminLessonFormScreen({
    super.key,
    this.lesson,
    this.nextOrderIndex = 1,
  });

  @override
  ConsumerState<AdminLessonFormScreen> createState() =>
      _AdminLessonFormScreenState();
}

class _AdminLessonFormScreenState extends ConsumerState<AdminLessonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _orderIndex;
  late final TextEditingController _mediaUrl;
  String _mediaType = 'video';
  String? _pickedFilePath;
  String? _pickedFileName;
  bool _saving = false;
  double? _uploadProgress;

  bool get _isEdit => widget.lesson != null;

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    _title = TextEditingController(text: lesson?.title ?? '');
    _description = TextEditingController(text: lesson?.description ?? '');
    _orderIndex = TextEditingController(
      text: '${lesson?.orderIndex ?? widget.nextOrderIndex}',
    );
    _mediaUrl = TextEditingController(text: lesson?.mediaUrl ?? '');
    _mediaType = lesson?.mediaType ?? 'video';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _orderIndex.dispose();
    _mediaUrl.dispose();
    super.dispose();
  }

  List<String> get _allowedExtensions => _mediaType == 'video'
      ? const [
          'mp4',
          'm4v',
          'mov',
          'webm',
          'mkv',
          'avi',
          'wmv',
          'flv',
          'f4v',
          'mpeg',
          'mpg',
          'mpe',
          'm2v',
          'ts',
          'm2ts',
          'mts',
          '3gp',
          '3g2',
          'ogv',
          'vob',
          'asf',
          'rm',
          'rmvb',
          'divx',
        ]
      : const ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (file?.path != null) {
      setState(() {
        _pickedFilePath = file!.path;
        _pickedFileName = file.name;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _uploadProgress = null;
    });
    void onProgress(int sent, int total) {
      if (mounted && total > 0) setState(() => _uploadProgress = sent / total);
    }

    try {
      final api = ref.read(apiServiceProvider);
      if (_isEdit) {
        await api.updateLesson(
          widget.lesson!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          mediaType: _mediaType,
          orderIndex: int.parse(_orderIndex.text.trim()),
          mediaUrl: _mediaUrl.text.trim().isEmpty
              ? null
              : _mediaUrl.text.trim(),
          mediaFilePath: _pickedFilePath,
          onUploadProgress: onProgress,
        );
      } else {
        await api.createLesson(
          title: _title.text.trim(),
          description: _description.text.trim(),
          mediaType: _mediaType,
          orderIndex: int.parse(_orderIndex.text.trim()),
          mediaUrl: _mediaUrl.text.trim().isEmpty
              ? null
              : _mediaUrl.text.trim(),
          mediaFilePath: _pickedFilePath,
          onUploadProgress: onProgress,
        );
      }
      ref.invalidate(lessonProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Lesson' : 'New Lesson')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _orderIndex,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Order',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (int.tryParse(v ?? '') ?? 0) < 1 ? 'Min 1' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _mediaType,
                    decoration: const InputDecoration(
                      labelText: 'Media type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                      DropdownMenuItem(value: 'image', child: Text('Image')),
                    ],
                    onChanged: (v) => setState(() {
                      _mediaType = v!;
                      _pickedFilePath = null;
                      _pickedFileName = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Media source', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(_pickedFileName ?? 'Upload $_mediaType file'),
              onPressed: _pickFile,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: Text('— or —')),
            ),
            TextFormField(
              controller: _mediaUrl,
              decoration: const InputDecoration(
                labelText: 'Media URL',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (_pickedFilePath == null &&
                    (v == null || v.trim().isEmpty) &&
                    (!_isEdit)) {
                  return 'Upload a file or provide a URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            if (_saving && _uploadProgress != null) ...[
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 6),
              Text(
                'Uploading ${(_uploadProgress! * 100).round()}%',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save Changes' : 'Create Lesson'),
            ),
          ],
        ),
      ),
    );
  }
}
