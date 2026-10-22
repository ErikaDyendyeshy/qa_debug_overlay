import 'package:flutter_test/flutter_test.dart';
import 'package:qa_debug_overlay/qa_debug_overlay.dart';

// Stand-ins for Firebase types. FirebaseLogger matches them by type name and
// reads their fields dynamically, so the real SDK isn't needed in tests.
class FakeHttpsCallableResult {
  FakeHttpsCallableResult(this.data);
  final dynamic data;
}

class FakeSnapshotMetadata {
  final bool hasPendingWrites = false;
  final bool isFromCache = true;
}

class FakeDocumentSnapshot {
  FakeDocumentSnapshot(this.id, this._data);
  final String id;
  final Map<String, dynamic>? _data;
  bool get exists => _data != null;
  Map<String, dynamic>? data() => _data;
  final metadata = FakeSnapshotMetadata();
}

class FakeQuerySnapshot {
  FakeQuerySnapshot(this.docs);
  final List<FakeDocumentSnapshot> docs;
  int get size => docs.length;
}

class FakeFirebaseException implements Exception {
  FakeFirebaseException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => '[cloud_firestore/$code] $message';
}

void main() {
  final controller = DebugOverlayController.instance;

  setUp(controller.reset);

  group('logCall', () {
    test('logs params and the callable result data', () async {
      final result = await FirebaseLogger.logCall(
        name: 'getUser',
        params: {'id': 7},
        call: () async => FakeHttpsCallableResult({'name': 'Ann'}),
      );

      expect(result.data, {'name': 'Ann'});
      final log = controller.logs.single;
      expect(log.method, 'FIREBASE');
      expect(log.endpoint, 'getUser');
      expect(log.statusCode, 200);
      expect(log.requestBody, {'id': 7});
      expect(log.responseBody, {'name': 'Ann'});
      expect(log.duration, isNotNull);
    });

    test('maps Firebase error codes to HTTP-like statuses and rethrows',
        () async {
      await expectLater(
        FirebaseLogger.logCall(
          name: 'deleteUser',
          call: () async =>
              throw FakeFirebaseException('permission-denied', 'Not allowed'),
        ),
        throwsA(isA<FakeFirebaseException>()),
      );

      final log = controller.logs.single;
      expect(log.statusCode, 403);
      expect(log.errorMessage, '[permission-denied] Not allowed');
      expect(log.isFailed, isTrue);
    });

    test('uses 500 and toString for errors without a code', () async {
      await expectLater(
        FirebaseLogger.logCall(
          name: 'broken',
          call: () async => throw StateError('boom'),
        ),
        throwsStateError,
      );

      final log = controller.logs.single;
      expect(log.statusCode, 500);
      expect(log.errorMessage, 'Bad state: boom');
    });
  });

  group('logRead', () {
    test('extracts document snapshots', () async {
      await FirebaseLogger.logRead(
        collection: 'users',
        docId: 'u1',
        read: () async => FakeDocumentSnapshot('u1', {'name': 'Ann'}),
      );

      final log = controller.logs.single;
      expect(log.method, 'FIRESTORE GET');
      expect(log.endpoint, 'users/u1');
      expect(log.responseBody, {
        'id': 'u1',
        'exists': true,
        'data': {'name': 'Ann'},
        'metadata': {'hasPendingWrites': false, 'isFromCache': true},
      });
    });

    test('extracts query snapshots', () async {
      await FirebaseLogger.logRead(
        collection: 'users',
        docId: null,
        read: () async => FakeQuerySnapshot([
          FakeDocumentSnapshot('u1', {'name': 'Ann'}),
          FakeDocumentSnapshot('u2', {'name': 'Bob'}),
        ]),
      );

      final log = controller.logs.single;
      expect(log.endpoint, 'users');
      expect(log.responseBody, {
        'docs': [
          {
            'id': 'u1',
            'data': {'name': 'Ann'}
          },
          {
            'id': 'u2',
            'data': {'name': 'Bob'}
          },
        ],
        'size': 2,
        'empty': false,
      });
    });

    test('logs not-found errors as 404', () async {
      await expectLater(
        FirebaseLogger.logRead(
          collection: 'users',
          docId: 'missing',
          read: () async => throw FakeFirebaseException('not-found', 'No doc'),
        ),
        throwsA(isA<FakeFirebaseException>()),
      );

      expect(controller.logs.single.statusCode, 404);
    });
  });

  group('logWrite', () {
    test('logs the written data', () async {
      await FirebaseLogger.logWrite(
        collection: 'users',
        docId: 'u1',
        data: {'name': 'Ann'},
        write: () async {},
      );

      final log = controller.logs.single;
      expect(log.method, 'FIRESTORE SET');
      expect(log.endpoint, 'users/u1');
      expect(log.statusCode, 200);
      expect(log.requestBody, {'name': 'Ann'});
    });

    test('logs unauthenticated errors as 401 and rethrows', () async {
      await expectLater(
        FirebaseLogger.logWrite(
          collection: 'users',
          docId: 'u1',
          data: {'name': 'Ann'},
          write: () async =>
              throw FakeFirebaseException('unauthenticated', 'Sign in first'),
        ),
        throwsA(isA<FakeFirebaseException>()),
      );

      final log = controller.logs.single;
      expect(log.statusCode, 401);
      expect(log.requestBody, {'name': 'Ann'});
      expect(log.errorMessage, '[unauthenticated] Sign in first');
    });
  });
}
