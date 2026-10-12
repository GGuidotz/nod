// Il glifo di Nod nella barra dei menu: la stessa spunta-cenno dell'icona, disegnata come immagine modello (template),
// così macOS la colora da solo per la barra chiara, scura e selezionata.
//   al Mac: la spunta · in uscita: la spunta con l'eco del movimento sopra · lontano: la spunta e un punto
// Varianti: Piena (capsula con la spunta ritagliata) o Contorno.

import AppKit

enum MenuBarStyle: String, CaseIterable, Identifiable, Codable {
    case filled, outline
    var id: String { rawValue }
    var title: String { self == .filled ? "Piena" : "Contorno" }
}

enum MenuBarGlyph {
    private static var cache: [String: NSImage] = [:]

    static func image(state: PresenceState, style: MenuBarStyle) -> NSImage {
        let key = state.rawValue + style.rawValue
        if let cached = cache[key] { return cached }
        let width: CGFloat = state == .here ? 18 : 23
        let image = NSImage(size: NSSize(width: width, height: 18), flipped: true) { _ in
            draw(state: state, style: style)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Nod"
        cache[key] = image
        return image
    }

    private static func checkPath(dy: CGFloat = 0, width: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 4.2, y: 9.6 + dy))
        p.line(to: NSPoint(x: 7.6, y: 12.9 + dy))
        p.line(to: NSPoint(x: 13.8, y: 5.6 + dy))
        p.lineWidth = width
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        return p
    }

    private static func draw(state: PresenceState, style: MenuBarStyle) {
        let ink = NSColor.black
        switch style {
        case .outline:
            if state == .leaving {
                ink.withAlphaComponent(0.4).setStroke()
                checkPath(dy: -3.4, width: 1.8).stroke()
            }
            ink.setStroke()
            checkPath(width: 2.4).stroke()
        case .filled:
            ink.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0.5, y: 1, width: 17, height: 16), xRadius: 5.5, yRadius: 5.5).fill()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            ink.setStroke()
            checkPath(width: 2.4).stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
        }
        switch state {
        case .here:
            break
        case .leaving:
            // due tratti di movimento a destra
            ink.setStroke()
            for (y, w) in [(6.5, 3.6), (10.5, 2.4)] as [(CGFloat, CGFloat)] {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: 19.2, y: y))
                p.line(to: NSPoint(x: 19.2 + w, y: y))
                p.lineWidth = 1.6
                p.lineCapStyle = .round
                p.stroke()
            }
        case .away:
            ink.setFill()
            NSBezierPath(ovalIn: NSRect(x: 19, y: 12.5, width: 3.6, height: 3.6)).fill()
        }
    }
}
