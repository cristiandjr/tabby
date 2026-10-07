import Foundation

let prefersSpanish = Locale.preferredLanguages.first?.lowercased().hasPrefix("es") ?? false

func t(_ english: String, _ spanish: String) -> String {
    prefersSpanish ? spanish : english
}

@MainActor
final class Inbox<Element: Sendable> {
    private var buffer: [Element] = []
    private var waiter: CheckedContinuation<Element?, Never>?
    private var generation = 0

    func push(_ element: Element) {
        if let waiter {
            self.waiter = nil
            waiter.resume(returning: element)
        } else {
            buffer.append(element)
        }
    }

    func clear() {
        buffer.removeAll()
    }

    func next(timeout: Duration? = nil) async -> Element? {
        if !buffer.isEmpty { return buffer.removeFirst() }
        generation += 1
        let current = generation
        if let timeout {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                self?.expire(current)
            }
        }
        return await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }

    private func expire(_ expected: Int) {
        guard expected == generation, let waiter else { return }
        self.waiter = nil
        waiter.resume(returning: nil)
    }
}

@MainActor
final class Console {
    private let lines = Inbox<String>()

    init() {
        let lines = self.lines
        Thread.detachNewThread {
            while let line = readLine() {
                Task { @MainActor in
                    lines.push(line)
                }
            }
        }
    }

    func say(_ text: String = "") {
        print(text)
    }

    func title(_ text: String) {
        say()
        say("━━━ \(text) ━━━")
    }

    func waitForReturn(_ prompt: String) async {
        say(prompt)
        lines.clear()
        _ = await lines.next()
    }

    func askYesNo(_ question: String) async -> Bool? {
        lines.clear()
        say("\(question) \(t("[y/n]", "[s/n]"))")
        while let answer = await lines.next() {
            let normalized = answer.trimmingCharacters(in: .whitespaces).lowercased()
            if ["y", "yes", "s", "si", "sí"].contains(normalized) { return true }
            if ["n", "no"].contains(normalized) { return false }
            say(t("Please answer y or n.", "Respondé s o n."))
        }
        return nil
    }
}
