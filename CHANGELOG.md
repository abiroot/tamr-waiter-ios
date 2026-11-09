# Changelog

## 1.0.0

The iOS SDK (#446). iOS 16 or later, Xcode 16 or later (Swift 6), no dependencies. Installs with Swift
Package Manager from `https://github.com/abiroot/tamr-waiter-ios`.

- `TamrWaiterController`: Tamr's hosted waiter page in a `WKWebView`, with the Web SDK's names. Preloaded
  and kept warm between opens; a hidden chat is released after 10 minutes and on a memory warning, and loads
  again when the app comes back. A hidden chat waits parked at zero size in the app's key window, so iOS
  doesn't suspend its page (a web view in no window is suspended on an iPhone, #446).
- `TamrWaiterViewController` (a page sheet, a full page or a screen of a navigation stack) and
  `TamrWaiterView` (SwiftUI), closed by the page's `close`.
- The bridge (ADR 0005, 0006): `TamrBridge` in the page's world before the first load, messages taken only
  from the main frame on Tamr's origin, replies with `callAsyncJavaScript(arguments:)`; `host.hello` and
  `ready`, `host.hello` again on a `ready` that isn't its reply, messages held until `ready` (kept across a
  reload and a release), what the app set sent again after every `ready`, each message taken once.
- The page's requests answered within 15 seconds: `identity.request` (`setIdentityProvider`), the cart
  (`onCartAdd`, `onCartUpdate`, `onCartRemove`), and `payment.open`, opened in `SFSafariViewController` only
  when https. The page is told again that it's shown when the diner closes it and when the app comes back,
  so it reads a payment's status.
- `on(_:_:)` for every page event; the setters for locale, appearance, text, theme, context, starters and
  restrictions.
- The microphone only through `onMicrophonePermission`, for Tamr's page alone; never the camera.
- Debug mode: `[tamr] page …` and `[tamr] shell: …` lines to `onLog` or the system log, and the web view
  inspectable.
