import 'package:flutter/material.dart';

import '../helpers/network_log_formatter.dart';
import 'debug_components.dart';
import 'debug_theme.dart';

/// Collapsible JSON tree with syntax colors.
///
/// Tap an object/array to fold it, long-press any row to copy its value.
class JsonTreeView extends StatelessWidget {
  /// The JSON data to display.
  final dynamic data;

  /// Nodes deeper than this start collapsed.
  final int initiallyExpandedDepth;

  const JsonTreeView({
    super.key,
    required this.data,
    this.initiallyExpandedDepth = 3,
  });

  @override
  Widget build(BuildContext context) {
    return _JsonNode(
      nodeKey: null,
      value: data,
      depth: 0,
      isLast: true,
      initiallyExpandedDepth: initiallyExpandedDepth,
    );
  }
}

class _JsonNode extends StatefulWidget {
  final Object? nodeKey;
  final dynamic value;
  final int depth;
  final bool isLast;
  final int initiallyExpandedDepth;

  const _JsonNode({
    required this.nodeKey,
    required this.value,
    required this.depth,
    required this.isLast,
    required this.initiallyExpandedDepth,
  });

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  late bool _expanded = widget.depth < widget.initiallyExpandedDepth;

  static const _indent = 14.0;

  bool get _isContainer => widget.value is Map || widget.value is List;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final comma = widget.isLast ? '' : ',';

    if (!_isContainer) {
      return _row(
        context,
        children: [
          ..._keySpans(),
          _valueSpan(value),
          _punct(comma),
        ],
      );
    }

    final isMap = value is Map;
    final open = isMap ? '{' : '[';
    final close = isMap ? '}' : ']';
    final List<MapEntry<dynamic, dynamic>> entries = value is Map
        ? value.entries.toList()
        : (value as List).asMap().entries.toList();

    if (entries.isEmpty) {
      return _row(context,
          children: [..._keySpans(), _punct('$open$close$comma')]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
          context,
          chevron: true,
          onTap: () => setState(() => _expanded = !_expanded),
          children: [
            ..._keySpans(),
            _punct(open),
            if (!_expanded) ...[
              TextSpan(
                text: ' ${entries.length} ${isMap ? 'keys' : 'items'} ',
                style: DebugTextStyles.mono.copyWith(
                  color: DebugColors.textFaint,
                  fontStyle: FontStyle.italic,
                ),
              ),
              _punct('$close$comma'),
            ],
          ],
        ),
        if (_expanded) ...[
          Container(
            margin: const EdgeInsets.only(left: 7),
            padding: const EdgeInsets.only(left: _indent - 7),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: DebugColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < entries.length; i++)
                  _JsonNode(
                    nodeKey: isMap ? entries[i].key : null,
                    value: entries[i].value,
                    depth: widget.depth + 1,
                    isLast: i == entries.length - 1,
                    initiallyExpandedDepth: widget.initiallyExpandedDepth,
                  ),
              ],
            ),
          ),
          _row(context, children: [_punct('$close$comma')]),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required List<InlineSpan> children,
    bool chevron = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: () => copyToClipboard(
        context,
        NetworkLogFormatter.prettyJson(widget.value),
        label: widget.nodeKey != null ? '"${widget.nodeKey}"' : 'Value',
      ),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 17,
              child: chevron
                  ? Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 14,
                      color: DebugColors.textMuted,
                    )
                  : null,
            ),
            Flexible(
              child: Text.rich(
                  TextSpan(children: children, style: DebugTextStyles.mono)),
            ),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _keySpans() {
    final key = widget.nodeKey;
    if (key == null) return const [];
    return [
      TextSpan(
        text: '"$key"',
        style: DebugTextStyles.mono.copyWith(color: DebugColors.jsonKey),
      ),
      _punct(': '),
    ];
  }

  static TextSpan _punct(String text) => TextSpan(
        text: text,
        style:
            DebugTextStyles.mono.copyWith(color: DebugColors.jsonPunctuation),
      );

  static TextSpan _valueSpan(dynamic value) {
    final String text;
    final Color color;
    if (value is String) {
      text = '"$value"';
      color = DebugColors.jsonString;
    } else if (value is num) {
      text = '$value';
      color = DebugColors.jsonNumber;
    } else if (value is bool) {
      text = '$value';
      color = DebugColors.jsonBool;
    } else if (value == null) {
      text = 'null';
      color = DebugColors.jsonNull;
    } else {
      text = '$value';
      color = DebugColors.text;
    }
    return TextSpan(
        text: text, style: DebugTextStyles.mono.copyWith(color: color));
  }
}

/// Syntax-highlights already pretty-printed JSON text.
TextSpan highlightJson(String source) {
  final pattern = RegExp(
    r'("(?:[^"\\]|\\.)*")(\s*:)?|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|\b(true|false)\b|\b(null)\b',
  );
  final spans = <TextSpan>[];
  var last = 0;
  for (final match in pattern.allMatches(source)) {
    if (match.start > last) {
      spans.add(TextSpan(
        text: source.substring(last, match.start),
        style: const TextStyle(color: DebugColors.jsonPunctuation),
      ));
    }
    if (match.group(1) != null) {
      final isKey = match.group(2) != null;
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
            color: isKey ? DebugColors.jsonKey : DebugColors.jsonString),
      ));
      if (isKey) {
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(color: DebugColors.jsonPunctuation),
        ));
      }
    } else if (match.group(3) != null) {
      spans.add(TextSpan(
        text: match.group(3),
        style: const TextStyle(color: DebugColors.jsonNumber),
      ));
    } else if (match.group(4) != null) {
      spans.add(TextSpan(
        text: match.group(4),
        style: const TextStyle(color: DebugColors.jsonBool),
      ));
    } else {
      spans.add(TextSpan(
        text: match.group(5),
        style: const TextStyle(color: DebugColors.jsonNull),
      ));
    }
    last = match.end;
  }
  if (last < source.length) {
    spans.add(TextSpan(
      text: source.substring(last),
      style: const TextStyle(color: DebugColors.jsonPunctuation),
    ));
  }
  return TextSpan(style: DebugTextStyles.mono, children: spans);
}
