import 'package:flutter/material.dart';

import '../controller/debug_overlay_controller.dart';
import '../helpers/network_log_formatter.dart';
import 'debug_components.dart';
import 'debug_theme.dart';
import 'json_viewer_widget.dart';

enum _DetailTab { overview, request, response }

/// Detailed view of a single network log: overview, request and response,
/// plus one-tap copy actions for cURL, request, response, auth token and
/// a ready-to-paste bug report.
class LogDetailView extends StatefulWidget {
  /// The network log entry to display.
  final NetworkLog log;

  /// Called when the back button is pressed. Hidden when null.
  final VoidCallback? onBack;

  /// Scroll controller for the content (e.g. from a draggable sheet).
  final ScrollController? scrollController;

  /// Creates a new [LogDetailView].
  const LogDetailView({
    super.key,
    required this.log,
    this.onBack,
    this.scrollController,
  });

  @override
  State<LogDetailView> createState() => _LogDetailViewState();
}

class _LogDetailViewState extends State<LogDetailView> {
  _DetailTab _tab = _DetailTab.overview;

  NetworkLog get log => widget.log;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _buildCopyActions(context),
              const SizedBox(height: 16),
              _buildTabs(context),
              const SizedBox(height: 12),
              ...switch (_tab) {
                _DetailTab.overview => _buildOverview(context),
                _DetailTab.request => _buildRequest(),
                _DetailTab.response => _buildResponse(),
              },
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              color: DebugColors.text,
              tooltip: 'Back',
              onPressed: widget.onBack,
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      MethodBadge(method: log.method),
                      const SizedBox(width: 8),
                      StatusBadge(log: log),
                      const Spacer(),
                      if (log.duration != null)
                        Text(
                          formatDuration(log.duration!),
                          style: DebugTextStyles.mono.copyWith(
                            color: DebugColors.forDuration(log.duration!),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onLongPress: () =>
                        copyToClipboard(context, log.url, label: 'URL'),
                    child: Text(
                      log.path?.isNotEmpty == true ? log.path! : log.endpoint,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: DebugColors.text,
                      ),
                    ),
                  ),
                  if (log.domain != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      log.domain!,
                      style: const TextStyle(
                          fontSize: 12.5, color: DebugColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyActions(BuildContext context) {
    final token = log.authToken;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        CopyChip(
          icon: Icons.terminal_rounded,
          label: 'cURL',
          primary: true,
          onPressed: () => copyToClipboard(
            context,
            NetworkLogFormatter.toCurl(log),
            label: 'cURL',
          ),
        ),
        CopyChip(
          icon: Icons.link_rounded,
          label: 'URL',
          onPressed: () => copyToClipboard(context, log.url, label: 'URL'),
        ),
        CopyChip(
          icon: Icons.north_east_rounded,
          label: 'Request',
          onPressed: () => copyToClipboard(
            context,
            NetworkLogFormatter.requestText(log),
            label: 'Request',
          ),
        ),
        CopyChip(
          icon: Icons.south_west_rounded,
          label: 'Response',
          onPressed: () => copyToClipboard(
            context,
            NetworkLogFormatter.responseText(log),
            label: 'Response',
          ),
        ),
        CopyChip(
          icon: Icons.key_rounded,
          label: 'Auth token',
          onPressed: token == null
              ? null
              : () => copyToClipboard(context, token, label: 'Auth token'),
        ),
        CopyChip(
          icon: Icons.bug_report_outlined,
          label: 'Bug report',
          onPressed: () => copyToClipboard(
            context,
            NetworkLogFormatter.bugReport(log),
            label: 'Bug report',
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context) {
    return SegmentedButton<_DetailTab>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: DebugColors.surface,
        foregroundColor: DebugColors.textMuted,
        selectedBackgroundColor: DebugColors.surfaceHigh,
        selectedForegroundColor: DebugColors.text,
        side: const BorderSide(color: DebugColors.border),
        textStyle: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(value: _DetailTab.overview, label: Text('Overview')),
        ButtonSegment(value: _DetailTab.request, label: Text('Request')),
        ButtonSegment(value: _DetailTab.response, label: Text('Response')),
      ],
      selected: {_tab},
      onSelectionChanged: (selection) => setState(() => _tab = selection.first),
    );
  }

  List<Widget> _buildOverview(BuildContext context) {
    final authHeader = log.authorizationHeader;
    return [
      if (log.errorMessage != null) ...[
        _ErrorBanner(message: log.errorMessage!),
        const SizedBox(height: 12),
      ],
      DebugPanel(
        title: 'General',
        child: KeyValueTable(values: {
          'URL': log.url,
          'Method': log.method.toUpperCase(),
          'Status': log.statusCode == 0
              ? 'No response'
              : '${log.statusCode} ${log.statusDescription}',
          if (log.duration != null) 'Duration': formatDuration(log.duration!),
          'Time': formatTime(log.timestamp),
          if (authHeader != null) 'Authorization': authHeader,
        }),
      ),
      if (log.queryParams?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        DebugPanel(
          title: 'Query parameters',
          child: KeyValueTable(values: log.queryParams!),
        ),
      ],
      const SizedBox(height: 12),
      Text(
        'Tip: tap a row to copy its value, long-press any JSON node to copy it.',
        style: const TextStyle(fontSize: 12, color: DebugColors.textFaint),
      ),
    ];
  }

  List<Widget> _buildRequest() {
    return [
      if (log.requestHeaders?.isNotEmpty ?? false) ...[
        DebugPanel(
          title: 'Headers',
          child: KeyValueTable(values: log.requestHeaders!),
        ),
        const SizedBox(height: 12),
      ],
      if (log.requestBody != null)
        JsonViewerWidget(
            title: 'Body', copyLabel: 'Request body', data: log.requestBody)
      else
        const _EmptyHint(text: 'No request body'),
    ];
  }

  List<Widget> _buildResponse() {
    return [
      if (log.errorMessage != null) ...[
        _ErrorBanner(message: log.errorMessage!),
        const SizedBox(height: 12),
      ],
      if (log.responseHeaders?.isNotEmpty ?? false) ...[
        DebugPanel(
          title: 'Headers',
          child: KeyValueTable(values: log.responseHeaders!),
        ),
        const SizedBox(height: 12),
      ],
      if (log.responseBody != null)
        JsonViewerWidget(
            title: 'Body', copyLabel: 'Response body', data: log.responseBody)
      else
        const _EmptyHint(text: 'No response body'),
    ];
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DebugColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DebugColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: DebugColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              message,
              style: DebugTextStyles.mono.copyWith(color: DebugColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text, style: const TextStyle(color: DebugColors.textFaint)),
      ),
    );
  }
}
