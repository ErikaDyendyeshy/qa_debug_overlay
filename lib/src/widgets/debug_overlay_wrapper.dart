import 'package:flutter/material.dart';
import '../controller/debug_overlay_controller.dart';
import 'draggable_debug_button.dart';
import 'debug_logs_bottom_sheet.dart';

/// Main debug overlay wrapper widget
///
/// Wraps your app and provides debug overlay functionality.
/// Simple Stack-based implementation - no OverlayEntry needed!
///
/// Usage:
/// ```dart
/// MaterialApp(
///   builder: (context, child) {
///     return DebugOverlayWrapper(child: child!);
///   },
/// );
/// ```
class DebugOverlayWrapper extends StatelessWidget {
  final Widget child;

  /// Set to false to render only [child] (e.g. in release builds).
  final bool enabled;

  const DebugOverlayWrapper(
      {super.key, required this.child, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return ListenableBuilder(
      listenable: DebugOverlayController.instance,
      builder: (context, _) {
        final controller = DebugOverlayController.instance;

        return Stack(
          children: [
            child,
            if (controller.isOverlayVisible && !controller.isBottomSheetVisible)
              const DraggableDebugButton(),
            if (controller.isBottomSheetVisible)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, sheet) => Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: controller.hideBottomSheet,
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55 * t),
                        ),
                      ),
                      FractionalTranslation(
                        translation: Offset(0, (1 - t) * 0.3),
                        child: Opacity(opacity: t, child: sheet),
                      ),
                    ],
                  ),
                  child: const DebugLogsBottomSheet(),
                ),
              ),
          ],
        );
      },
    );
  }
}
