// Le novità a schermo: una scheda per versione, con le sezioni (New Features, Improvements, Bug Fixes…) e il loro simbolo.
// Il testo del changelog è in inglese; ciò che sta intorno è tradotto.

import SwiftUI

struct ChangelogList: View {
    let entries: [ChangelogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(L("Versione %@", entry.version)).font(.title3.weight(.semibold))
                        Text(entry.date).font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(entry.sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(section.title, systemImage: section.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Brand.gradient)
                            ForEach(section.items, id: \.self) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("•").foregroundStyle(.secondary).accessibilityHidden(true)
                                    Text((try? AttributedString(markdown: item)) ?? AttributedString(item)).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
