import AVFoundation
import SwiftUI
import TamrWaiter

/// A restaurant's app: its menu screen preloads the waiter, opens it as a sheet and as a full page,
/// takes the waiter's cart lines, and logs every page event and debug line on screen.
/// "Chat with a screen on top" is the real-device check (#449): the app shows a screen over the
/// open chat, as a notification would; taps on it must not reach the chat, and after closing it
/// the chat must still take taps.
///
/// It runs against the SDK test venue with its public test key, in guest mode (#459). Another venue
/// or a local server comes from the scheme's environment (Edit Scheme > Run > Arguments):
/// `TAMR_HOST=http://localhost:3036`, `TAMR_RESTAURANT=test-org`, `TAMR_KEY=tamr_pk_test_…`.
struct MenuView: View {
    @StateObject private var model = Model()
    @State private var sheet = false
    @State private var page = false
    @State private var onTop = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("TamrWaiter \(TamrWaiterSDK.version) · \(Model.restaurant)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Ask the waiter (sheet)") { sheet = true }
                    .buttonStyle(.borderedProminent)
                Button("Ask the waiter (full page)") { page = true }
                Button("Chat with a screen on top") {
                    page = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        model.write("showed a screen over the chat")
                        onTop = true
                    }
                }
                List(model.log.indices, id: \.self) { index in
                    Text(model.log[index]).font(.system(.caption, design: .monospaced))
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("Cedar House")
        }
        // The menu screen: where the waiter is likely to be opened.
        .onAppear { model.waiter?.preload() }
        .sheet(isPresented: $sheet) {
            if let waiter = model.waiter {
                TamrWaiterView(controller: waiter)
            }
        }
        .fullScreenCover(isPresented: $page) {
            if let waiter = model.waiter {
                TamrWaiterView(controller: waiter, presentation: .fullScreen)
                    .sheet(isPresented: $onTop) {
                        VStack(spacing: 16) {
                            Text("Your order").font(.headline)
                            Text("Tap here: the chat underneath must not react.")
                            Button("Back to the chat") { onTop = false }
                        }
                        .padding()
                    }
            }
        }
    }
}

/// The waiter, wired the way an app would: debug lines and events to the log, the cart taken, the
/// microphone through the system's permission.
@MainActor
final class Model: ObservableObject {
    static let environment = ProcessInfo.processInfo.environment
    /// The SDK test venue's public test key (guest mode, #459): publishable by design.
    static let publicTestVenue = "tamr_pk_test_c6zv1fAPhaM8aUSrkUdruP8A9pNs8ddq"
    static let restaurant = environment["TAMR_RESTAURANT"] ?? "tamr-sdk-test"

    @Published private(set) var log: [String] = []
    private(set) var waiter: TamrWaiterController?
    private let opened = Date()

    init() {
        do {
            let waiter = try TamrWaiterController(
                appKey: Self.environment["TAMR_KEY"] ?? Self.publicTestVenue,
                restaurant: Self.restaurant,
                appearance: Appearance(showBack: .set(true)),
                host: Self.environment["TAMR_HOST"].flatMap(URL.init(string:)),
                debug: true,
                onLog: { [weak self] line in self?.write(line) }
            )
            // Orders go to the app's cart: take every line.
            waiter.onCartAdd { [weak self] change in
                self?.write("cart.add: \(change.lines.count) lines")
                return Reply(ok: true, lines: change.lines.map { LineAnswer(lineId: $0.lineId, ok: true) })
            }
            for type in ["ready", "order.placed", "payment.completed", "booking.made", "waiter.called", "close"] {
                waiter.on(type) { [weak self] message in self?.write("event: \(message.type)") }
            }
            waiter.onMicrophonePermission = {
                if #available(iOS 17, *) {
                    return await AVAudioApplication.requestRecordPermission()
                }
                return await withCheckedContinuation { done in
                    AVAudioSession.sharedInstance().requestRecordPermission { done.resume(returning: $0) }
                }
            }
            self.waiter = waiter
        } catch {
            write("\(error)")
        }
    }

    func write(_ line: String) {
        let seconds = String(format: "+%.1fs", Date().timeIntervalSince(opened))
        log.insert("\(seconds) \(line)", at: 0)
        if log.count > 200 {
            log.removeLast()
        }
    }
}
