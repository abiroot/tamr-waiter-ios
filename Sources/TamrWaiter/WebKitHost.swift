import UIKit
import WebKit

/// The web view the controller drives: one page at a time, built on the first load and again after
/// a release. Tests drive the controller through a fake.
@MainActor
protocol WebViewDriving: AnyObject {
    /// The page's address now.
    var url: URL? { get }
    func load(_ url: URL)
    /// Deliver one envelope to the page (`window.tamr.receive`).
    func deliver(_ json: String)
    /// Unload the page and give the web view back.
    func detach()
    /// Keep the hidden web view in the key window, out of sight: iOS suspends one in no window (#446).
    func park()
    /// A view is taking the web view: undo what parking turned off.
    func unpark()
}

/// The `WKWebView` behind a `TamrWaiterController`, and the one file that holds the platform's web
/// view, so a device fix stays here. WebKit's delegates become the controller's calls; every
/// decision (origins, navigation, microphone) is the controller's, where tests reach it.
@MainActor
final class WebKitHost: NSObject, WebViewDriving, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private weak var controller: TamrWaiterController?

    init(controller: TamrWaiterController) {
        let configuration = WKWebViewConfiguration()
        // The waiter's spoken replies play inline and without a tap.
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // The bridge goes in before the first load, in the page's world. WebKit keeps its handler
        // strongly, so it gets a proxy that doesn't keep this host (and the controller) alive.
        let proxy = WeakMessageHandler()
        configuration.userContentController.add(proxy, contentWorld: .page, name: TamrContract.bridgeHandler)
        webView = WKWebView(frame: .zero, configuration: configuration)
        self.controller = controller
        super.init()
        proxy.host = self
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) {
            // Safari's Web Inspector, in debug mode only.
            webView.isInspectable = controller.debug
        }
    }

    var url: URL? {
        webView.url
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    /// `callAsyncJavaScript(arguments:)`: the message is an argument, never pasted into a script.
    func deliver(_ json: String) {
        webView.callAsyncJavaScript(
            "window.\(TamrContract.pageReceiver) && window.\(TamrContract.pageReceiver).receive(m)",
            arguments: ["m": json],
            in: nil,
            in: .page
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.controller?.trace("-> couldn't reach the page: \(error.localizedDescription)")
            }
        }
    }

    /// Behind everything in the foreground scene's key window, at zero size (nothing shows behind an
    /// app's page sheet), touches, VoiceOver and the status-bar tap off. Only one no view holds.
    func park() {
        guard webView.superview == nil else { return }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let window = (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?.keyWindow
        else {
            controller?.trace("no key window: the hidden chat waits in no window")
            return
        }
        webView.frame = .zero
        webView.isUserInteractionEnabled = false
        webView.accessibilityElementsHidden = true
        webView.scrollView.scrollsToTop = false
        window.insertSubview(webView, at: 0)
        controller?.trace("parked hidden in the key window")
    }

    func unpark() {
        webView.isUserInteractionEnabled = true
        webView.accessibilityElementsHidden = false
        webView.scrollView.scrollsToTop = true
        if webView.superview is UIWindow {
            webView.removeFromSuperview()
        }
    }

    func detach() {
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: TamrContract.bridgeHandler, contentWorld: .page
        )
        webView.removeFromSuperview()
    }

    // MARK: Bridge in

    fileprivate func didReceive(_ message: WKScriptMessage) {
        guard let json = message.body as? String else { return }
        let frame = message.frameInfo
        let origin = Address.origin(
            scheme: frame.securityOrigin.protocol, host: frame.securityOrigin.host, port: frame.securityOrigin.port
        )
        controller?.pageMessage(json, isMainFrame: frame.isMainFrame, origin: origin)
    }

    // MARK: WKNavigationDelegate

    func webView(
        _: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url, let controller else {
            decisionHandler(.cancel)
            return
        }
        // No target frame: a target="_blank" link or window.open, never the chat itself.
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
        decisionHandler(controller.navigate(to: url, isMainFrame: isMainFrame) ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        controller?.pageStarted(webView.url)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        controller?.pageFinished(webView.url)
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: any Error) {
        controller?.pageFailed(error)
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: any Error) {
        controller?.pageFailed(error)
    }

    func webViewWebContentProcessDidTerminate(_: WKWebView) {
        controller?.processEnded()
    }

    // MARK: WKUIDelegate

    /// `window.open`: never a second web view; the link is routed like any other.
    func webView(
        _: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            _ = controller?.navigate(to: url, isMainFrame: false)
        }
        return nil
    }

    /// The microphone only, from Tamr's page, once the app says yes; never the camera and never
    /// WebKit's own prompt (ADR 0007).
    func webView(
        _: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame _: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
    ) {
        let from = Address.origin(scheme: origin.protocol, host: origin.host, port: origin.port)
        Task { [weak controller] in
            let granted = await controller?.allowsMicrophone(origin: from, microphoneOnly: type == .microphone) ?? false
            decisionHandler(granted ? .grant : .deny)
        }
    }
}

/// Holds the host weakly, so the web view's configuration doesn't keep the chat alive.
@MainActor
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var host: WebKitHost?

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        host?.didReceive(message)
    }
}
