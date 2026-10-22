import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/debug_overlay_controller.dart';
import 'debug_theme.dart';

/// Copies [text] to the clipboard and shows a short confirmation toast
/// when a [CopyToastScope] is above [context].
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  required String label,
}) async {
  final scope = CopyToastScope.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.selectionClick();
  scope?.show('$label copied');
}

/// Hosts the "copied" toast for everything below it.
class CopyToastScope extends StatefulWidget {
  final Widget child;

  const CopyToastScope({super.key, required this.child});

  static CopyToastScopeState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<CopyToastScopeState>();

  @override
  State<CopyToastScope> createState() => CopyToastScopeState();
}

class CopyToastScopeState extends State<CopyToastScope> {
  String? _message;
  Timer? _timer;

  void show(String message) {
    _timer?.cancel();
    setState(() => _message = message);
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _message = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // At the top: Android 13+ shows its own clipboard preview at the
        // bottom-left corner.
        Positioned(
          left: 0,
          right: 0,
          top: 12 + MediaQuery.paddingOf(context).top,
          child: IgnorePointer(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: _message == null
                    ? const SizedBox.shrink()
                    : Material(
                        key: ValueKey(_message),
                        type: MaterialType.transparency,
                        child: _Toast(message: _message!),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Toast extends StatelessWidget {
  final String message;

  const _Toast({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: DebugColors.text,
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: DebugColors.background),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              color: DebugColors.background,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Colored HTTP method label.
class MethodBadge extends StatelessWidget {
  final String method;

  const MethodBadge({super.key, required this.method});

  @override
  Widget build(BuildContext context) {
    final color = DebugColors.forMethod(method);
    return Container(
      constraints: const BoxConstraints(minWidth: 48),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        method.toUpperCase(),
        maxLines: 1,
        style: DebugTextStyles.mono.copyWith(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Colored status code pill.
class StatusBadge extends StatelessWidget {
  final NetworkLog log;

  const StatusBadge({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final color = DebugColors.forStatus(log);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            log.statusCode == 0 ? 'ERR' : '${log.statusCode}',
            style: DebugTextStyles.mono.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded panel with an optional header row.
class DebugPanel extends StatelessWidget {
  final String? title;
  final List<Widget> actions;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DebugPanel({
    super.key,
    this.title,
    this.actions = const [],
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: DebugColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DebugColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: const BoxDecoration(
                color: DebugColors.surfaceHigh,
                border: Border(bottom: BorderSide(color: DebugColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!.toUpperCase(),
                        style: DebugTextStyles.label),
                  ),
                  ...actions,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Small icon button used in panel headers.
class DebugIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const DebugIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: color ?? DebugColors.textMuted,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

/// Pill-shaped action button (e.g. "cURL", "Response").
class CopyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  const CopyChip({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = primary ? DebugColors.accent : DebugColors.surfaceHigh;
    final foreground = !enabled
        ? DebugColors.textFaint
        : primary
            ? DebugColors.onAccent
            : DebugColors.text;
    return Material(
      color: enabled ? background : DebugColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: primary ? background : DebugColors.border),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Key/value rows (headers, query params). Tap a row to copy its value.
class KeyValueTable extends StatelessWidget {
  final Map<String, dynamic> values;

  const KeyValueTable({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return Text('—',
          style: DebugTextStyles.mono.copyWith(color: DebugColors.textFaint));
    }
    final entries = values.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => copyToClipboard(
              context,
              _stringify(entries[i].value),
              label: entries[i].key,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              decoration: BoxDecoration(
                border: i == entries.length - 1
                    ? null
                    : const Border(
                        bottom:
                            BorderSide(color: DebugColors.border, width: 0.5),
                      ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      entries[i].key,
                      style: DebugTextStyles.mono
                          .copyWith(color: DebugColors.jsonKey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _stringify(entries[i].value),
                      style: DebugTextStyles.mono,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _stringify(dynamic value) =>
      value is List ? value.join(', ') : '$value';
}
