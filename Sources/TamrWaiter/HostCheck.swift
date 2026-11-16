import Foundation

/// One validation rule for all platforms (#614; PLAN.md): the contract's check of a message from the
/// app, run where the app's values enter the bridge (every setter, `sendCart`, `sendMessage`, `send`
/// and the controller's own values).
///
/// - In a Debug build a refused value stops at the call with `assertionFailure`, naming the message
///   type, the field and the rule, never the value. SwiftPM builds the package in the app's
///   configuration, so it fires in Debug and is compiled out of Release.
/// - Otherwise a bad patch field (`appearance`, `text`) goes as it is: the page drops that field alone
///   and applies the rest. Any other refused message isn't sent, since the page would refuse it whole.
/// - Either way it writes one warning, always, not only in debug mode, once per message type and field
///   for this controller: a bad value that reaches a release build (a colour from the app's remote
///   config) is never dropped silently (debug.md).
@MainActor
final class HostCheck {
    /// How a Debug build stops. Internal, and set only by the tests (`@testable import`) to see it:
    /// there is no public hook.
    static var stop: (String) -> Void = { assertionFailure($0) }

    private let warn: @MainActor (String) -> Void
    private let problems: (any HostMessage) -> [HostMessageProblem]
    private var warned = Set<String>()

    /// A check that writes its warning to `warn`: the app's `onLog`, or the system log as an error.
    /// `problems` is the contract's check; a test's stand-in reaches the reply's fallback.
    init(
        warn: @escaping @MainActor (String) -> Void,
        problems: @escaping (any HostMessage) -> [HostMessageProblem] = hostMessageProblems
    ) {
        self.warn = warn
        self.problems = problems
    }

    /// Whether `message` goes to the page.
    @discardableResult
    func admit(_ message: any HostMessage) -> Bool {
        let problems = hostMessageProblems(message)
        guard !problems.isEmpty else { return true }
        Self.stop("Tamr: \(message.type): the contract refuses \(Self.named(problems))")
        let sent = problems.allSatisfy(\.isPatch)
        let fresh = problems.filter { warned.insert("\(message.type) \($0.field)").inserted }
        if !fresh.isEmpty {
            warn("[tamr] shell: \(message.type): \(sent ? "dropped" : "not sent:") \(Self.named(fresh))")
        }
        return sent
    }

    /// The cart handler's reply, checked before it's posted (#676): a bad field is repaired (a message
    /// cut to its length or dropped, the lists cut to 50, an entry with a bad id dropped) and named in
    /// the same once-per-field warning. Never stops: the handler is async. A good reply comes back as
    /// it is.
    func reply(_ answer: Reply) -> Reply {
        let found = problems(HostReplyMessage(data: answer))
        guard !found.isEmpty else { return answer }
        let (repaired, notes) = Self.repair(answer, found)
        let left = problems(HostReplyMessage(data: repaired))
        let written = fresh(notes)
        if !written.isEmpty {
            warn("[tamr] shell: reply: \(written.joined(separator: ", "))")
        }
        guard !left.isEmpty else { return repaired }
        // #676's never-silent rule: a reply the repair can't make good goes as `failed`, so the
        // cart card says it didn't work instead of timing out.
        let refused = fresh(left.map { ("\($0.field) sent", Self.named([$0])) })
        if !refused.isEmpty {
            warn("[tamr] shell: reply: not sent: \(refused.joined(separator: ", ")), sent failed instead")
        }
        return Reply(ok: false, error: ReplyError(code: .failed))
    }

    /// The notes not written yet for this check, each once.
    private func fresh(_ notes: [(field: String, note: String)]) -> [String] {
        notes.filter { warned.insert("reply \($0.field)").inserted }.map(\.note)
    }

    /// The longest messages and lists a reply may carry (`reply.ts`, `cart.ts`).
    private static let errorMessageMax = 300
    private static let lineMessageMax = 200
    private static let entriesMax = 50

    /// What JavaScript's `trim()` takes off, the generated check's `jsSpace` (private there).
    private static let jsSpace = CharacterSet(
        charactersIn: "\t\n\u{0B}\u{0C}\r \u{A0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200A}\u{2028}\u{2029}\u{202F}\u{205F}\u{3000}\u{FEFF}"
    )

    /// `answer` with each field `problems` names repaired, and a note per repair: a message trimmed
    /// as JavaScript's `trim()` does, then cut to `max` code points (Unicode scalars, as the check
    /// counts, so an emoji is never split) or dropped when nothing is left, a list cut to its first 50, an entry with a bad id dropped. The notes name the
    /// app's own indexes.
    private static func repair(
        _ answer: Reply, _ problems: [HostMessageProblem]
    ) -> (Reply, [(field: String, note: String)]) {
        let bad = Dictionary(problems.map { ($0.field, $0.rule) }, uniquingKeysWith: { first, _ in first })
        var notes: [(field: String, note: String)] = []
        func note(_ verb: String, _ field: String, _ rule: String) {
            notes.append((field, "\(verb) \(field) (\(rule))"))
        }
        /// The message cut to `max`, or nil to drop it.
        func fixed(_ field: String, _ text: String?, _ max: Int) -> String? {
            guard let rule = bad[field] else { return text }
            // Trimmed first, so a message of only spaces is dropped, not cut.
            let trimmed = text?.trimmingCharacters(in: jsSpace) ?? ""
            let cut = trimmed.isEmpty ? nil : String(String.UnicodeScalarView(trimmed.unicodeScalars.prefix(max)))
            note(cut == nil ? "dropped" : "trimmed", field, rule)
            return cut
        }
        /// The first 50 of `entries`, without those whose id the check refused.
        func kept<T>(_ list: String, _ entries: [T]?, _ idField: String, _ fix: (T, Int) -> T) -> [T]? {
            guard let entries else { return nil }
            if let count = bad[list] {
                note("trimmed", list, count)
            }
            var out: [T] = []
            for (at, entry) in entries.prefix(entriesMax).enumerated() {
                if let rule = bad["\(list).\(at).\(idField)"] {
                    note("dropped", "\(list).\(at)", rule)
                } else {
                    out.append(fix(entry, at))
                }
            }
            return out
        }
        var repaired = answer
        repaired.lines = kept("lines", answer.lines, "lineId") { line, at in
            var line = line
            line.message = fixed("lines.\(at).message", line.message, lineMessageMax)
            return line
        }
        repaired.unmapped = kept("unmapped", answer.unmapped, "externalId") { entry, _ in entry }
        if var error = answer.error {
            error.message = fixed("error.message", error.message, errorMessageMax)
            repaired.error = error
        }
        return (repaired, notes)
    }

    /// `accent (format), labels.checkout (length)`: fields and rules, never values.
    private static func named(_ problems: [HostMessageProblem]) -> String {
        problems.map { "\($0.field) (\($0.rule))" }.joined(separator: ", ")
    }
}
