import 'dart:convert';

import 'package:dio/dio.dart';

import '../controller/debug_overlay_controller.dart';

/// A Dio interceptor that captures all network requests and responses for debugging purposes.
///
/// This interceptor automatically logs all HTTP traffic to the debug overlay,
/// including request/response headers, body content, timing information,
/// and error details.
///
/// ## Usage
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(DebugInterceptor());
/// ```
class DebugInterceptor extends Interceptor {
  static const _startTimeKey = 'qa_debug_overlay_start_time';

  /// Creates a new [DebugInterceptor]. Logs go to [controller], which
  /// defaults to [DebugOverlayController.instance].
  DebugInterceptor({DebugOverlayController? controller})
      : _controller = controller ?? DebugOverlayController.instance;

  final DebugOverlayController _controller;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startTimeKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _controller.addLog(
      _buildLog(response.requestOptions, response: response),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _controller.addLog(
      _buildLog(
        err.requestOptions,
        response: err.response,
        errorMessage: _describeError(err),
      ),
    );
    handler.next(err);
  }

  NetworkLog _buildLog(
    RequestOptions options, {
    Response? response,
    String? errorMessage,
  }) {
    final startTime = options.extra[_startTimeKey];
    final duration = startTime is DateTime
        ? DateTime.now().difference(startTime)
        : Duration.zero;
    final uri = options.uri;

    return NetworkLog.create(
      method: options.method,
      endpoint: uri.toString(),
      fullUrl: uri.toString(),
      domain: '${uri.scheme}://${uri.authority}',
      path: uri.path,
      queryParams: uri.queryParameters.isNotEmpty ? uri.queryParameters : null,
      statusCode: response?.statusCode ?? 0,
      requestHeaders: _requestHeaders(options),
      requestBody: _processBody(options.data),
      responseHeaders: response != null
          ? _convertHeadersToStringMap(response.headers.map)
          : null,
      responseBody: _processBody(response?.data),
      duration: duration,
      errorMessage: errorMessage,
    );
  }

  /// Request headers including the content type Dio sends separately.
  Map<String, dynamic> _requestHeaders(RequestOptions options) {
    final headers = Map<String, dynamic>.of(options.headers);
    final hasContentType = headers.keys
        .any((key) => key.toLowerCase() == Headers.contentTypeHeader);
    if (!hasContentType &&
        options.contentType != null &&
        options.data != null) {
      headers[Headers.contentTypeHeader] = options.contentType;
    }
    return headers;
  }

  String _describeError(DioException err) {
    final type = err.type.name;
    final response = err.response;
    // Dio's badResponse message is a long generic paragraph; the status line
    // says the same thing in a few words.
    if (err.type == DioExceptionType.badResponse && response != null) {
      final reason = response.statusMessage;
      return '[$type] HTTP ${response.statusCode}'
          '${reason != null && reason.isNotEmpty ? ' $reason' : ''}';
    }
    final message = err.message ?? err.error?.toString();
    return message != null && message.isNotEmpty
        ? '[$type] $message'
        : '[$type]';
  }

  /// Converts headers from `Map<String, List<String>>` to `Map<String, dynamic>`
  /// for better JSON display in the debug overlay.
  Map<String, dynamic> _convertHeadersToStringMap(
    Map<String, List<String>> headers,
  ) {
    return headers.map(
      (key, values) =>
          MapEntry(key, values.length == 1 ? values.first : values),
    );
  }

  /// Converts request/response data to something the JSON viewer can show.
  dynamic _processBody(dynamic data) {
    if (data == null) return null;

    // ResponseType.bytes gives List<int>; decoded JSON arrays are List<dynamic>.
    if (data is List<int>) return '<binary ${data.length} bytes>';

    if (data is Map || data is List) return data;

    if (data is FormData) {
      return {
        for (final field in data.fields) field.key: field.value,
        for (final file in data.files)
          file.key: '<file ${file.value.filename ?? ''} '
              '(${file.value.length} bytes)>',
      };
    }

    if (data is ResponseBody || data is Stream) return '<stream>';

    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }

    return data.toString();
  }
}
