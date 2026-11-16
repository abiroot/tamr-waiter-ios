# Changelog

## 1.1.0

- Post-meal reviews (#453): `requestReview(orderId:dishes:)` asks the diner, after an order is served, to rate each of its
  dishes (1 to 5 stars), held until the chat is ready like `sendCart`. The order must be one your backend
  sent (`POST /api/v1/sdk/orders`) for this diner. The chat opens its "How was your order?" sheet when it's
  shown, and the new `review.submitted` event says what they rated: the order and each dish's review id and
  stars, never words. The `review.submitted` webhook stays the source of truth for your backend.
- The contract's check where the app's values enter the bridge (#614): every setter, `sendCart`,
  `sendMessage`, `send` and the values given to the controller. In a Debug build a value the contract
  refuses (a colour that isn't `#RRGGBB`, seven starters, an allergen made with `Allergen(rawValue:)` that
  the contract doesn't know) stops at the call with `assertionFailure`, naming the message, the field and
  the rule, never the value. A minor version because code that passed such a value before now stops a
  Debug build.
- A Release build sends a bad patch field (`appearance`, `text`) as it is, and the page drops that field
  alone; any other refused message isn't sent. Either way one line, `[tamr] shell: appearance: dropped
  accent (format)` or `[tamr] shell: starters: not sent: items (count)`, goes to `onLog` or the system log
  (as an error) once per message type and field, even without `debug`. Nothing else changes on the wire.
- The cart handler's reply is checked before it's posted (#676), so a reply the page would refuse no
  longer leaves the cart to time out. A bad field is repaired, never stopped on: a refused `error.message`
  or line `message` is trimmed as JavaScript's `trim()` does, then cut to 300 or 200 code points (never
  inside an emoji), or dropped if only spaces are left; `lines` and `unmapped` keep their first 50; a line
  or unmapped entry with a bad id is dropped. One line per field, `[tamr] shell: reply: trimmed
  error.message (length)`, goes to `onLog` or the system log (as an error) once, never with the value. A
  reply still refused after that goes as `failed` to the same `replyTo`. A good reply is posted as before.
- An iOS app opened while offline now shows the shell's "couldn't open" screen and Try again, instead of a
  stale, unstyled page that never recovers (#675): the page itself is loaded without WebKit's cache, on the
  first load, Try again and the load after a dead web process. Its images and scripts keep the normal cache.
- `setGoal(_:)` (#450): the diner's nutrition goal as your app keeps it, per meal (`Goal(mode: .cutting,
  kcal: 600)`; a mode with no number checks nothing until the diner gives one). Kept and sent again after
  every `ready`, like `setRestrictions`. While it's set it wins over the one the diner keeps, and the waiter
  says to change it in your app; `setGoal(nil)` stops setting one.
- Treats on the house (#455): a `CartLine` in `cart.add` can carry an optional `treat` (`treatId`,
  `expiresAt`). Price that line at zero in your checkout, and redeem it from your backend once the order is
  placed (`docs/sdk/orders.md`). Additive: the field is forwarded as it comes.
- The app's bundle id goes to Tamr with the first message and every call (#615), so the app key's list of app ids is
  checked: a key used from an app it doesn't list is logged, never refused. List your bundle id on the key.
- An app can hide Tamr's review ask, take-home suggestions and treats on the house (#726), as it hides voice:
  `appearance.hideReviews`, `hideRetailSuggestions` and `hideLoyalty`. Off only: the restaurant's own switches
  win, and an app never turns one on. With reviews hidden, `requestReview` answers `not_allowed`. Additive.
- Debug mode makes the web view inspectable only in a Debug build of the app (#738): a Release build with
  `debug: true` still logs, but Safari's Web Inspector can't reach it, since it would expose the diner's session.
- `order.cancelled` (#743): the page tells your app when an order it heard placed ends unserved (declined,
  cancelled or expired), with `orderId` and `status`. Also a webhook. Additive.
- An app built with Xcode 27 no longer crashes at launch on iOS 18 and older (found on the iOS 18.4
  simulator in #732's device run): the shell sent its messages through the Swift overlay's
  `callAsyncJavaScript`, which the newer SDK links from `libswiftWebKit.dylib`, a library iOS before 26
  doesn't have. It now calls WebKit's own method. 1.0.0 makes the same call.
- `order.placed` can carry `test: true` (#742): a test key's pickup, checked and priced but never sent to the
  restaurant. Additive: the field is forwarded as it comes.

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
