import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How often screens re-fetch their data while the app is in the foreground.
const refreshInterval = Duration(seconds: 30);

/// A counter that changes whenever screens should re-fetch. Watch it (or
/// listen to it) from data providers and screens; it ticks every
/// [refreshInterval] while the app is active, and once more on resume.
class RefreshTick extends Notifier<int> {
  Timer? _timer;
  bool _active = true;

  @override
  int build() {
    _timer = Timer.periodic(refreshInterval, (_) {
      if (_active) state++;
    });
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  /// Pauses ticking while the app is in the background.
  void setActive(bool active) => _active = active;

  /// Forces an immediate refresh (e.g. when the app is resumed).
  void pulse() => state++;
}

final refreshTickProvider =
    NotifierProvider<RefreshTick, int>(RefreshTick.new);
