// Renders the README demo frame by frame (no simulator or screen recording).
//
//   flutter test tool/demo/record_demo_test.dart
//   tool/demo/encode.sh
//
// Frames go to build/demo_frames, the encoder turns them into doc/demo.gif,
// doc/demo.mp4 and doc/screenshots/preview.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qa_debug_overlay/qa_debug_overlay.dart';

const _canvasSize = Size(1040, 940);
const _phoneSize = Size(390, 844);
const _fps = 25;
const _pixelRatio = 2.0;

const _bg = Color(0xFF0B0D11);
const _accent = Color(0xFF99BC33);
const _text = Color(0xFFE8EAF0);
const _muted = Color(0xFF8B93A7);

const _steps = [
  ('Capture', 'Dio and http requests are logged automatically'),
  ('Filter', 'Spot failed calls with 2xx / 4xx / 5xx filters'),
  ('Inspect', 'Headers, body and errors in a readable JSON tree'),
  ('Copy cURL', 'Hand the backend a ready-to-run command'),
  ('Copy anything', 'Response, request, auth token or a full bug report'),
];

final _step = ValueNotifier<int>(-1);
final _touch = ValueNotifier<Offset?>(null);
final _boundaryKey = GlobalKey();

void main() {
  setUpAll(_loadFonts);

  testWidgets('record demo', (tester) async {
    tester.view.physicalSize = _canvasSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);

    final out = Directory('build/demo_frames');
    if (out.existsSync()) out.deleteSync(recursive: true);
    out.createSync(recursive: true);

    DebugOverlayController.instance.reset();
    await tester.pumpWidget(const _DemoCanvas());

    final recorder = _Recorder(tester, out);

    await recorder.hold(1.0);

    // 1. Capture
    _step.value = 0;
    await recorder.hold(0.8);
    await recorder.tap(find.text('Sign in'));
    await recorder.hold(0.3);
    DebugOverlayController.instance.addLog(_SampleLogs.login());
    await recorder.hold(0.7);
    await recorder.tap(find.text('Load products'));
    await recorder.hold(0.3);
    DebugOverlayController.instance.addLog(_SampleLogs.products());
    await recorder.hold(0.2);
    DebugOverlayController.instance.addLog(_SampleLogs.recommendations());
    await recorder.hold(0.7);
    await recorder.tap(find.text('Checkout'));
    await recorder.hold(0.3);
    DebugOverlayController.instance.addLog(_SampleLogs.cart());
    await recorder.hold(0.2);
    DebugOverlayController.instance.addLog(_SampleLogs.checkout());
    await recorder.hold(1.0);

    await recorder.tap(find.byType(DraggableDebugButton));
    await recorder.hold(1.6);

    // 2. Filter
    _step.value = 1;
    await recorder.hold(0.6);
    await recorder.tap(find.text('Failed'));
    await recorder.hold(1.6);

    // 3. Inspect
    _step.value = 2;
    await recorder.tap(find.text('/v1/checkout'));
    await recorder.hold(1.8);
    await recorder.tap(_tab('Response'));
    await recorder.hold(2.2);

    // 4. Copy cURL
    _step.value = 3;
    await recorder.hold(0.5);
    await recorder.tap(_chip('cURL'));
    await recorder.hold(1.6, snapshotAs: 'preview');

    // 5. Copy anything
    _step.value = 4;
    await recorder.tap(_chip('Response'));
    await recorder.hold(1.3);
    await recorder.tap(find.byTooltip('Back'));
    await recorder.hold(0.6);
    await recorder.tap(find.text('All'));
    await recorder.hold(0.6);
    await recorder.tap(find.text('/v1/products'));
    await recorder.hold(1.0);
    await recorder.tap(_chip('Auth token'));
    await recorder.hold(1.3);
    await recorder.tap(_chip('Bug report'));
    await recorder.hold(1.8);

    await recorder.tap(find.byTooltip('Back'));
    await recorder.hold(0.5);
    await recorder.tap(find.byTooltip('Close'));
    await recorder.hold(1.2);

    debugPrint('Recorded ${recorder.frame} frames to ${out.path}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Finder _chip(String label) =>
    find.descendant(of: find.byType(Wrap), matching: find.text(label));

Finder _tab(String label) => find.descendant(
      of: find.byWidgetPredicate((w) => w is SegmentedButton),
      matching: find.text(label),
    );

class _Recorder {
  _Recorder(this.tester, this.out);

  final WidgetTester tester;
  final Directory out;
  int frame = 0;

  Future<void> hold(double seconds, {String? snapshotAs}) async {
    final count = (seconds * _fps).round();
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 1000 ~/ _fps));
      await _capture(i == count ~/ 2 ? snapshotAs : null);
    }
  }

  /// Shows a touch indicator, taps and keeps recording while it fades.
  Future<void> tap(Finder finder) async {
    final target = tester.getCenter(finder);
    _touch.value = target;
    await hold(0.25);
    await tester.tap(finder);
    await hold(0.2);
    _touch.value = null;
  }

  Future<void> _capture(String? snapshotAs) async {
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: _pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final png = bytes!.buffer.asUint8List();
      final name = 'frame_${frame.toString().padLeft(5, '0')}.png';
      File('${out.path}/$name').writeAsBytesSync(png);
      if (snapshotAs != null) {
        File('${out.path}/$snapshotAs.png').writeAsBytesSync(png);
      }
    });
    frame++;
  }
}

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
  final materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader
          .addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
    await loader.load();
  }

  await load('Roboto', [
    for (final w in ['Regular', 'Medium', 'Bold', 'Black'])
      '$materialFonts/Roboto-$w.ttf',
  ]);
  await load('MaterialIcons', ['$materialFonts/MaterialIcons-Regular.otf']);
  await load('Menlo', ['/System/Library/Fonts/Menlo.ttc']);
}

