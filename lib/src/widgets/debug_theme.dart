import 'package:flutter/material.dart';

import '../controller/debug_overlay_controller.dart';

/// Colors used by the overlay. The overlay always uses its own dark theme so
/// it looks the same in every host app.
abstract final class DebugColors {
  static const background = Color(0xFF0E1015);
  static const surface = Color(0xFF161920);
  static const surfaceHigh = Color(0xFF1E222B);
  static const border = Color(0xFF2A2F3A);
  static const text = Color(0xFFE8EAF0);
  static const textMuted = Color(0xFF8B93A7);
  static const textFaint = Color(0xFF5C6375);

  static const accent = Color(0xFF99BC33);
  static const onAccent = Color(0xFF10140A);

  static const success = Color(0xFF3DD68C);
  static const info = Color(0xFF4C9EFF);
  static const warning = Color(0xFFF5A524);
  static const error = Color(0xFFF3555A);
  static const purple = Color(0xFFB48CFF);

  // JSON syntax
  static const jsonKey = Color(0xFF7DCFFF);
  static const jsonString = Color(0xFF9ECE6A);
  static const jsonNumber = Color(0xFFFF9E64);
  static const jsonBool = Color(0xFFBB9AF7);
  static const jsonNull = Color(0xFF737AA2);
  static const jsonPunctuation = Color(0xFF6B7289);

  static Color forMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return info;
      case 'POST':
        return success;
      case 'PUT':
      case 'PATCH':
        return warning;
      case 'DELETE':
        return error;
      default:
        return purple;
    }
  }

  static Color forStatus(NetworkLog log) {
    if (log.statusCode == 0 || log.isServerError) return error;
    if (log.isClientError) return warning;
    if (log.isRedirect) return info;
    if (log.isSuccess) return success;
    return textMuted;
  }

  static Color forDuration(Duration duration) {
    if (duration.inMilliseconds < 500) return success;
    if (duration.inMilliseconds < 1000) return warning;
    return error;
  }
}

/// Text styles used by the overlay.
abstract final class DebugTextStyles {
  static const mono = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: ['monospace', 'Roboto Mono', 'Courier New', 'Courier'],
    fontSize: 12,
    height: 1.45,
    color: DebugColors.text,
  );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: DebugColors.textMuted,
  );
}

/// Theme applied to everything inside the overlay.
ThemeData buildDebugTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: DebugColors.accent,
      onPrimary: DebugColors.onAccent,
      secondary: DebugColors.accent,
      surface: DebugColors.surface,
      onSurface: DebugColors.text,
      error: DebugColors.error,
      outline: DebugColors.border,
      outlineVariant: DebugColors.border,
    ),
    scaffoldBackgroundColor: DebugColors.background,
    dividerColor: DebugColors.border,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: DebugColors.text,
      displayColor: DebugColors.text,
    ),
    iconTheme: const IconThemeData(color: DebugColors.textMuted, size: 20),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: DebugColors.accent,
      selectionColor: DebugColors.accent.withValues(alpha: 0.35),
      selectionHandleColor: DebugColors.accent,
    ),
  );
}

/// Formats a timestamp as `HH:mm:ss.SSS`.
String formatTime(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}'
      '.${time.millisecond.toString().padLeft(3, '0')}';
}

/// Formats a duration as `120 ms` or `1.42 s`.
String formatDuration(Duration duration) {
  final ms = duration.inMilliseconds;
  if (ms < 1000) return '$ms ms';
  return '${(ms / 1000).toStringAsFixed(2)} s';
}
