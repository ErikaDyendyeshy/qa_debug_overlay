# Changelog

All notable changes to this project will be documented in this file.

## [1.1.1] - 2026-10-22

Fixes found while testing on a real Android device.

### 🐛 Fixes
- Fixed the floating button's request counter, which was drawn with MaterialApp's
  red, underlined error text style.
- The floating button now follows fast drags. Before, some movement was lost
  and the button snapped to the wrong edge.
- Errors for 4xx/5xx responses are now short: `[badResponse] HTTP 404 Not Found`
  instead of Dio's long generic paragraph.
- The "copied" toast moved to the top so it doesn't overlap the clipboard preview
  on Android 13+.
- The floating button has an accessibility label ("Open network logs").
- A sharper demo GIF.

## [1.1.0] - 2026-10-22

### ✨ New
- **Copy actions** in request details: cURL, URL, Request, Response, Auth token
  (from the `Authorization` header, without `Bearer`) and a Markdown **Bug report**.
- Tap a header row to copy its value, or long-press any JSON node to copy it.
- **Search** by URL, method or status, plus `2xx` / `4xx` / `5xx` / **Failed** filters with counts.
- `NetworkLogFormatter`: a public API for cURL, request/response text and bug reports.
- `NetworkLog.isFailed`, `isRedirect`, `url`, `authorizationHeader` and `authToken`.
- `DebugOverlayWrapper(enabled: ...)` to turn the overlay off in release builds.
- `DebugInterceptor(controller: ...)` parameter.

### 🎨 Redesign
- A new dark UI that doesn't depend on the host app's theme: request cards, status
  pills, tabbed details (Overview, Request and Response) and a "copied" toast.
- The floating button shows the request count, turns red on failures and snaps to the screen edge.
- A rewritten JSON viewer: a proper collapsible tree (no more duplicated brackets)
  and a raw view with syntax highlighting that you can select.
- A new demo GIF and a pub.dev screenshot.

### 🐛 Fixes
- `DebugInterceptor` now records the error message for failed requests and status `0`
  for connection errors.
- `FormData` and binary (`ResponseType.bytes`) bodies are summarized instead of
  dumped. The `Content-Type` that Dio sends is shown.
- Log ids are unique even when requests finish within the same millisecond.
- `DebugOverlayController.logs` is now read-only from outside.
- The text field and tooltips work inside the overlay, which now has its own `Overlay`.

### 🔧 Maintenance
- Requires Dart `^3.6.0` and Flutter `>=3.27.0`. Upgraded to `flutter_lints` 6.
- Added tests for the interceptor, the formatter and the widgets (39 tests).
- Fixed a crash in the example app on short responses.

## [1.0.1] - 2025-01-28

### 🐛 Bug Fixes
- Fixed demo GIF path to display correctly on pub.dev

## [1.0.0] - 2025-10-28

### 🎉 Initial Release

**qa_debug_overlay** - A professional debug overlay widget for QA testing with comprehensive network logging capabilities.

#### ✨ Features
- **Network Logging**: Automatic capture of HTTP requests and responses
- **JSON Viewer**: Syntax-highlighted JSON display with expandable nodes
- **URL Components**: Separate display of domain, path, and query parameters
- **Timing Information**: Request duration and status code visualization
- **Dio Integration**: Built-in interceptor for Dio HTTP client
- **HTTP Package Support**: Helper methods for http package
- **Firebase Support**: Logging wrappers for Firebase Functions and Firestore


#### 🔧 Technical Details
- **Zero Dependencies**: No BLoC, get_it, or other complex dependencies
- **Lightweight**: Only 18KB compressed package size
- **QA-Friendly**: Designed specifically for quality assurance testing
- **Easy Integration**: Simple wrapper widget with minimal setup