// ---------------------------------------------------------------------------
// Presentation canvas
// ---------------------------------------------------------------------------

class _DemoCanvas extends StatelessWidget {
  const _DemoCanvas();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      home: RepaintBoundary(
        key: _boundaryKey,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.55, -0.2),
                radius: 1.1,
                colors: [Color(0xFF1B2412), _bg],
              ),
            ),
            child: Stack(
              children: [
                const Positioned(
                  left: 64,
                  top: 0,
                  bottom: 0,
                  width: 500,
                  child: _Captions(),
                ),
                Positioned(
                  right: 56,
                  top: (_canvasSize.height - _phoneSize.height - 24) / 2,
                  child: const _PhoneFrame(child: _HostApp()),
                ),
                const Positioned.fill(
                    child: IgnorePointer(child: _TouchIndicator())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Captions extends StatelessWidget {
  const _Captions();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _bg,
                shape: BoxShape.circle,
                border: Border.all(color: _accent, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withValues(alpha: 0.4), blurRadius: 20),
                ],
              ),
              child: const Icon(Icons.bug_report_rounded,
                  color: _accent, size: 28),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: _accent.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Dio · http · Firebase',
                style: TextStyle(
                    color: _accent, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Text(
          'QA Debug Overlay',
          style: TextStyle(
            color: _text,
            fontSize: 46,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'An in-app network inspector that lets QA talk\nto backend and frontend in the same language.',
          style: TextStyle(color: _muted, fontSize: 18, height: 1.45),
        ),
        const SizedBox(height: 40),
        ValueListenableBuilder<int>(
          valueListenable: _step,
          builder: (context, current, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < _steps.length; i++)
                _StepRow(
                  index: i,
                  title: _steps[i].$1,
                  subtitle: _steps[i].$2,
                  state: i < current
                      ? _StepState.done
                      : i == current
                          ? _StepState.active
                          : _StepState.upcoming,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _StepState { done, active, upcoming }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final int index;
  final String title;
  final String subtitle;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final active = state == _StepState.active;
    final done = state == _StepState.done;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:
            active ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? _accent.withValues(alpha: 0.5) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || done ? _accent : Colors.transparent,
              border: Border.all(
                  color: active || done ? _accent : const Color(0xFF3A4150)),
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 18, color: _bg)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: active ? _bg : _muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: state == _StepState.upcoming ? 0.45 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: _muted, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TouchIndicator extends StatelessWidget {
  const _TouchIndicator();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Offset?>(
      valueListenable: _touch,
      builder: (context, offset, _) {
        if (offset == null) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned(
              left: offset.dx - 22,
              top: offset.dy - 22,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.28),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.8), width: 2),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF050608),
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: const Color(0xFF2C313B), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _accent.withValues(alpha: 0.12),
              blurRadius: 80,
              spreadRadius: 4),
          const BoxShadow(
              color: Colors.black54, blurRadius: 40, offset: Offset(0, 24)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(48),
        child: SizedBox.fromSize(
          size: _phoneSize,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              const Positioned(top: 0, left: 0, right: 0, child: _StatusBar()),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const Positioned(
            left: 46,
            child: Text(
              '9:41',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black),
            ),
          ),
          const Positioned(
            right: 32,
            child: Row(
              children: [
                Icon(Icons.signal_cellular_alt_rounded,
                    size: 17, color: Colors.black),
                SizedBox(width: 4),
                Icon(Icons.wifi_rounded, size: 17, color: Colors.black),
                SizedBox(width: 4),
                Icon(Icons.battery_full_rounded, size: 18, color: Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fake host app
// ---------------------------------------------------------------------------

class _HostApp extends StatelessWidget {
  const _HostApp();

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3D5AFE);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      builder: (context, child) => MediaQuery(
        data: const MediaQueryData(
          size: _phoneSize,
          padding: EdgeInsets.only(top: 54, bottom: 34),
          viewPadding: EdgeInsets.only(top: 54, bottom: 34),
        ),
        child: DebugOverlayWrapper(child: child!),
      ),
      home: const _StoreScreen(),
    );
  }
}

class _StoreScreen extends StatelessWidget {
  const _StoreScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good morning,',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 14)),
                    const Text(
                      'Nova Store',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const Spacer(),
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.person_rounded, color: scheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 150,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3D5AFE), Color(0xFF7C4DFF)],
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Autumn sale',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Text(
                    'Up to 40% off',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: const [
                _Product(Icons.headphones_rounded, 'Headphones', '\$129',
                    Color(0xFFFFE0B2)),
                _Product(Icons.watch_rounded, 'Smart watch', '\$249',
                    Color(0xFFC8E6C9)),
                _Product(Icons.camera_alt_rounded, 'Camera', '\$599',
                    Color(0xFFBBDEFB)),
                _Product(Icons.speaker_rounded, 'Speaker', '\$89',
                    Color(0xFFF8BBD0)),
              ],
            ),
            const SizedBox(height: 20),
            _ActionButton(
                label: 'Sign in', icon: Icons.login_rounded, filled: false),
            const SizedBox(height: 10),
            _ActionButton(
                label: 'Load products',
                icon: Icons.refresh_rounded,
                filled: false),
            const SizedBox(height: 10),
            _ActionButton(
                label: 'Checkout',
                icon: Icons.shopping_bag_rounded,
                filled: true),
          ],
        ),
      ),
    );
  }
}

