# 🐞 QA Debug Overlay

[![pub package](https://img.shields.io/pub/v/qa_debug_overlay.svg)](https://pub.dev/packages/qa_debug_overlay)
[![GitHub stars](https://img.shields.io/github/stars/ErikaDyendyeshy/qa_debug_overlay.svg)](https://github.com/ErikaDyendyeshy/qa_debug_overlay)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An in-app network inspector for Flutter, built for QA. See every request and response
right on the device, find failed calls in a second, and send developers exactly what
they need: **cURL, request, response, auth token or a full bug report — in one tap.**

![QA Debug Overlay demo](https://github.com/ErikaDyendyeshy/qa_debug_overlay/raw/v1.1.2/doc/demo.gif)

## ✨ Features

- **Floating debug button**: drag it anywhere and it snaps to the nearest edge. It shows the request count and turns red when something failed.
- **Network log**: method, path, host, status, duration and time on one card.
- **Search & filters**: search by URL, method or status. Filter by `2xx`, `4xx`, `5xx` or **Failed** (which includes network errors).
- **Request details** in three tabs (Overview, Request and Response) with headers as a table and bodies as a collapsible JSON tree or raw text you can select.
- **Copy actions** for QA ↔ dev communication:
  | Action | What you get |
  | --- | --- |
  | **cURL** | A ready-to-run command for backend devs |
  | **URL** | The full request URL |
  | **Request** | Method, URL, headers and body |
  | **Response** | Status, headers, body and the error, if any |
  | **Auth token** | The token from the `Authorization` header, without `Bearer` |
  | **Bug report** | Markdown for Jira, Slack or GitHub with cURL and both bodies |
- **Copy any detail**: tap a header row to copy its value, or long-press any JSON node.
- **Dio interceptor** with timings, errors, `FormData` and binary responses.
- **Firebase helpers** for Cloud Functions and Firestore.
- The overlay has its own dark theme, so it looks the same in any app and never inherits your app's styles.

## 📦 Installation

```yaml
dependencies:
  qa_debug_overlay: ^1.1.2
```

## 🚀 Quick start

**1. Wrap your app:**

```dart
MaterialApp(
  builder: (context, child) => DebugOverlayWrapper(child: child!),
  home: const HomePage(),
);
```

**2. Add the interceptor to Dio:**

```dart
final dio = Dio()..interceptors.add(DebugInterceptor());
```

That's it! Tap the 🐞 button to see the logs.

### Show it only in debug or QA builds

```dart
import 'package:flutter/foundation.dart';

MaterialApp(
  builder: (context, child) => DebugOverlayWrapper(
    enabled: kDebugMode, // or your own flavor flag
    child: child!,
  ),
);
```

## 🌐 Other HTTP clients

### Firebase

```dart
final result = await FirebaseLogger.logCall(
  name: 'getUserData',
  params: params,
  call: () => FirebaseFunctions.instance.httpsCallable('getUserData').call(params),
);

final doc = await FirebaseLogger.logRead(
  collection: 'users',
  docId: 'user123',
  read: () => FirebaseFirestore.instance.collection('users').doc('user123').get(),
);
```

### `http` or any other client

```dart
final stopwatch = Stopwatch()..start();
final response = await http.get(uri, headers: headers);

DebugOverlayController.instance.addLog(
  NetworkLog.create(
    method: 'GET',
    endpoint: uri.toString(),
    fullUrl: uri.toString(),
    domain: '${uri.scheme}://${uri.host}',
    path: uri.path,
    statusCode: response.statusCode,
    duration: stopwatch.elapsed,
    requestHeaders: headers,
    responseHeaders: response.headers,
    responseBody: response.body, // JSON strings are parsed automatically
  ),
);
```

## 📋 Formatting logs in code

`NetworkLogFormatter` is the same formatter the copy buttons use. You can call it yourself,
for example to attach the last failed request to a crash report:

```dart
final failed = DebugOverlayController.instance.logs.firstWhere((log) => log.isFailed);

NetworkLogFormatter.toCurl(failed);       // curl -X POST 'https://…' -H '…' --data-raw '…'
NetworkLogFormatter.requestText(failed);  // method, URL, headers and body
NetworkLogFormatter.responseText(failed); // status, headers, body and error
NetworkLogFormatter.bugReport(failed);    // Markdown report
failed.authToken;                         // token from the Authorization header
```

## 🔧 Controller

```dart
final controller = DebugOverlayController.instance;

controller.setOverlayVisible(false); // hide the button
controller.showBottomSheet();        // open the logs
controller.hideBottomSheet();
controller.clearLogs();
controller.addListener(() => print('Logs: ${controller.logs.length}'));
```

The controller keeps the latest `DebugOverlayController.maxLogs` (100) requests.

## 🐛 Troubleshooting

**The button doesn't appear.** Make sure `DebugOverlayWrapper` is used in the
`MaterialApp.builder` (not in `home`), then do a hot restart.

**The logs are empty.** Make sure `DebugInterceptor()` is added to the same `Dio`
instance that makes the calls.

> ⚠️ The overlay shows tokens and request bodies in plain text. Ship it only in
> debug or QA builds.

## 🤝 Contributing

Issues and PRs are welcome. To run the tests:

```bash
flutter test
```

To re-render the demo GIF after changing the UI:

```bash
flutter test tool/demo/record_demo_test.dart && tool/demo/encode.sh
```

## 📝 License

MIT License. See the [LICENSE](LICENSE) file.

Created by [Erika](https://github.com/ErikaDyendyeshy). QA meets Flutter magic 💚
