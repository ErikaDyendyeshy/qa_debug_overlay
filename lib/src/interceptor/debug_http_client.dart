import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../controller/debug_overlay_controller.dart';

/// An `http` client that logs every request and response to the debug overlay.
///
/// Wraps any [http.Client], so it works with `http.get`-style code, Retrofit-like
/// generators and packages that accept a client.
///
/// ## Usage
///
/// ```dart
/// final client = DebugHttpClient();
/// final response = await client.get(Uri.parse('https://api.example.com/users'));
///
/// // Or wrap a client you already have:
/// final client = DebugHttpClient(inner: myClient);
/// ```
///
/// Response bodies are passed through as they stream; the log is added once
/// the body has been read.
class DebugHttpClient extends http.BaseClient {
  /// Creates a client that logs to [controller] (defaults to
  /// [DebugOverlayController.instance]) and sends requests with [inner]
  /// (defaults to a new [http.Client]).
  DebugHttpClient({http.Client? inner, DebugOverlayController? controller})
      : _inner = inner ?? http.Client(),
        _controller = controller ?? DebugOverlayController.instance;

  final http.Client _inner;
  final DebugOverlayController _controller;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();
    final requestBody = _requestBody(request);

    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (error) {
      _controller.addLog(_buildLog(
        request,
        requestBody: requestBody,
        duration: stopwatch.elapsed,
        errorMessage: _describeError(error),
      ));
      rethrow;
    }

    final chunks = <int>[];
    var logged = false;
    void log({String? errorMessage}) {
      if (logged) return;
      logged = true;
      _controller.addLog(_buildLog(
        request,
        requestBody: requestBody,
        duration: stopwatch.elapsed,
        response: response,
        responseBody: _decode(chunks, response.headers),
        errorMessage: errorMessage,
      ));
    }

    final stream = response.stream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          chunks.addAll(data);
          sink.add(data);
        },
        handleError: (error, stackTrace, sink) {
          log(errorMessage: _describeError(error));
          sink.addError(error, stackTrace);
        },
        handleDone: (sink) {
          log();
          sink.close();
        },
      ),
    );

    return http.StreamedResponse(
      stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();

  NetworkLog _buildLog(
    http.BaseRequest request, {
    required dynamic requestBody,
    required Duration duration,
    http.StreamedResponse? response,
    dynamic responseBody,
    String? errorMessage,
  }) {
    final uri = request.url;
    return NetworkLog.create(
      method: request.method,
      endpoint: uri.toString(),
      fullUrl: uri.toString(),
      domain: '${uri.scheme}://${uri.authority}',
      path: uri.path,
      queryParams: uri.queryParameters.isNotEmpty ? uri.queryParameters : null,
      statusCode: response?.statusCode ?? 0,
      duration: duration,
      requestHeaders: Map<String, dynamic>.of(request.headers),
      requestBody: requestBody,
      responseHeaders:
          response != null ? Map<String, dynamic>.of(response.headers) : null,
      responseBody: responseBody,
      errorMessage: errorMessage,
    );
  }

  dynamic _requestBody(http.BaseRequest request) {
    if (request is http.Request) {
      if (request.bodyBytes.isEmpty) return null;
      return _decode(request.bodyBytes, request.headers);
    }
    if (request is http.MultipartRequest) {
      return {
        ...request.fields,
        for (final file in request.files)
          file.field: '<file ${file.filename ?? ''} (${file.length} bytes)>',
      };
    }
    return '<stream>';
  }

  /// Decodes text bodies (JSON is parsed), summarizes binary ones.
  static dynamic _decode(List<int> bytes, Map<String, String> headers) {
    if (bytes.isEmpty) return null;
    final contentType = headers.entries
        .firstWhere(
          (e) => e.key.toLowerCase() == 'content-type',
          orElse: () => const MapEntry('', ''),
        )
        .value
        .toLowerCase();
    final isText = contentType.isEmpty ||
        contentType.startsWith('text/') ||
        contentType.contains('json') ||
        contentType.contains('xml') ||
        contentType.contains('x-www-form-urlencoded') ||
        contentType.contains('javascript');
    if (!isText) return '<binary ${bytes.length} bytes>';

    final text = utf8.decode(bytes, allowMalformed: true);
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  static String _describeError(Object error) {
    final type = error.runtimeType.toString();
    final message = error is http.ClientException ? error.message : '$error';
    return '[$type] $message';
  }
}
