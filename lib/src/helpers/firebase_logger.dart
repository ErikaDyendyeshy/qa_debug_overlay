import '../controller/debug_overlay_controller.dart';

/// Helper class for logging Firebase requests and operations.
///
/// This class provides convenient wrappers for Firebase Functions and Firestore
/// operations with automatic logging to the debug overlay. It captures timing
/// information, request/response data, and error details.
///
/// ## Usage
///
/// ```dart
/// // Firebase Functions
/// final result = await FirebaseLogger.logCall(
///   name: 'getUserData',
///   call: () => FirebaseFunctions.instance.httpsCallable('getUserData').call(params),
///   params: params,
/// );
///
/// // Firestore read
/// final doc = await FirebaseLogger.logRead(
///   collection: 'users',
///   docId: 'user123',
///   read: () => FirebaseFirestore.instance.collection('users').doc('user123').get(),
/// );
///
/// // Firestore write
/// await FirebaseLogger.logWrite(
///   collection: 'users',
///   docId: 'user123',
///   data: userData,
///   write: () => FirebaseFirestore.instance.collection('users').doc('user123').set(userData),
/// );
/// ```
class FirebaseLogger {
  /// Wrapper for Firebase Functions calls with automatic logging.
  ///
  /// Executes the provided Firebase function call and logs the request,
  /// response, timing, and any errors to the debug overlay.
  static Future<T> logCall<T>({
    required String name,
    required Future<T> Function() call,
    dynamic params,
  }) async {
    final startTime = DateTime.now();

    try {
      final result = await call();
      final duration = DateTime.now().difference(startTime);

      // Log successful call
      final log = NetworkLog.create(
        method: 'FIREBASE',
        endpoint: name,
        statusCode: 200,
        duration: duration,
        requestBody: params,
        responseBody: _extractFirebaseData(result),
      );

      DebugOverlayController.instance.addLog(log);

      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      // Log error
      final log = NetworkLog.create(
        method: 'FIREBASE',
        endpoint: name,
        statusCode: 500,
        duration: duration,
        requestBody: params,
        errorMessage: e.toString(),
      );

      DebugOverlayController.instance.addLog(log);

      rethrow;
    }
  }

  /// Wrapper for Firestore read operations with automatic logging.
  ///
  /// Executes the provided Firestore read operation and logs the request,
  /// response, timing, and any errors to the debug overlay.
  static Future<T> logRead<T>({
    required String collection,
    required String? docId,
    required Future<T> Function() read,
  }) async {
    final startTime = DateTime.now();
    final path = docId != null ? '$collection/$docId' : collection;

    try {
      final result = await read();
      final duration = DateTime.now().difference(startTime);

      final log = NetworkLog.create(
        method: 'FIRESTORE GET',
        endpoint: path,
        statusCode: 200,
        duration: duration,
        responseBody: _extractFirebaseData(result),
      );

      DebugOverlayController.instance.addLog(log);

      return result;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      final log = NetworkLog.create(
        method: 'FIRESTORE GET',
        endpoint: path,
        statusCode: 500,
        duration: duration,
        errorMessage: e.toString(),
      );

      DebugOverlayController.instance.addLog(log);

      rethrow;
    }
  }

  /// Wrapper for Firestore write operations with automatic logging.
  ///
  /// Executes the provided Firestore write operation and logs the request,
  /// timing, and any errors to the debug overlay.
  static Future<void> logWrite({
    required String collection,
    required String? docId,
    required dynamic data,
    required Future<void> Function() write,
  }) async {
    final startTime = DateTime.now();
    final path = docId != null ? '$collection/$docId' : collection;

    try {
      await write();
      final duration = DateTime.now().difference(startTime);

      final log = NetworkLog.create(
        method: 'FIRESTORE SET',
        endpoint: path,
        statusCode: 200,
        duration: duration,
        requestBody: data,
      );

      DebugOverlayController.instance.addLog(log);
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      final log = NetworkLog.create(
        method: 'FIRESTORE SET',
        endpoint: path,
        statusCode: 500,
        duration: duration,
        requestBody: data,
        errorMessage: e.toString(),
      );

      DebugOverlayController.instance.addLog(log);

      rethrow;
    }
  }

  /// Extracts meaningful data from Firebase objects for logging purposes.
  ///
  /// This method handles various Firebase object types and extracts
  /// relevant information for display in the debug overlay.
  static dynamic _extractFirebaseData(dynamic data) {
    if (data == null) return null;

    // DocumentSnapshot
    if (data.runtimeType.toString().contains('DocumentSnapshot')) {
      try {
        final snapshot = data as dynamic;
        return {
          'id': snapshot.id,
          'exists': snapshot.exists,
          'data': snapshot.data(),
          'metadata': {
            'hasPendingWrites': snapshot.metadata.hasPendingWrites,
            'isFromCache': snapshot.metadata.isFromCache,
          }
        };
      } catch (e) {
        return 'Error extracting DocumentSnapshot: $e';
      }
    }

    // QuerySnapshot
    if (data.runtimeType.toString().contains('QuerySnapshot')) {
      try {
        final snapshot = data as dynamic;
        return {
          'docs': snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'data': doc.data(),
                  })
              .toList(),
          'size': snapshot.size,
          'empty': snapshot.docs.isEmpty,
        };
      } catch (e) {
        return 'Error extracting QuerySnapshot: $e';
      }
    }

    // HttpsCallableResult
    if (data.runtimeType.toString().contains('HttpsCallableResult')) {
      try {
        final result = data as dynamic;
        return result.data;
      } catch (e) {
        return 'Error extracting HttpsCallableResult: $e';
      }
    }

    // Regular data
    return data;
  }
}
