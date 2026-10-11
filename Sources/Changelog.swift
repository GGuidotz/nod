// Le novità, lette dal CHANGELOG.md incluso nell'app (Contents/Resources). Formato:
//   ## 0.2.0 · 2026-11-02
//   - Una riga per novità.

import Foundation

struct ChangelogEntry: Identifiable, Equatable {
    let version: String
    let date: String
    let items: [String]
    var id: String { version }
}

enum Changelog {
    static func load(bundle: Bundle = .main) -> [ChangelogEntry] {
        guard let url = bundle.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }

    static func parse(_ text: String) -> [ChangelogEntry] {
        var entries: [ChangelogEntry] = []
        var version: String?, date = "", items: [String] = []
        func flush() {
            if let version { entries.append(ChangelogEntry(version: version, date: date, items: items)) }
        }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flush()
                let parts = line.dropFirst(3).components(separatedBy: "·").map { $0.trimmingCharacters(in: .whitespaces) }
                version = parts.first
                date = parts.count > 1 ? parts[1] : ""
                items = []
            } else if line.hasPrefix("- "), version != nil {
                items.append(String(line.dropFirst(2)))
            }
        }
        flush()
        return entries
    }

    /// Le versioni dopo `seen` fino a `current` compresa, dalla più recente.
    static func entries(after seen: String, upTo current: String, in all: [ChangelogEntry]) -> [ChangelogEntry] {
        all.filter { Version($0.version) > Version(seen) && Version($0.version) <= Version(current) }
    }
}
