// Le novità, lette dal CHANGELOG.md incluso nell'app (Contents/Resources) o da quello su GitHub (aggiornamenti). Formato:
//   ## 0.3.0 · 2026-10-12
//   ### New Features
//   - One line per change, written for the people who use the app.
// Sezioni previste: New Features, Improvements, Bug Fixes, Security, Known Issues. Le righe prima di una sezione vanno in
// "Changes".

import Foundation

struct ChangelogSection: Identifiable, Equatable {
    let title: String
    let items: [String]
    var id: String { title }

    var symbol: String {
        switch title.lowercased() {
        case "new features": "sparkles"
        case "improvements": "arrow.up.circle"
        case "bug fixes": "ladybug"
        case "security": "lock.shield"
        case "known issues": "exclamationmark.triangle"
        default: "circle.grid.2x1"
        }
    }
}

struct ChangelogEntry: Identifiable, Equatable {
    let version: String
    let date: String
    let sections: [ChangelogSection]
    var id: String { version }
    var items: [String] { sections.flatMap(\.items) }
}

enum Changelog {
    static func load(bundle: Bundle = .main) -> [ChangelogEntry] {
        guard let url = bundle.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }

    static func parse(_ text: String) -> [ChangelogEntry] {
        var entries: [ChangelogEntry] = []
        var version: String?, date = ""
        var sections: [ChangelogSection] = []
        var sectionTitle = "Changes", items: [String] = []

        func flushSection() {
            if !items.isEmpty { sections.append(ChangelogSection(title: sectionTitle, items: items)) }
            items = []
        }
        func flushEntry() {
            flushSection()
            if let version { entries.append(ChangelogEntry(version: version, date: date, sections: sections)) }
            sections = []
            sectionTitle = "Changes"
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                flushEntry()
                let parts = line.dropFirst(3).components(separatedBy: "·").map { $0.trimmingCharacters(in: .whitespaces) }
                version = parts.first
                date = parts.count > 1 ? parts[1] : ""
            } else if line.hasPrefix("### "), version != nil {
                flushSection()
                sectionTitle = String(line.dropFirst(4))
            } else if line.hasPrefix("- "), version != nil {
                items.append(String(line.dropFirst(2)))
            }
        }
        flushEntry()
        return entries
    }

    /// Le versioni dopo `seen` fino a `current` compresa, dalla più recente.
    static func entries(after seen: String, upTo current: String, in all: [ChangelogEntry]) -> [ChangelogEntry] {
        all.filter { Version($0.version) > Version(seen) && Version($0.version) <= Version(current) }
    }
}
