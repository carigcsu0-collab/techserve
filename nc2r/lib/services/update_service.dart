import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdate {
  const AppUpdate({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.fileName,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String fileName;
}

/// Checks the latest GitHub release on launch and installs it on Android
/// (APK) or Windows (Inno Setup installer). Web is updated by the server.
class UpdateService {
  static const _latestReleaseUrl =
      'https://api.github.com/repos/carigcsu0-collab/techserve/releases/latest';

  static Future<AppUpdate?> findUpdate() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isWindows)) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Accept': 'application/vnd.github+json'},
      ));
      final response = await dio.get<Map<String, dynamic>>(_latestReleaseUrl);
      final data = response.data;
      if (data == null) return null;

      final tag = data['tag_name'] as String? ?? '';
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (_compareVersions(latest, info.version) <= 0) return null;

      final assets = (data['assets'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      for (final asset in assets) {
        final name = asset['name'] as String;
        final matches = Platform.isAndroid
            ? name.endsWith('.apk')
            : name.endsWith('.exe') && name.contains('setup');
        if (matches) {
          return AppUpdate(
            currentVersion: info.version,
            latestVersion: latest,
            downloadUrl: asset['browser_download_url'] as String,
            fileName: name,
          );
        }
      }
    } catch (_) {
      // Offline or GitHub unreachable: skip silently and let the app open.
    }
    return null;
  }

  /// Shows an update prompt when a newer release exists.
  static Future<void> checkAndPrompt(BuildContext context) async {
    final update = await findUpdate();
    if (update == null || !context.mounted) return;

    final wantsUpdate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'Version ${update.latestVersion} is available. '
          'You have ${update.currentVersion}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update now'),
          ),
        ],
      ),
    );
    if (wantsUpdate != true || !context.mounted) return;

    await _downloadAndInstall(context, update);
  }

  static Future<void> _downloadAndInstall(
      BuildContext context, AppUpdate update) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double>(0);
    var dialogOpen = true;

    void closeDialog() {
      if (dialogOpen) {
        dialogOpen = false;
        navigator.pop();
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('Downloading ${update.latestVersion}'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (ctx, value, _) =>
              LinearProgressIndicator(value: value > 0 ? value : null),
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}${Platform.pathSeparator}${update.fileName}';
      await Dio().download(
        update.downloadUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );
      closeDialog();

      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
      // The installer replaces the running exe, so the app must close first.
      if (Platform.isWindows) exit(0);
    } catch (e) {
      closeDialog();
      messenger.showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      progress.dispose();
    }
  }

  /// Compares dotted versions numerically, ignoring any `+build` suffix.
  static int _compareVersions(String a, String b) {
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();

    final x = parts(a);
    final y = parts(b);
    for (var i = 0; i < 3; i++) {
      final xi = i < x.length ? x[i] : 0;
      final yi = i < y.length ? y[i] : 0;
      if (xi != yi) return xi.compareTo(yi);
    }
    return 0;
  }
}
