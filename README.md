# TamrWaiter for iOS

Tamr's AI waiter inside a restaurant's iOS app. The waiter is Tamr's hosted page (`tamr.link/w/{restaurant}`)
in a `WKWebView`; this package shows it, keeps it on Tamr's origin, and talks to it over a typed bridge.
Everything the waiter decides (renewing the diner's session, retries, what goes in a cart) happens in the
page, so it improves without an app release.

- `TamrWaiterController`: one waiter for one diner. It loads ahead of the tap and stays loaded between opens.
- `TamrWaiterViewController` (UIKit): the waiter as a page sheet, a full page, or a screen of a navigation
  stack, with loading and retry states.
- `TamrWaiterView` (SwiftUI): the same, for `.sheet` and `.fullScreenCover`.

iOS 16 or later, Xcode 16 or later (Swift 6). No dependencies.

## Install

**Xcode:** File > Add Package Dependencies, paste `https://github.com/abiroot/tamr-waiter-ios`, set the
Dependency Rule to **Up to Next Major Version** from `1.0.0`, and add `TamrWaiter` to your app's target.

**Package.swift:**

```swift
.package(url: "https://github.com/abiroot/tamr-waiter-ios", from: "1.0.0"),
// and in your target's dependencies:
.product(name: "TamrWaiter", package: "tamr-waiter-ios"),
```

### You need a publishable key

Create one in the dashboard (Settings, App keys).

- **A key in guest mode** opens the chat for anyone: diners are guests.
- **A live key without guest mode** needs to know who the diner is: your backend signs a short diner token,
  and you hand it over with `setIdentityProvider` (below).

### Voice notes (optional)

Without this the waiter still works, by text. Add the microphone's purpose to your app's `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Talk to the waiter with your voice.</string>
```

Then answer `onMicrophonePermission` with the system's permission:

```swift
waiter.onMicrophonePermission = { await AVAudioApplication.requestRecordPermission() }   // iOS 17+
```

Only a microphone request from the waiter page reaches it. The SDK never asks for the camera: a camera
request is refused without asking your app, and WebKit's own permission prompt never shows.

## Open the waiter

Create one controller where the waiter is likely to be opened (the menu screen, not app start), preload it,
and show it on a tap:

```swift
import TamrWaiter

let waiter = try TamrWaiterController(
    appKey: "tamr_pk_live_…",
    restaurant: "cedar-house",
    locale: "ar"          // optional: branch, appearance, table, tableScan, mode, launch, debug, onLog
)
waiter.preload()

// Who the diner is, asked whenever the page needs a fresh token. Return nil for "no one".
waiter.setIdentityProvider { _ in
    guard let token = try await myBackend.tamrToken() else { return nil }   // your backend signs it
    return .token(token)
}

// Orders go to your own cart ("Orders go to: the app's cart"): answer each line.
waiter.onCartAdd { change in
    Reply(ok: true, lines: change.lines.map { LineAnswer(lineId: $0.lineId, ok: true) })
}

// Everything the page tells you.
waiter.on("payment.completed") { message in
    if let paid = message as? PaymentCompletedMessage { print("paid", paid.data.paymentId) }
}

// On a tap, UIKit:
present(TamrWaiterViewController(controller: waiter), animated: true)
// or SwiftUI:
.sheet(isPresented: $open) { TamrWaiterView(controller: waiter) }
```

Call `dispose()` when the diner signs out, and create a new controller for the next diner.

| Method | What it does |
| --- | --- |
| `preload()` | Load the chat hidden, so it opens at once. A hidden chat is released after 10 minutes and on a memory warning, and loads again when your app comes back. While hidden, its web view waits at zero size behind everything in your key window, with touches, VoiceOver and the status-bar tap off: iOS suspends a web view that is in no window |
| `reload()`, `dispose()` | Load again after a failure (`pageState == .failed`); stop for good |
| `setIdentityProvider(_:)` | Returns `.token(…)`, `.code(…)` or `nil`, within 15 seconds |
| `onCartAdd`, `onCartUpdate`, `onCartRemove` | Answer the waiter's cart proposals, per line, within 15 seconds |
| `on(_:_:)` | `ready`, `state`, `checkout`, `open_dish`, `order.placed`, `payment.completed`, `booking.made`, `booking.changed`, `waiter.called`, `close`, `log`… Returns the function that removes it |
| `setLocale`, `setAppearance`, `setText`, `setTheme`, `setContext`, `setStarters`, `setRestrictions` | Kept and sent again whenever the page loads again |
| `sendCart(_:)`, `sendMessage(_:)`, `newChat()`, `clearIdentity()` | One-off messages, held until the chat is ready |

These names are the SDKs' shared shape (the Web SDK's README sets it out). The page's messages are
protocols and the SDK's own kinds (`TamrPageState`, `TamrWaiterViewController.Presentation`) are structs,
not enums, so a new case never breaks your `switch`.

### A full page

`TamrWaiterViewController(controller: waiter, presentation: .fullScreen)` (or `TamrWaiterView(controller:
waiter, presentation: .fullScreen)` in a `.fullScreenCover`) covers the screen with no grabber. Create the
controller with `appearance: Appearance(showBack: .set(true))` so the page's back arrow closes it.

## Payments

With Tamr Pay on, the waiter can offer to take the bill. The provider's page opens in
`SFSafariViewController` over the chat, never inside the web view, and only when the link is https. When the
diner closes it, the waiter is told it's shown again and checks the payment.

## Debug mode

`debug: true` prints every message both ways, the page's loads and its own trace, as `[tamr] page <level>: …`
and `[tamr] shell: …`, to `onLog` or the system log (subsystem `link.tamr.waiter`), and makes the web view
inspectable in Safari's Web Inspector (iOS 16.4+). Tokens, codes and what the diner types are never logged.

## The example

`Example/TamrWaiterExample.xcodeproj` is a restaurant's menu screen that preloads the waiter, opens it as a
sheet and a full page, takes the cart lines and logs every event. It runs against the SDK test venue; for
another venue or a local server, set `TAMR_HOST`, `TAMR_RESTAURANT` and `TAMR_KEY` in the scheme's
environment (Edit Scheme > Run > Arguments).

`xcodebuild test -scheme TamrWaiter -destination 'platform=iOS Simulator,name=iPhone 17'` runs the package's
tests: every case of the shared `host_v1.json` and `debug_v1.json` fixtures, the bridge and the controller.
