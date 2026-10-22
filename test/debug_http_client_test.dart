import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qa_debug_overlay/qa_debug_overlay.dart';

void main() {
  final controller = DebugOverlayController.instance;

  setUp(controller.reset);

  DebugHttpClient clientReturning(http.Response response) =>
      DebugHttpClient(inner: MockClient((_) async => response));

  test('logs request and response with url parts, headers and JSON bodies',
      () async {
    late http.Request sent;
    final client = DebugHttpClient(
      inner: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({'id': 1}),
          201,
          headers: {'content-type': 'application/json'},
          reasonPhrase: 'Created',
        );
      }),
    );

    final response = await client.post(
      Uri.parse('https://api.example.com/users?page=2'),
      headers: {
        'Authorization': 'Bearer secret',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': 'Ann'}),
    );

    // The caller still gets the full, untouched response.
    expect(response.statusCode, 201);
    expect(jsonDecode(response.body), {'id': 1});
    expect(sent.body, '{"name":"Ann"}');

    final log = controller.logs.single;
    expect(log.method, 'POST');
    expect(log.statusCode, 201);
    expect(log.domain, 'https://api.example.com');
    expect(log.path, '/users');
    expect(log.queryParams, {'page': '2'});
    expect(log.requestBody, {'name': 'Ann'});
    expect(log.responseBody, {'id': 1});
    expect(log.responseHeaders?['content-type'], 'application/json');
    expect(log.authToken, 'secret');
    expect(log.duration, isNotNull);
    expect(log.errorMessage, isNull);
  });

  test('logs error status codes as failed', () async {
    final client = clientReturning(http.Response(
      '{"error":"nope"}',
      404,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ));

    final response = await client.get(Uri.parse('https://api.example.com/x'));

    expect(response.statusCode, 404);
    final log = controller.logs.single;
    expect(log.statusCode, 404);
    expect(log.responseBody, {'error': 'nope'});
    expect(log.isFailed, isTrue);
  });

  test('logs connection errors with status 0 and rethrows them', () async {
    final client = DebugHttpClient(
      inner: MockClient((_) async => throw http.ClientException('No internet')),
    );

    await expectLater(
      client.get(Uri.parse('https://api.example.com/offline')),
      throwsA(isA<http.ClientException>()),
    );

    final log = controller.logs.single;
    expect(log.statusCode, 0);
    expect(log.errorMessage, '[ClientException] No internet');
    expect(log.isFailed, isTrue);
  });

  test('keeps plain text and summarizes binary responses', () async {
    await clientReturning(
            http.Response('pong', 200, headers: {'content-type': 'text/plain'}))
        .get(Uri.parse('https://api.example.com/ping'));
    expect(controller.logs.first.responseBody, 'pong');

    await clientReturning(http.Response.bytes([1, 2, 3], 200,
            headers: {'content-type': 'image/png'}))
        .get(Uri.parse('https://api.example.com/avatar.png'));
    expect(controller.logs.first.responseBody, '<binary 3 bytes>');
  });

  test('summarizes multipart requests', () async {
    final client = clientReturning(http.Response('', 204));
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.example.com/upload'),
    )
      ..fields['title'] = 'avatar'
      ..files
          .add(http.MultipartFile.fromBytes('file', [0, 1], filename: 'a.png'));

    await client.send(request).then((r) => r.stream.drain<void>());

    final log = controller.logs.single;
    expect(
        log.requestBody, {'title': 'avatar', 'file': '<file a.png (2 bytes)>'});
    expect(log.responseBody, isNull);
  });

  test('adds the log only after the body is read', () async {
    final client = clientReturning(http.Response('{"a":1}', 200,
        headers: {'content-type': 'application/json'}));

    final streamed =
        await client.send(http.Request('GET', Uri.parse('https://a.dev/b')));
    expect(controller.logs, isEmpty);

    await streamed.stream.bytesToString();
    expect(controller.logs.single.responseBody, {'a': 1});
  });
}
