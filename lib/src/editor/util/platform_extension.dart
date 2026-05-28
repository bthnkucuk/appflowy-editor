import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' show window;
import 'package:universal_platform/universal_platform.dart';

// TODO(Xazin): Refactor to honor `Theme.platform`
extension PlatformExtension on Platform {
  static String get _webPlatform =>
      window.navigator.platform?.toLowerCase() ?? '';

  /// Returns true if the operating system is macOS and not running on Web platform.
  static bool get isMacOS => UniversalPlatform.isMacOS;

  /// Returns true if the operating system is Windows and not running on Web platform.
  static bool get isWindows => UniversalPlatform.isWindows;

  /// Returns true if the operating system is Linux and not running on Web platform.
  static bool get isLinux => UniversalPlatform.isLinux;

  /// Returns true if the operating system is iOS and not running on Web platform.
  static bool get isIOS {
    final override = debugPlatformOverride;
    if (override != null) return override == DebugPlatform.ios;
    return UniversalPlatform.isIOS;
  }

  /// Returns true if the operating system is Android and not running on Web platform.
  static bool get isAndroid {
    final override = debugPlatformOverride;
    if (override != null) return override == DebugPlatform.android;
    return UniversalPlatform.isAndroid;
  }

  /// Returns true if the operating system is macOS and running on Web platform.
  static bool get isWebOnMacOS {
    if (!kIsWeb) {
      return false;
    }

    return _webPlatform.contains('mac') == true;
  }

  /// Returns true if the operating system is Windows and running on Web platform.
  static bool get isWebOnWindows {
    if (!kIsWeb) {
      return false;
    }

    return _webPlatform.contains('windows') == true;
  }

  /// Returns true if the operating system is Linux and running on Web platform.
  static bool get isWebOnLinux {
    if (!kIsWeb) {
      return false;
    }

    return _webPlatform.contains('linux') == true;
  }

  static bool get isDesktopOrWeb {
    final override = debugPlatformOverride;
    if (override != null) return override == DebugPlatform.desktopOrWeb;
    return UniversalPlatform.isWeb || UniversalPlatform.isDesktop;
  }

  static bool get isDesktop => UniversalPlatform.isDesktop;

  static bool get isMobile {
    final override = debugPlatformOverride;
    if (override != null) {
      return override == DebugPlatform.android ||
          override == DebugPlatform.ios;
    }
    return UniversalPlatform.isMobile;
  }

  static bool get isNotMobile => !isMobile;

  /// Test-only override for mobile/desktop platform detection. Set
  /// before mounting the editor in a widget test so
  /// `SelectionServiceWidget` mounts the `MobileSelectionService`
  /// branch (and its iOS/Android gesture strategy). Production code
  /// must never set this — the bare static is the simplest mock
  /// surface and behaves like `debugDefaultTargetPlatformOverride`.
  ///
  /// Reset to `null` in a tearDown to leave the harness clean for
  /// other tests.
  @visibleForTesting
  static DebugPlatform? debugPlatformOverride;
}

/// Platform identity for [PlatformExtension.debugPlatformOverride] —
/// mirrors the iOS / Android / desktop+web branches the editor reads
/// elsewhere. Public so test files can write
/// `PlatformExtension.debugPlatformOverride = DebugPlatform.android`
/// without an analyzer escape hatch; the override itself is gated by
/// `@visibleForTesting` so production code can't set it.
enum DebugPlatform { android, ios, desktopOrWeb }
