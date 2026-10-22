import 'package:flutter_test/flutter_test.dart';
import 'package:qa_debug_overlay/qa_debug_overlay.dart';

void main() {
  late DebugOverlayController controller;

  setUp(() {
    controller = DebugOverlayController.instance;
    controller.reset();
  });

  group('DebugOverlayController', () {
    test('should be a singleton', () {
      final instance1 = DebugOverlayController.instance;
      final instance2 = DebugOverlayController.instance;
      expect(instance1, same(instance2));
    });

    test('should start with overlay visible', () {
      expect(controller.isOverlayVisible, isTrue);
    });

    test('should start with bottom sheet hidden', () {
      expect(controller.isBottomSheetVisible, isFalse);
    });

    test('should add logs', () {
      final log = NetworkLog.create(
        method: 'GET',
        endpoint: '/api/users',
        statusCode: 200,
      );

      controller.addLog(log);

      expect(controller.logs, hasLength(1));
      expect(controller.logs.first.endpoint, '/api/users');
    });

    test('should clear logs', () {
      final log = NetworkLog.create(
        method: 'GET',
        endpoint: '/api/users',
        statusCode: 200,
      );

      controller.addLog(log);
      expect(controller.logs, hasLength(1));

      controller.clearLogs();
      expect(controller.logs, isEmpty);
    });

    test('should show/hide bottom sheet', () {
      expect(controller.isBottomSheetVisible, isFalse);

      controller.showBottomSheet();
      expect(controller.isBottomSheetVisible, isTrue);

      controller.hideBottomSheet();
      expect(controller.isBottomSheetVisible, isFalse);
    });

    test('should limit logs to maxLogs', () {
      for (int i = 0; i < 150; i++) {
        controller.addLog(NetworkLog.create(
          method: 'GET',
          endpoint: '/api/test/$i',
          statusCode: 200,
        ));
      }

      expect(controller.logs.length, DebugOverlayController.maxLogs);
    });

    test('should keep newest logs first', () {
      controller.addLog(NetworkLog.create(
          method: 'GET', endpoint: '/first', statusCode: 200));
      controller.addLog(NetworkLog.create(
          method: 'GET', endpoint: '/second', statusCode: 200));

      expect(controller.logs.map((log) => log.endpoint), ['/second', '/first']);
    });

    test('should not allow modifying logs from outside', () {
      expect(
        () => controller.logs.add(
          NetworkLog.create(method: 'GET', endpoint: '/x', statusCode: 200),
        ),
        throwsUnsupportedError,
      );
    });

    test('hiding the overlay also hides the bottom sheet', () {
      controller.showBottomSheet();
      controller.setOverlayVisible(false);

      expect(controller.isOverlayVisible, isFalse);
      expect(controller.isBottomSheetVisible, isFalse);
    });

    test('should notify listeners on changes', () {
      var notified = false;
      void listener() => notified = true;
      controller.addListener(listener);
      addTearDown(() => controller.removeListener(listener));

      controller.addLog(NetworkLog.create(
        method: 'GET',
        endpoint: '/api/test',
        statusCode: 200,
      ));

      expect(notified, isTrue);
    });
  });

  group('NetworkLog', () {
    test('should identify success status codes', () {
      final log = NetworkLog.create(
        method: 'GET',
        endpoint: '/test',
        statusCode: 200,
      );
      expect(log.isSuccess, isTrue);
      expect(log.isClientError, isFalse);
      expect(log.isServerError, isFalse);
    });

    test('should identify client error status codes', () {
      final log = NetworkLog.create(
        method: 'GET',
        endpoint: '/test',
        statusCode: 404,
      );
      expect(log.isSuccess, isFalse);
      expect(log.isClientError, isTrue);
      expect(log.isServerError, isFalse);
    });

    test('should identify server error status codes', () {
      final log = NetworkLog.create(
        method: 'GET',
        endpoint: '/test',
        statusCode: 500,
      );
      expect(log.isSuccess, isFalse);
      expect(log.isClientError, isFalse);
      expect(log.isServerError, isTrue);
    });

    test('should give unique ids to logs created at the same time', () {
      final ids = {
        for (var i = 0; i < 50; i++)
          NetworkLog.create(method: 'GET', endpoint: '/t', statusCode: 200).id,
      };
      expect(ids, hasLength(50));
    });

    test('isFailed covers HTTP errors, no response and error messages', () {
      NetworkLog log(int status, [String? error]) => NetworkLog.create(
            method: 'GET',
            endpoint: '/t',
            statusCode: status,
            errorMessage: error,
          );

      expect(log(200).isFailed, isFalse);
      expect(log(302).isFailed, isFalse);
      expect(log(404).isFailed, isTrue);
      expect(log(503).isFailed, isTrue);
      expect(log(0).isFailed, isTrue);
      expect(log(200, 'parse error').isFailed, isTrue);
    });

    test('extracts the auth token from the Authorization header', () {
      NetworkLog withAuth(Map<String, dynamic>? headers) => NetworkLog.create(
            method: 'GET',
            endpoint: '/t',
            statusCode: 200,
            requestHeaders: headers,
          );

      expect(
          withAuth({'Authorization': 'Bearer abc.def'}).authToken, 'abc.def');
      expect(withAuth({'authorization': 'bearer xyz'}).authToken, 'xyz');
      expect(
          withAuth({'Authorization': 'Basic dXNlcg=='}).authToken, 'dXNlcg==');
      expect(withAuth({'Authorization': 'raw-token'}).authToken, 'raw-token');
      expect(
        withAuth({'Authorization': 'Bearer abc'}).authorizationHeader,
        'Bearer abc',
      );
      expect(withAuth({'Accept': '*/*'}).authToken, isNull);
      expect(withAuth(null).authToken, isNull);
    });
  });
}
