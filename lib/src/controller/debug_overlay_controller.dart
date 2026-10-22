import 'package:flutter/foundation.dart';

/// Simple data model for network logs
class NetworkLog {
  final String id;
  final String method;
  final String endpoint;
  final String? fullUrl;
  final String? domain;
  final String? path;
  final Map<String, dynamic>? queryParams;
  final int statusCode;
  final DateTime timestamp;
  final Duration? duration;
  final Map<String, dynamic>? requestHeaders;
  final dynamic requestBody;
  final Map<String, dynamic>? responseHeaders;
  final dynamic responseBody;
  final String? errorMessage;

  NetworkLog({
    required this.id,
    required this.method,
    required this.endpoint,
    this.fullUrl,
    this.domain,
    this.path,
    this.queryParams,
    required this.statusCode,
    required this.timestamp,
    this.duration,
    this.requestHeaders,
    this.requestBody,
    this.responseHeaders,
    this.responseBody,
    this.errorMessage,
  });

  static int _counter = 0;

  factory NetworkLog.create({
    required String method,
    required String endpoint,
    String? fullUrl,
    String? domain,
    String? path,
    Map<String, dynamic>? queryParams,
    required int statusCode,
    Duration? duration,
    Map<String, dynamic>? requestHeaders,
    dynamic requestBody,
    Map<String, dynamic>? responseHeaders,
    dynamic responseBody,
    String? errorMessage,
  }) {
    final now = DateTime.now();
    return NetworkLog(
      // Counter suffix keeps ids unique for logs created in the same millisecond.
      id: '${now.microsecondsSinceEpoch}-${_counter++}',
      method: method,
      endpoint: endpoint,
      fullUrl: fullUrl,
      domain: domain,
      path: path,
      queryParams: queryParams,
      statusCode: statusCode,
      timestamp: now,
      duration: duration,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      responseHeaders: responseHeaders,
      responseBody: responseBody,
      errorMessage: errorMessage,
    );
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  bool get isRedirect => statusCode >= 300 && statusCode < 400;

  bool get isClientError => statusCode >= 400 && statusCode < 500;

  bool get isServerError => statusCode >= 500 && statusCode < 600;

  /// True when the request failed: HTTP 4xx/5xx, no status (network error)
  /// or an explicit error message.
  bool get isFailed =>
      errorMessage != null || statusCode == 0 || statusCode >= 400;

  String get statusDescription {
    if (isSuccess) return 'Success';
    if (isRedirect) return 'Redirect';
    if (isClientError) return 'Client Error';
    if (isServerError) return 'Server Error';
    if (statusCode == 0) return 'No Response';
    return 'Unknown';
  }

  /// The best available URL for this log.
  String get url => fullUrl ?? endpoint;

  /// Value of the `Authorization` request header (case-insensitive), if any.
  String? get authorizationHeader {
    final headers = requestHeaders;
    if (headers == null) return null;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization' && entry.value != null) {
        final value = entry.value;
        return value is List ? value.join(', ') : value.toString();
      }
    }
    return null;
  }

  /// The auth token without its scheme (`Bearer`, `Basic`, ...), if any.
  String? get authToken {
    final header = authorizationHeader?.trim();
    if (header == null || header.isEmpty) return null;
    final match =
        RegExp(r'^(Bearer|Basic|Token|JWT|OAuth)\s+(.+)$', caseSensitive: false)
            .firstMatch(header);
    return match != null ? match.group(2)!.trim() : header;
  }
}

/// Main controller for debug overlay
///
/// Singleton that manages all debug overlay state using ChangeNotifier.
/// Much simpler than BLoC - no dependencies, no conflicts!
class DebugOverlayController extends ChangeNotifier {
  // Singleton
  static final instance = DebugOverlayController._();

  DebugOverlayController._();

  final List<NetworkLog> _logs = [];
  bool _isOverlayVisible = true;
  bool _isBottomSheetVisible = false;

  static const int maxLogs = 100;

  List<NetworkLog> get logs => List.unmodifiable(_logs);

  bool get isOverlayVisible => _isOverlayVisible;

  bool get isBottomSheetVisible => _isBottomSheetVisible;

  /// Add a new network log
  void addLog(NetworkLog log) {
    _logs.insert(0, log);

    if (_logs.length > maxLogs) {
      _logs.removeRange(maxLogs, _logs.length);
    }

    notifyListeners();
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Show/hide overlay
  void setOverlayVisible(bool visible) {
    _isOverlayVisible = visible;
    if (!visible) {
      _isBottomSheetVisible = false;
    }
    notifyListeners();
  }

  /// Show bottom sheet
  void showBottomSheet() {
    _isBottomSheetVisible = true;
    notifyListeners();
  }

  /// Hide bottom sheet
  void hideBottomSheet() {
    _isBottomSheetVisible = false;
    notifyListeners();
  }

  /// Reset to initial state
  void reset() {
    _logs.clear();
    _isOverlayVisible = true;
    _isBottomSheetVisible = false;
    notifyListeners();
  }
}
