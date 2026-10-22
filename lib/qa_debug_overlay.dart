/// Flutter Debug Overlay - Simple QA Testing Tool
///
/// A lightweight debug overlay for Flutter with network logging and JSON viewer.
///
/// ## Quick Start
///
/// 1. Wrap your app:
/// ```dart
/// MaterialApp(
///   builder: (context, child) {
///     return DebugOverlayWrapper(child: child!);
///   },
/// );
/// ```
///
/// 2. Log your HTTP client:
/// ```dart
/// final dio = Dio()..interceptors.add(DebugInterceptor()); // Dio
/// final client = DebugHttpClient();                        // package:http
/// ```
///
/// That's it! Tap the 🐞 button to view logs, then copy cURL, request,
/// response or the auth token in one tap.
library;

// Core Controller
export 'src/controller/debug_overlay_controller.dart';

// Network Interceptors & Helpers
export 'src/interceptor/debug_interceptor.dart'; // For Dio automatic logging
export 'src/interceptor/debug_http_client.dart'; // For package:http automatic logging
export 'src/helpers/firebase_logger.dart'; // For Firebase
export 'src/helpers/network_log_formatter.dart'; // cURL, request/response text, bug report

// UI Widgets
export 'src/widgets/debug_overlay_wrapper.dart';
export 'src/widgets/draggable_debug_button.dart';
export 'src/widgets/debug_logs_bottom_sheet.dart';
export 'src/widgets/log_detail_view.dart';
