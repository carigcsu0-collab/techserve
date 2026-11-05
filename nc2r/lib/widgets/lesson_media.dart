import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../models/lesson.dart';

/// Renders the lesson media: chewie video player or cached network image.
class LessonMedia extends StatefulWidget {
  final Lesson lesson;

  const LessonMedia({super.key, required this.lesson});

  @override
  State<LessonMedia> createState() => _LessonMediaState();
}

class _LessonMediaState extends State<LessonMedia> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.lesson.isVideo && widget.lesson.mediaUrl != null) {
      _initVideo(widget.lesson.mediaUrl!);
    }
  }

  @override
  void didUpdateWidget(LessonMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Same widget instance can be reused (e.g. after a refresh swaps in a
    // newly-unlocked lesson) — reinitialize media instead of leaking the
    // old controller and silently showing stale content.
    if (oldWidget.lesson.mediaUrl == widget.lesson.mediaUrl &&
        oldWidget.lesson.mediaType == widget.lesson.mediaType) {
      return;
    }
    _disposeVideo();
    setState(() => _error = null);
    if (widget.lesson.isVideo && widget.lesson.mediaUrl != null) {
      _initVideo(widget.lesson.mediaUrl!);
    }
  }

  Future<void> _initVideo(String url) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      // The url this controller was created for may no longer match the
      // widget's current lesson (rapid updates, or disposed mid-flight).
      if (!mounted || widget.lesson.mediaUrl != url) {
        controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: false,
          looping: false,
        );
      });
    } catch (e) {
      controller.dispose();
      if (mounted) setState(() => _error = e);
    }
  }

  void _retryVideo() {
    final url = widget.lesson.mediaUrl;
    if (url == null) return;
    _disposeVideo();
    setState(() => _error = null);
    _initVideo(url);
  }

  void _disposeVideo() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.lesson.mediaUrl;

    if (url == null) {
      return const _MediaPlaceholder(icon: Icons.lock, label: 'Locked');
    }

    if (!widget.lesson.isVideo) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        height: 220,
        width: double.infinity,
        placeholder: (_, _) => const _ShimmerMediaPlaceholder(),
        errorWidget: (_, _, _) => const _MediaPlaceholder(
          icon: Icons.broken_image,
          label: 'Failed to load image',
        ),
      );
    }

    final chewie = _chewieController;
    if (_error != null) {
      return _MediaPlaceholder(
        icon: Icons.error_outline,
        label: 'Video could not be loaded',
        actionLabel: 'Retry',
        onAction: _retryVideo,
      );
    }
    if (chewie == null) {
      return const _ShimmerMediaPlaceholder();
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Chewie(controller: chewie),
    );
  }
}

/// Shimmer skeleton shown while an image or video is loading — replaces
/// the plain spinner with a placeholder that reads as "media incoming".
class _ShimmerMediaPlaceholder extends StatelessWidget {
  const _ShimmerMediaPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colors.surfaceContainerHighest,
      highlightColor: colors.surface,
      child: Container(
        height: 220,
        width: double.infinity,
        color: Colors.white,
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MediaPlaceholder({
    required this.icon,
    this.label,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          if (label != null) ...[const SizedBox(height: 8), Text(label!)],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