class _Product extends StatelessWidget {
  const _Product(this.icon, this.name, this.price, this.color);

  final IconData icon;
  final String name;
  final String price;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: Colors.black87),
          ),
          const Spacer(),
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text(price, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.label, required this.icon, required this.filled});

  final String label;
  final IconData icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(label)],
    );
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
      textStyle: WidgetStatePropertyAll(TextStyle(
          fontFamily: 'Roboto', fontSize: 15, fontWeight: FontWeight.w600)),
    );
    return filled
        ? FilledButton(onPressed: () {}, style: style, child: child)
        : OutlinedButton(onPressed: () {}, style: style, child: child);
  }
}

// ---------------------------------------------------------------------------
// Sample traffic
// ---------------------------------------------------------------------------

abstract final class _SampleLogs {
  static const _host = 'https://api.novastore.dev';
  static const _token =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1XzgyMSIsInJvbGUiOiJxYSJ9.4pQe1x';

  static Map<String, dynamic> _headers({bool auth = true, bool json = false}) =>
      {
        if (auth) 'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        'X-App-Version': '3.8.1 (412)',
      };

  static NetworkLog _log(
    String method,
    String path, {
    Map<String, dynamic>? query,
    required int status,
    required int ms,
    Map<String, dynamic>? headers,
    dynamic body,
    dynamic response,
    String? error,
  }) {
    final uri = Uri.parse('$_host$path').replace(queryParameters: query);
    return NetworkLog.create(
      method: method,
      endpoint: uri.toString(),
      fullUrl: uri.toString(),
      domain: _host,
      path: path,
      queryParams: query,
      statusCode: status,
      duration: Duration(milliseconds: ms),
      requestHeaders: headers,
      requestBody: body,
      responseHeaders: {
        'content-type': 'application/json; charset=utf-8',
        'x-request-id': 'req_7f3a91c2',
        'server': 'nginx',
      },
      responseBody: response,
      errorMessage: error,
    );
  }

  static NetworkLog login() => _log(
        'POST',
        '/v1/auth/login',
        status: 200,
        ms: 312,
        headers: _headers(auth: false, json: true),
        body: {'email': 'qa@novastore.dev', 'password': '••••••••'},
        response: {
          'access_token': _token,
          'token_type': 'Bearer',
          'expires_in': 3600,
          'user': {'id': 'u_821', 'name': 'QA Tester', 'role': 'qa'},
        },
      );

  static NetworkLog products() => _log(
        'GET',
        '/v1/products',
        query: {'page': '1', 'limit': '20'},
        status: 200,
        ms: 184,
        headers: _headers(),
        response: {
          'items': [
            {'id': 42, 'name': 'Headphones', 'price': 129.0, 'in_stock': true},
            {
              'id': 43,
              'name': 'Smart watch',
              'price': 249.0,
              'in_stock': false
            },
          ],
          'total': 2,
          'next_page': null,
        },
      );

  static NetworkLog recommendations() => _log(
        'GET',
        '/v1/recommendations',
        status: 500,
        ms: 1240,
        headers: _headers(),
        response: {'error': 'INTERNAL', 'trace_id': 'a91c-77de'},
        error: '[badResponse] HTTP 500 Internal Server Error',
      );

  static NetworkLog cart() => _log(
        'PUT',
        '/v1/cart/items/42',
        status: 200,
        ms: 96,
        headers: _headers(json: true),
        body: {'quantity': 1},
        response: {'cart_id': 'c_19', 'items': 1, 'total': 129.0},
      );

  static NetworkLog checkout() => _log(
        'POST',
        '/v1/checkout',
        status: 422,
        ms: 642,
        headers: _headers(json: true),
        body: {
          'cart_id': 'c_19',
          'payment': {'method': 'card', 'last4': '4242', 'exp': '09/26'},
        },
        response: {
          'error': 'VALIDATION_ERROR',
          'message': 'Card has expired',
          'fields': {'payment.exp': 'must be in the future'},
        },
        error: '[badResponse] HTTP 422 Unprocessable Entity',
      );
}
