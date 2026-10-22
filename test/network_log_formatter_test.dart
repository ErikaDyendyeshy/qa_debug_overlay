import 'package:flutter_test/flutter_test.dart';
import 'package:qa_debug_overlay/qa_debug_overlay.dart';

void main() {
  NetworkLog buildLog({
    Map<String, dynamic>? requestHeaders,
    dynamic requestBody,
    dynamic responseBody,
    int statusCode = 201,
    String? errorMessage,
  }) {
    return NetworkLog.create(
      method: 'post',
      endpoint: 'https://api.example.com/users?page=1',
      fullUrl: 'https://api.example.com/users?page=1',
      statusCode: statusCode,
      duration: const Duration(milliseconds: 240),
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      responseHeaders: {'content-type': 'application/json'},
      responseBody: responseBody,
      errorMessage: errorMessage,
    );
  }

  group('NetworkLogFormatter.toCurl', () {
    test('includes method, url, headers and JSON body', () {
      final curl = NetworkLogFormatter.toCurl(buildLog(
        requestHeaders: {
          'Authorization': 'Bearer abc',
          'Accept': 'application/json'
        },
        requestBody: {'name': 'Ann'},
      ));

      expect(
        curl,
        "curl -X POST 'https://api.example.com/users?page=1' \\\n"
        "  -H 'Authorization: Bearer abc' \\\n"
        "  -H 'Accept: application/json' \\\n"
        "  --data-raw '{\"name\":\"Ann\"}'",
      );
    });

    test('escapes single quotes for the shell', () {
      final curl = NetworkLogFormatter.toCurl(buildLog(requestBody: "it's"));
      expect(curl, contains(r"--data-raw 'it'\''s'"));
    });

    test('omits body when there is none', () {
      final curl = NetworkLogFormatter.toCurl(buildLog());
      expect(curl, isNot(contains('--data-raw')));
    });
  });

  group('NetworkLogFormatter.prettyJson', () {
    test('pretty prints maps and JSON strings', () {
      const expected = '{\n  "a": 1\n}';
      expect(NetworkLogFormatter.prettyJson({'a': 1}), expected);
      expect(NetworkLogFormatter.prettyJson('{"a":1}'), expected);
    });

    test('returns plain strings and invalid JSON unchanged', () {
      expect(NetworkLogFormatter.prettyJson('hello'), 'hello');
      expect(NetworkLogFormatter.prettyJson('{oops'), '{oops');
      expect(NetworkLogFormatter.prettyJson(null), 'null');
    });
  });

  test('requestText contains request line, headers and body', () {
    final text = NetworkLogFormatter.requestText(buildLog(
      requestHeaders: {'Accept': 'application/json'},
      requestBody: {'name': 'Ann'},
    ));

    expect(text, startsWith('POST https://api.example.com/users?page=1'));
    expect(text, contains('Headers:'));
    expect(text, contains('"name": "Ann"'));
  });

  test('responseText contains status, body and error', () {
    final text = NetworkLogFormatter.responseText(buildLog(
      statusCode: 404,
      responseBody: {'error': 'not found'},
      errorMessage: '[badResponse] 404',
    ));

    expect(text, startsWith('404 Client Error'));
    expect(text, contains('"error": "not found"'));
    expect(text, contains('[badResponse] 404'));
  });

  test('bugReport is markdown with cURL and bodies', () {
    final report = NetworkLogFormatter.bugReport(buildLog(
      requestBody: {'name': 'Ann'},
      responseBody: {'id': 7},
    ));

    expect(
        report, startsWith('**POST** `https://api.example.com/users?page=1`'));
    expect(report, contains('- Status: 201 Success'));
    expect(report, contains('- Duration: 240 ms'));
    expect(report, contains('```bash\ncurl -X POST'));
    expect(report, contains('**Request body**'));
    expect(report, contains('**Response body**'));
  });

  test('network errors are reported as "No response"', () {
    final report = NetworkLogFormatter.bugReport(buildLog(statusCode: 0));
    expect(report, contains('- Status: No response'));
  });
}
