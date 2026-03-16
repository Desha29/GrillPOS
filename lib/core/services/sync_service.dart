import 'dart:async';

class SyncService {
  final Duration interval;
  Timer? _timer;
  DateTime? _lastSyncAt;

  SyncService({this.interval = const Duration(minutes: 3)});

  DateTime? get lastSyncAt => _lastSyncAt;

  bool get isRunning => _timer != null;

  void start(Future<void> Function() onSync) {
    stop();
    _timer = Timer.periodic(interval, (_) async {
      try {
        await onSync();
        _lastSyncAt = DateTime.now();
      } catch (_) {
        // Keep background sync resilient; caller can add logging if needed.
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
