import 'package:flutter/material.dart';

import '../controller/debug_overlay_controller.dart';
import 'debug_theme.dart';

/// Draggable floating debug button.
///
/// Shows the number of captured requests and a red dot when one of them
/// failed. Drag it anywhere — on release it snaps to the nearest side.
/// Tap to open the debug logs bottom sheet.
class DraggableDebugButton extends StatefulWidget {
  const DraggableDebugButton({super.key});

  @override
  State<DraggableDebugButton> createState() => _DraggableDebugButtonState();
}

class _DraggableDebugButtonState extends State<DraggableDebugButton> {
  // Persist the position across rebuilds when the sheet opens and closes.
  static Offset? _savedPosition;

  bool _isDragging = false;

  static const double buttonSize = 56.0;
  static const double _margin = 12.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final position = _clamp(
      _savedPosition ??
          Offset(size.width - buttonSize - _margin, size.height * 0.6),
      size,
      padding,
    );

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) => setState(() {
          _savedPosition = _clamp(position + details.delta, size, padding);
        }),
        onPanEnd: (_) => setState(() {
          _isDragging = false;
          final snapLeft = position.dx + buttonSize / 2 < size.width / 2;
          _savedPosition = Offset(
            snapLeft ? _margin : size.width - buttonSize - _margin,
            position.dy,
          );
        }),
        onTap: DebugOverlayController.instance.showBottomSheet,
        child: ListenableBuilder(
          listenable: DebugOverlayController.instance,
          builder: (context, _) {
            final logs = DebugOverlayController.instance.logs;
            final hasFailures = logs.any((log) => log.isFailed);
            return AnimatedScale(
              scale: _isDragging ? 1.08 : 1,
              duration: const Duration(milliseconds: 150),
              child: _ButtonBody(count: logs.length, hasFailures: hasFailures),
            );
          },
        ),
      ),
    );
  }

  Offset _clamp(Offset offset, Size size, EdgeInsets padding) {
    return Offset(
      offset.dx
          .clamp(0.0, (size.width - buttonSize).clamp(0.0, double.infinity)),
      offset.dy.clamp(
        padding.top,
        (size.height - buttonSize - padding.bottom)
            .clamp(padding.top, double.infinity),
      ),
    );
  }
}

class _ButtonBody extends StatelessWidget {
  final int count;
  final bool hasFailures;

  const _ButtonBody({required this.count, required this.hasFailures});

  @override
  Widget build(BuildContext context) {
    const size = _DraggableDebugButtonState.buttonSize;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: DebugColors.background,
              shape: BoxShape.circle,
              border: Border.all(color: DebugColors.accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: DebugColors.accent.withValues(alpha: 0.35),
                  blurRadius: 18,
                ),
                const BoxShadow(
                  color: Colors.black38,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bug_report_rounded,
              color: DebugColors.accent,
              size: 28,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasFailures ? DebugColors.error : DebugColors.accent,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: DebugColors.background, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    color: hasFailures ? Colors.white : DebugColors.onAccent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
