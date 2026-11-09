import Combine
import SwiftUI
import UIKit
import WebKit

/// The chat of a `TamrWaiterController`, with a spinner until the page paints and a retry when it
/// can't load. Presented, it's a page sheet with a grabber:
///
///     present(TamrWaiterViewController(controller: waiter), animated: true)
///
/// or, with `presentation: .fullScreen`, a page of its own that the page's back arrow
/// (`Appearance(showBack: .set(true))`) closes. Pushed on a navigation controller it's a screen of
/// the stack, and the back arrow pops it. Closing it hides the chat, which stays loaded for the
/// next open.
@MainActor
public final class TamrWaiterViewController: UIViewController {
    /// How the view is presented. A struct, not an enum, so a new style never breaks an app.
    public struct Presentation: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        /// A page sheet with a grabber, the chat scrolling inside it.
        public static let sheet = Presentation(rawValue: "sheet")
        /// The whole screen, no grabber: the chat below the status bar.
        public static let fullScreen = Presentation(rawValue: "fullScreen")
    }

    public let controller: TamrWaiterController
    public let presentation: Presentation
    /// SwiftUI's dismiss, when `TamrWaiterView` holds this view.
    var dismissChat: (@MainActor () -> Void)?

    private let loading = UIActivityIndicatorView(style: .large)
    private let failed = UIStackView()
    private let overlay = UIView()
    private var state: AnyCancellable?
    private weak var webView: WKWebView?

    public init(controller: TamrWaiterController, presentation: Presentation = .sheet) {
        self.controller = controller
        self.presentation = presentation
        super.init(nibName: nil, bundle: nil)
        if presentation == .fullScreen {
            modalPresentationStyle = .fullScreen
            return
        }
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            // The chat scrolls inside the sheet instead of dragging it.
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported; use init(controller:)")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        overlay.backgroundColor = .systemBackground
        fill(overlay)
        loading.translatesAutoresizingMaskIntoConstraints = false
        loading.accessibilityLabel = "Opening the waiter"
        overlay.addSubview(loading)
        buildFailure()
        NSLayoutConstraint.activate([
            loading.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        state = controller.$pageState.sink { [weak self] state in
            self?.show(state)
        }
    }

    /// The web view is the controller's: it may have loaded before this view, and a released chat
    /// comes back in a new one, so it moves in on every appearance.
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controller.viewShown(by: self) { [weak self] in self?.closeChat() }
        attachWebView()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent || navigationController?.isBeingDismissed == true
            || isInsideAViewThatIsGoing
        {
            leave()
        }
    }

    /// The view is gone: the chat stays loaded in its web view, parked hidden in the key window.
    /// Out of this view first, so the controller can park it.
    func leave() {
        if webView?.superview === view {
            webView?.removeFromSuperview()
        }
        controller.viewHidden(by: self)
    }

    /// The page asked to close (its back arrow): SwiftUI's dismiss in SwiftUI; otherwise a pop
    /// when pushed, a dismiss when presented.
    private func closeChat() {
        if let dismissChat {
            dismissChat()
            return
        }
        if let navigation = navigationController, navigation.viewControllers.count > 1,
           navigation.topViewController === self
        {
            navigation.popViewController(animated: true)
            return
        }
        let presented: UIViewController = navigationController?.viewControllers.first === self
            ? navigationController ?? self : self
        if presented.presentingViewController?.presentedViewController === presented {
            presented.dismiss(animated: true)
        }
    }

    /// A container this view is in (the app's own wrapper, a tab bar or navigation controller) is
    /// dismissed or removed, as opposed to covered.
    private var isInsideAViewThatIsGoing: Bool {
        var ancestor = parent
        while let container = ancestor {
            if container.isBeingDismissed || container.isMovingFromParent {
                return true
            }
            ancestor = container.parent
        }
        return false
    }

    private func attachWebView() {
        guard let webView = controller.webView(), webView.superview !== view else { return }
        self.webView = webView
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        fill(webView, at: 0)
    }

    private func show(_ state: TamrPageState) {
        overlay.isHidden = state == .loaded
        failed.isHidden = state != .failed
        if state == .loading {
            loading.startAnimating()
        } else {
            loading.stopAnimating()
        }
        // A released chat comes back in a new web view.
        if state == .loading, viewIfLoaded?.window != nil {
            attachWebView()
        }
    }

    /// Full screen, the chat starts below the status bar; the page keeps its message box clear of
    /// the home indicator.
    private func fill(_ child: UIView, at index: Int? = nil) {
        child.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(child, at: index ?? view.subviews.count)
        let top = presentation == .fullScreen ? view.safeAreaLayoutGuide.topAnchor : view.topAnchor
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: top),
            child.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func buildFailure() {
        let title = UILabel()
        title.text = "The waiter couldn't open"
        title.font = .preferredFont(forTextStyle: .headline)
        let detail = UILabel()
        detail.text = "Check your connection and try again."
        detail.font = .preferredFont(forTextStyle: .body)
        detail.textColor = .secondaryLabel
        for label in [title, detail] {
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            label.textAlignment = .center
        }
        let retry = UIButton(type: .system)
        retry.setTitle("Try again", for: .normal)
        retry.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retry.addAction(UIAction { [weak self] _ in self?.controller.reload() }, for: .primaryActionTriggered)
        failed.axis = .vertical
        failed.alignment = .center
        failed.spacing = 8
        failed.setCustomSpacing(16, after: detail)
        [title, detail, retry].forEach(failed.addArrangedSubview)
        failed.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(failed)
        NSLayoutConstraint.activate([
            failed.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            failed.leadingAnchor.constraint(equalTo: overlay.layoutMarginsGuide.leadingAnchor),
            failed.trailingAnchor.constraint(equalTo: overlay.layoutMarginsGuide.trailingAnchor),
        ])
    }
}

/// `TamrWaiterViewController` in SwiftUI, for a `.sheet` or a `.fullScreenCover`:
///
///     .sheet(isPresented: $open) { TamrWaiterView(controller: waiter) }
///
/// The page's back arrow closes it with SwiftUI's dismiss. Leaving it hides the chat, which stays
/// loaded for the next open.
public struct TamrWaiterView: UIViewControllerRepresentable {
    public let controller: TamrWaiterController
    public let presentation: TamrWaiterViewController.Presentation

    public init(controller: TamrWaiterController, presentation: TamrWaiterViewController.Presentation = .sheet) {
        self.controller = controller
        self.presentation = presentation
    }

    public func makeUIViewController(context: Context) -> TamrWaiterViewController {
        let viewController = TamrWaiterViewController(controller: controller, presentation: presentation)
        updateUIViewController(viewController, context: context)
        return viewController
    }

    public func updateUIViewController(_ viewController: TamrWaiterViewController, context: Context) {
        let dismiss = context.environment.dismiss
        viewController.dismissChat = { dismiss() }
    }

    public static func dismantleUIViewController(_ viewController: TamrWaiterViewController, coordinator _: Void) {
        viewController.leave()
    }
}
