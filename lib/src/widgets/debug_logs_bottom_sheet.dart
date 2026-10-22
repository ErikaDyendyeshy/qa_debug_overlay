import 'package:flutter/material.dart';

import '../controller/debug_overlay_controller.dart';
import '../helpers/network_log_formatter.dart';
import 'debug_components.dart';
import 'debug_theme.dart';
import 'log_detail_view.dart';

enum _LogFilter {
  all('All'),
  success('2xx'),
  clientError('4xx'),
  serverError('5xx'),
  failed('Failed');

  const _LogFilter(this.label);

  final String label;

  bool matches(NetworkLog log) => switch (this) {
        _LogFilter.all => true,
        _LogFilter.success => log.isSuccess,
        _LogFilter.clientError => log.isClientError,
        _LogFilter.serverError => log.isServerError,
        _LogFilter.failed => log.isFailed,
      };
}

/// Bottom sheet with the list of network logs, search, status filters and
/// a detail view for each request.
class DebugLogsBottomSheet extends StatelessWidget {
  /// Creates a new [DebugLogsBottomSheet].
  const DebugLogsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // The overlay lives above the app's Navigator, so it brings its own
    // Overlay (needed by text fields and tooltips) and theme.
    return Theme(
      data: buildDebugTheme(),
      child: const _OverlayHost(child: CopyToastScope(child: _SheetBody())),
    );
  }
}

class _OverlayHost extends StatefulWidget {
  final Widget child;

  const _OverlayHost({required this.child});

  @override
  State<_OverlayHost> createState() => _OverlayHostState();
}

class _OverlayHostState extends State<_OverlayHost> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_OverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

class _SheetBody extends StatefulWidget {
  const _SheetBody();

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  final _searchController = TextEditingController();
  _LogFilter _filter = _LogFilter.all;
  String? _selectedId;

  DebugOverlayController get _controller => DebugOverlayController.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.75],
      builder: (context, scrollController) {
        return Material(
          color: DebugColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final logs = _controller.logs;
              final selected = _selectedId == null
                  ? null
                  : logs.where((log) => log.id == _selectedId).firstOrNull;
              return Column(
                children: [
                  const _DragHandle(),
                  Expanded(
                    child: selected != null
                        ? LogDetailView(
                            key: ValueKey(selected.id),
                            log: selected,
                            scrollController: scrollController,
                            onBack: () => setState(() => _selectedId = null),
                          )
                        : _buildList(context, logs, scrollController),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<NetworkLog> logs,
    ScrollController scrollController,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = logs
        .where(_filter.matches)
        .where((log) =>
            query.isEmpty ||
            log.url.toLowerCase().contains(query) ||
            log.method.toLowerCase().contains(query) ||
            log.statusCode.toString().contains(query))
        .toList();

    return Column(
      children: [
        _buildHeader(logs),
        _buildSearch(),
        _buildFilters(logs),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? _EmptyState(
                  scrollController: scrollController,
                  hasLogs: logs.isNotEmpty,
                )
              : ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _LogCard(
                    log: visible[index],
                    onTap: () =>
                        setState(() => _selectedId = visible[index].id),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader(List<NetworkLog> logs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.bug_report_rounded,
              color: DebugColors.accent, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Network',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: DebugColors.text,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: DebugColors.surfaceHigh,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${logs.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: DebugColors.textMuted,
              ),
            ),
          ),
          const Spacer(),
          DebugIconButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: 'Clear logs',
            onPressed: logs.isEmpty ? null : _controller.clearLogs,
          ),
          DebugIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            color: DebugColors.text,
            onPressed: _controller.hideBottomSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 14, color: DebugColors.text),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search URL, method or status',
          hintStyle: const TextStyle(color: DebugColors.textFaint),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(_searchController.clear),
                ),
          filled: true,
          fillColor: DebugColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DebugColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DebugColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DebugColors.accent),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(List<NetworkLog> logs) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final filter in _LogFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FilterChip(
                label: filter.label,
                count: logs.where(filter.matches).length,
                selected: _filter == filter,
                onTap: () => setState(() => _filter = filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: DebugColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? DebugColors.onAccent : DebugColors.textMuted;
    return Material(
      color: selected ? DebugColors.accent : DebugColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
            color: selected ? DebugColors.accent : DebugColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? DebugColors.onAccent : DebugColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(color: foreground, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final NetworkLog log;
  final VoidCallback onTap;

  const _LogCard({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = DebugColors.forStatus(log);
    final path = log.path?.isNotEmpty == true ? log.path! : log.endpoint;
    final host = log.domain?.replaceFirst(RegExp(r'^https?://'), '');

    return Material(
      color: DebugColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: DebugColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => copyToClipboard(
          context,
          NetworkLogFormatter.toCurl(log),
          label: 'cURL',
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MethodBadge(method: log.method),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: DebugColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(log: log),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DefaultTextStyle.merge(
                        style: const TextStyle(
                            fontSize: 12, color: DebugColors.textMuted),
                        child: Row(
                          children: [
                            if (host != null && host.isNotEmpty)
                              Flexible(
                                child: Text(host,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            if (log.queryParams?.isNotEmpty ?? false) ...[
                              const SizedBox(width: 6),
                              Text(
                                '?${log.queryParams!.length}',
                                style: const TextStyle(
                                    color: DebugColors.textFaint),
                              ),
                            ],
                            const Spacer(),
                            if (log.duration != null) ...[
                              Text(
                                formatDuration(log.duration!),
                                style: TextStyle(
                                    color:
                                        DebugColors.forDuration(log.duration!)),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Text(formatTime(log.timestamp)),
                          ],
                        ),
                      ),
                      if (log.errorMessage != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          log.errorMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: DebugColors.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ScrollController scrollController;
  final bool hasLogs;

  const _EmptyState({required this.scrollController, required this.hasLogs});

  @override
  Widget build(BuildContext context) {
    // Scrollable so the sheet can still be dragged when empty.
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 64),
      children: [
        Icon(
          hasLogs
              ? Icons.filter_alt_off_outlined
              : Icons.wifi_tethering_rounded,
          size: 44,
          color: DebugColors.textFaint,
        ),
        const SizedBox(height: 12),
        Text(
          hasLogs ? 'No requests match the filter' : 'Waiting for requests…',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: DebugColors.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          hasLogs
              ? 'Try another filter or search query'
              : 'Network calls made by the app will show up here',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: DebugColors.textFaint),
        ),
      ],
    );
  }
}
