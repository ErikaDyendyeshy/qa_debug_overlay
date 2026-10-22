import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qa_debug_overlay/qa_debug_overlay.dart';

void main() {
  final controller = DebugOverlayController.instance;
  String? clipboard;

  setUp(() {
    controller.reset();
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => DebugOverlayWrapper(child: child!),
      home: const Scaffold(body: Center(child: Text('Host app'))),
    ));
  }

  NetworkLog log({
    String method = 'GET',
    String path = '/users',
    int status = 200,
    Map<String, dynamic>? headers,
    dynamic responseBody,
  }) {
    final url = 'https://api.example.com$path';
    return NetworkLog.create(
      method: method,
      endpoint: url,
      fullUrl: url,
      domain: 'https://api.example.com',
      path: path,
      statusCode: status,
      duration: const Duration(milliseconds: 120),
      requestHeaders: headers,
      responseBody: responseBody,
    );
  }

  Finder copyAction(String label) =>
      find.descendant(of: find.byType(Wrap), matching: find.text(label));

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.bug_report_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('button shows the log count and opens the sheet', (tester) async {
    await pumpApp(tester);
    controller.addLog(log());
    controller.addLog(log(path: '/orders'));
    await tester.pump();

    expect(find.text('2'), findsOneWidget);

    await openSheet(tester);

    expect(controller.isBottomSheetVisible, isTrue);
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('/users'), findsOneWidget);
    expect(find.text('/orders'), findsOneWidget);
  });

  testWidgets('shows an empty state without logs', (tester) async {
    await pumpApp(tester);
    await openSheet(tester);

    expect(find.text('Waiting for requests…'), findsOneWidget);
  });

  testWidgets('filters by status and searches by url', (tester) async {
    await pumpApp(tester);
    controller.addLog(log(path: '/ok'));
    controller.addLog(log(path: '/missing', status: 404));
    controller.addLog(log(path: '/crash', status: 500));
    await openSheet(tester);

    await tester.tap(find.text('4xx'));
    await tester.pumpAndSettle();
    expect(find.text('/missing'), findsOneWidget);
    expect(find.text('/ok'), findsNothing);
    expect(find.text('/crash'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField), 'cra');
    await tester.pumpAndSettle();
    expect(find.text('/crash'), findsOneWidget);
    expect(find.text('/ok'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing-matches');
    await tester.pumpAndSettle();
    expect(find.text('No requests match the filter'), findsOneWidget);
  });

  testWidgets('detail view copies cURL, response and auth token',
      (tester) async {
    await pumpApp(tester);
    controller.addLog(log(
      headers: {'Authorization': 'Bearer token-123'},
      responseBody: {'id': 7},
    ));
    await openSheet(tester);

    await tester.tap(find.text('/users'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);

    await tester.tap(find.text('cURL'));
    await tester.pump();
    expect(
        clipboard, startsWith("curl -X GET 'https://api.example.com/users'"));
    expect(clipboard, contains("-H 'Authorization: Bearer token-123'"));
    expect(find.text('cURL copied'), findsOneWidget);

    await tester.tap(copyAction('Response'));
    await tester.pump();
    expect(clipboard, startsWith('200 Success'));
    expect(clipboard, contains('"id": 7'));

    await tester.tap(find.text('Auth token'));
    await tester.pump();
    expect(clipboard, 'token-123');

    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  testWidgets('auth token action is disabled without Authorization header',
      (tester) async {
    await pumpApp(tester);
    controller.addLog(log());
    await openSheet(tester);
    await tester.tap(find.text('/users'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Auth token'));
    await tester.pump();
    expect(clipboard, isNull);
  });

  testWidgets('response tab shows the body and back returns to the list',
      (tester) async {
    await pumpApp(tester);
    controller.addLog(log(responseBody: {
      'name': 'Ann',
      'tags': ['qa']
    }));
    await openSheet(tester);
    await tester.tap(find.text('/users'));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byWidgetPredicate((w) => w is SegmentedButton),
      matching: find.text('Response'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('"name"', findRichText: true), findsOneWidget);
    expect(find.textContaining('"Ann"', findRichText: true), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Network'), findsOneWidget);
  });

  testWidgets('tapping the scrim and close button hide the sheet',
      (tester) async {
    await pumpApp(tester);
    await openSheet(tester);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(controller.isBottomSheetVisible, isFalse);

    await openSheet(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(controller.isBottomSheetVisible, isFalse);
  });

  testWidgets('clear button removes all logs', (tester) async {
    await pumpApp(tester);
    controller.addLog(log());
    await openSheet(tester);

    await tester.tap(find.byTooltip('Clear logs'));
    await tester.pumpAndSettle();

    expect(controller.logs, isEmpty);
    expect(find.text('Waiting for requests…'), findsOneWidget);
  });

  testWidgets('disabled wrapper renders only the child', (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) =>
          DebugOverlayWrapper(enabled: false, child: child!),
      home: const Text('Host app'),
    ));

    expect(find.byIcon(Icons.bug_report_rounded), findsNothing);
  });
}
