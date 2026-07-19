import 'package:flutter/foundation.dart';

enum AppRuntimeMode { debug, release }

/// Single source of truth for runtime behavior that must differ between
/// development and production builds.
abstract final class AppEnvironment {
  static const _requestedMode = String.fromEnvironment('APP_MODE');

  static AppRuntimeMode get mode {
    // A compiled release binary can never be downgraded to debug behavior via
    // a dart-define. This keeps seed credentials and test data out of release.
    if (kReleaseMode) return AppRuntimeMode.release;
    if (_requestedMode.toLowerCase() == 'release') {
      return AppRuntimeMode.release;
    }
    return AppRuntimeMode.debug;
  }

  static bool get isDebug => mode == AppRuntimeMode.debug;
  static bool get isRelease => mode == AppRuntimeMode.release;

  static bool get shouldSeedDebugData => kDebugMode && isDebug;

  static const bool enableDevicePreview =
      bool.fromEnvironment('ENABLE_DEVICE_PREVIEW', defaultValue: false);

  static const String debugDataPath =
      String.fromEnvironment('DEBUG_DATA_PATH', defaultValue: '');

  static String get displayName => isDebug ? 'DEBUG' : 'RELEASE';
}
