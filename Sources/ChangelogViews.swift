// Le novità a schermo: una scheda per versione, con le sezioni (New Features, Improvements, Bug Fixes…) e il loro simbolo.
// Il testo del changelog è in inglese; ciò che sta intorno è tradotto.

import SwiftUI

struct ChangelogList: View {
    let entries: [ChangelogEntry]
    /// Una scheda di Sguardo per ogni versione. Spento quando l'elenco sta già dentro una scheda (l'aggiornamento).
    var cards = false

    var body: some View {
        VStack(alignment: .leading, spacing: cards ? 12 : 24) {
            ForEach(entries) { entry in
                if cards {
                    entryView(entry).contentCard()
                } else {
                    entryView(entry)
                }
            }
        }
    }

    private func entryView(_ entry: ChangelogEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(L("Versione %@", entry.version)).font(SG.Font.instruction).foregroundStyle(SG.Ink.primary)
                Text(entry.date).font(SG.Font.field).foregroundStyle(SG.Ink.secondary)
            }
            ForEach(entry.sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Label(section.title, systemImage: section.symbol)
                        .font(SG.Font.label)
                        .foregroundStyle(SG.Ink.secondary)
                    ForEach(section.items, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("•").foregroundStyle(SG.Ink.secondary).accessibilityHidden(true)
                            Text((try? AttributedString(markdown: item)) ?? AttributedString(item))
                                .font(SG.Font.body)
                                .foregroundStyle(SG.Ink.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
