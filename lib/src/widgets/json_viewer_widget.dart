import 'dart:convert';

import 'package:flutter/material.dart';

import '../helpers/network_log_formatter.dart';
import 'debug_components.dart';
import 'debug_theme.dart';
import 'json_tree_view.dart';

/// Panel that shows a body as a JSON tree or as raw, selectable text,
/// with a copy button in the header.
class JsonViewerWidget extends StatefulWidget {
  /// The data to display (can be string, map, list, or other types).
  final dynamic data;

  /// The title to display above the JSON content.
  final String title;

  /// Label used in the "copied" toast.
  final String? copyLabel;

  const JsonViewerWidget({
    super.key,
    required this.data,
    required this.title,
    this.copyLabel,
  });

  @override
  State<JsonViewerWidget> createState() => _JsonViewerWidgetState();
}

class _JsonViewerWidgetState extends State<JsonViewerWidget> {
  bool _raw = false;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseJsonData(widget.data);
    final isStructured = parsed is Map || parsed is List;
    final pretty = NetworkLogFormatter.prettyJson(widget.data);

    return DebugPanel(
      title: widget.title,
      actions: [
        if (isStructured)
          DebugIconButton(
            icon: _raw ? Icons.account_tree_outlined : Icons.notes_rounded,
            tooltip: _raw ? 'Tree view' : 'Raw view',
            onPressed: () => setState(() => _raw = !_raw),
          ),
        DebugIconButton(
          icon: Icons.copy_rounded,
          tooltip: 'Copy',
          onPressed: () => copyToClipboard(
            context,
            pretty,
            label: widget.copyLabel ?? widget.title,
          ),
        ),
      ],
      child: !isStructured
          ? SelectableText(
              pretty,
              style: DebugTextStyles.mono.copyWith(
                color: widget.data == null
                    ? DebugColors.jsonNull
                    : DebugColors.text,
              ),
            )
          : _raw
              ? SelectableText.rich(highlightJson(pretty))
              : JsonTreeView(data: parsed),
    );
  }

  /// Decodes JSON strings so they can be shown as a tree.
  static dynamic _parseJsonData(dynamic data) {
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {
          return data;
        }
      }
    }
    return data;
  }
}
