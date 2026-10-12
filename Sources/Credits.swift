// Chi ha fatto Nod e dove trovarlo: il pannello Informazioni su Nod e il pannello Info delle impostazioni.

import AppKit
import SwiftUI

enum Developer {
    static let name = "gguidotz"
    static let github = URL(string: "https://github.com/GGuidotz/nod")!
    static let email = "giulioguidotz@yahoo.com"
    static let mail = URL(string: "mailto:giulioguidotz@yahoo.com?subject=Nod")!
}

enum AboutPanel {
    static func show() {
        let center = NSMutableParagraphStyle()
        center.alignment = .center
        let base: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11), .paragraphStyle: center,
                                                   .foregroundColor: NSColor.secondaryLabelColor]
        let credits = NSMutableAttributedString(string: L("Sviluppato da %@", Developer.name) + "\n", attributes: base)
        var link = base
        link[.link] = Developer.github
        credits.append(NSAttributedString(string: "github.com/GGuidotz/nod\n", attributes: link))
        link[.link] = Developer.mail
        credits.append(NSAttributedString(string: Developer.email, attributes: link))
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}

/// Firma dello sviluppatore, riusata nelle impostazioni e alla fine della configurazione.
struct DeveloperLinks: View {
    var body: some View {
        HStack(spacing: 14) {
            Text(L("Sviluppato da %@", Developer.name)).foregroundStyle(.secondary)
            Link(destination: Developer.github) { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
            Link(destination: Developer.mail) { Label(Developer.email, systemImage: "envelope") }
        }
        .font(.callout)
    }
}
