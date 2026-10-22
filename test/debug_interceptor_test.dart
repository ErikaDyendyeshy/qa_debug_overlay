import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qa_debug_overlay/qa_debug_overlay.dart';

/// Returns canned responses (or throws) without touching the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  final controller = DebugOverlayController.instance;
  late Dio dio;

  setUp(() {
    controller.reset();
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'))
      ..interceptors.add(DebugInterceptor());
  });

  test('logs successful responses with url parts, headers and bodies',
      () async {
    dio.httpClientAdapter = _FakeAdapter((_) => _json({'id': 1}, 200));

    await dio.post(
      '/users',
      queryParameters: {'page': '2'},
      data: {'name': 'Ann'},
      options: Options(headers: {'Authorization': 'Bearer secret'}),
    );

    expect(controller.logs, hasLength(1));
    final log = controller.logs.single;
    expect(log.method, 'POST');
    expect(log.statusCode, 200);
    expect(log.domain, 'https://api.example.com');
    expect(log.path, '/users');
    expect(log.queryParams, {'page': '2'});
    expect(log.requestBody, {'name': 'Ann'});
    expect(log.responseBody, {'id': 1});
    expect(log.responseHeaders?[Headers.contentTypeHeader],
        Headers.jsonContentType);
    expect(log.authToken, 'secret');
    expect(log.duration, isNotNull);
    expect(log.errorMessage, isNull);
  });

  test('logs HTTP errors with status code and error message', () async {
    dio.httpClientAdapter = _FakeAdapter((_) => _json({'error': 'nope'}, 404));

    await expectLater(dio.get('/missing'), throwsA(isA<DioException>()));

    final log = controller.logs.single;
    expect(log.statusCode, 404);
    expect(log.responseBody, {'error': 'nope'});
    expect(log.errorMessage, startsWith('[badResponse]'));
    expect(log.isFailed, isTrue);
  });

  test('logs connection errors with status 0', () async {
    dio.httpClientAdapter = _FakeAdapter(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'No internet',
      ),
    );

    await expectLater(dio.get('/offline'), throwsA(isA<DioException>()));

    final log = controller.logs.single;
    expect(log.statusCode, 0);
    expect(log.responseBody, isNull);
    expect(log.errorMessage, contains('connectionError'));
    expect(log.isFailed, isTrue);
  });

  test('summarizes form data and binary responses', () async {
    dio.httpClientAdapter = _FakeAdapter(
      (_) => ResponseBody.fromBytes([1, 2, 3], 200),
    );

    await dio.post(
      '/upload',
      data: FormData.fromMap({
        'title': 'avatar',
        'file': MultipartFile.fromBytes([0, 1], filename: 'a.png'),
      }),
      options: Options(responseType: ResponseType.bytes),
    );

    final log = controller.logs.single;
    expect(
        log.requestBody, {'title': 'avatar', 'file': '<file a.png (2 bytes)>'});
    expect(log.responseBody, '<binary 3 bytes>');
  });
}
