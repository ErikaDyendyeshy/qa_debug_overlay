import 'dart:convert';

import '../controller/debug_overlay_controller.dart';

/// Turns a [NetworkLog] into text that QA can paste into Jira, Slack or a
/// terminal: cURL commands, request/response dumps and a full bug report.
class NetworkLogFormatter {
  NetworkLogFormatter._();

  static const _encoder = JsonEncoder.withIndent('  ');

  /// Pretty-prints [data] as JSON when possible, otherwise returns
  /// its string form. JSON strings are decoded first.
  static String prettyJson(dynamic data) {
    if (data == null) return 'null';
    var value = data;
    if (value is String) {
      final trimmed = value.trim();
      if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return value;
      try {
        value = jsonDecode(trimmed);
      } catch (_) {
        return data;
      }
    }
    try {
      return _encoder.convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  /// A cURL command that reproduces the request.
  static String toCurl(NetworkLog log) {
    final buffer = StringBuffer(
        "curl -X ${log.method.toUpperCase()} '${_escape(log.url)}'");
    log.requestHeaders?.forEach((key, value) {
      if (value == null) return;
      final headerValue = value is List ? value.join(', ') : value.toString();
      buffer.write(" \\\n  -H '${_escape('$key: $headerValue')}'");
    });
    final body = log.requestBody;
    if (body != null) {
      final data = body is String ? body : _compactJson(body);
      buffer.write(" \\\n  --data-raw '${_escape(data)}'");
    }
    return buffer.toString();
  }

  /// Request line, headers and body.
  static String requestText(NetworkLog log) {
    final buffer = StringBuffer('${log.method.toUpperCase()} ${log.url}\n');
    if (log.requestHeaders?.isNotEmpty ?? false) {
      buffer.write('\nHeaders:\n${prettyJson(log.requestHeaders)}\n');
    }
    if (log.requestBody != null) {
      buffer.write('\nBody:\n${prettyJson(log.requestBody)}\n');
    }
    return buffer.toString().trimRight();
  }

  /// Status line, headers and body of the response.
  static String responseText(NetworkLog log) {
    final buffer = StringBuffer('${_statusLine(log)}\n');
    if (log.responseHeaders?.isNotEmpty ?? false) {
      buffer.write('\nHeaders:\n${prettyJson(log.responseHeaders)}\n');
    }
    if (log.responseBody != null) {
      buffer.write('\nBody:\n${prettyJson(log.responseBody)}\n');
    }
    if (log.errorMessage != null) {
      buffer.write('\nError:\n${log.errorMessage}\n');
    }
    return buffer.toString().trimRight();
  }

  /// A Markdown bug report with everything backend and frontend devs need.
  static String bugReport(NetworkLog log) {
    final buffer = StringBuffer()
      ..writeln('**${log.method.toUpperCase()}** `${log.url}`')
      ..writeln()
      ..writeln('- Status: ${_statusLine(log)}')
      ..writeln('- Time: ${log.timestamp.toIso8601String()}');
    if (log.duration != null) {
      buffer.writeln('- Duration: ${log.duration!.inMilliseconds} ms');
    }
    if (log.errorMessage != null) {
      buffer.writeln('- Error: ${log.errorMessage}');
    }
    buffer
      ..writeln()
      ..writeln('**cURL**')
      ..writeln('```bash')
      ..writeln(toCurl(log))
      ..writeln('```');
    if (log.requestBody != null) {
      buffer
        ..writeln()
        ..writeln('**Request body**')
        ..writeln('```json')
        ..writeln(prettyJson(log.requestBody))
        ..writeln('```');
    }
    if (log.responseHeaders?.isNotEmpty ?? false) {
      buffer
        ..writeln()
        ..writeln('**Response headers**')
        ..writeln('```json')
        ..writeln(prettyJson(log.responseHeaders))
        ..writeln('```');
    }
    if (log.responseBody != null) {
      buffer
        ..writeln()
        ..writeln('**Response body**')
        ..writeln('```json')
        ..writeln(prettyJson(log.responseBody))
        ..writeln('```');
    }
    return buffer.toString().trimRight();
  }

  static String _statusLine(NetworkLog log) => log.statusCode == 0
      ? 'No response'
      : '${log.statusCode} ${log.statusDescription}';

  static String _compactJson(dynamic data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  /// Escapes single quotes for a single-quoted shell string.
  static String _escape(String value) => value.replaceAll("'", r"'\''");
}
