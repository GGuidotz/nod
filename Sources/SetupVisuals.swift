// Pezzi grafici della configurazione: icona dell'app, spunta che si disegna, onde, indicatore dei passi,
// anteprima della notifica sul Watch, settimana della regola di presenza, anteprima della barra dei menu.
// Colori e forme vengono da Sguardo (accento della persona, riempimenti, filo da 1 pt, molle).
// Con Riduci movimento: niente onde, la spunta compare già disegnata.

import AppKit
import SwiftUI

/// La spunta-cenno di Nod (stessa geometria dell'icona), in un riquadro unitario.
struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX + w * 0.10, y: rect.minY + h * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.38, y: rect.minY + h * 0.80))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.92, y: rect.minY + h * 0.20))
        return p
    }
}

/// Una spunta che si disegna quando `trigger` cambia, nel colore d'accento.
struct DrawnCheck: View {
    var trigger: Int
    var size: CGFloat = 64
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sgAccent) private var accent

    var body: some View {
        CheckShape()
            .trim(from: 0, to: progress)
            .stroke(accent.base, style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .onAppear { draw() }
            .onChange(of: trigger) { draw() }
            .accessibilityHidden(true)
    }

    private func draw() {
        guard trigger > 0 else { progress = 0; return }
        if reduceMotion { progress = 1; return }
        progress = 0
        withAnimation(.easeOut(duration: 0.28)) { progress = 1 }
    }
}

/// L'icona dell'app, grande, con un'ombra morbida.
struct AppIconView: View {
    var size: CGFloat = 128

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.18), radius: size * 0.08, y: size * 0.03)
            .accessibilityHidden(true)
    }
}

/// Onde che si allargano attorno a qualcosa che aspetta (il Watch che aspetta il doppio clic).
struct PulseRings: View {
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sgAccent) private var accent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t / 1.8 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(accent.base.opacity(active && !reduceMotion ? 0.5 * (1 - phase) : 0), lineWidth: 2)
                        .scaleEffect(0.6 + phase * 0.8)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Indicatore dei passi: capsule, quella attuale più lunga e nel colore d'accento.
struct StepDots: View {
    var count: Int
    var current: Int
    @Environment(\.sgAccent) private var accent

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? accent.base : (i < current ? SG.Ink.tertiary : SG.Fill.neutralButton))
                    .frame(width: i == current ? 26 : 8, height: 8)
            }
        }
        .animation(SG.Motion.respecting(SG.Motion.snappy), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Passo %d di %d", current + 1, count))
    }
}

/// Una funzione di Nod in una scheda: simbolo e due righe.
struct FeatureTile: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(SG.Ink.primary)
            Text(title).font(SG.Font.bodyEmphasis).foregroundStyle(SG.Ink.primary)
            Text(detail).font(SG.Font.caption).foregroundStyle(SG.Ink.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentCard(padding: SG.Space.l)
    }
}

/// Com'è la notifica sul Watch: per riconoscerla quando arriva.
struct WatchNotificationPreview: View {
    var title = L("Nod: prova")
    var message = L("Fai doppio tap sul Watch.")
    var buttons = [L("Ricevuta"), L("Ignora")]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.2, green: 0.6, blue: 0.5)).frame(width: 14, height: 14)
                Text(verbatim: "NTFY").font(.caption2.weight(.semibold)).foregroundStyle(SG.Island.textSecondary)
            }
            Text(title).font(SG.Font.bodyEmphasis).foregroundStyle(SG.Island.textPrimary)
            Text(message).font(SG.Font.caption).foregroundStyle(SG.Island.textDetail)
            ForEach(Array(buttons.enumerated()), id: \.offset) { item in
                Text(item.element)
                    .font(SG.Font.label)
                    .foregroundStyle(SG.Island.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(item.offset == 0 ? SG.Island.surfaceRaised : SG.Island.surface))
                    .overlay(alignment: .trailing) {
                        if item.offset == 0 {
                            Image(systemName: "hand.tap.fill").font(.caption2).foregroundStyle(SG.Island.textDetail).padding(.trailing, 8)
                        }
                    }
            }
        }
        .padding(12)
        .frame(width: 168)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(SG.Island.panel))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(SG.Island.surfaceRaised, lineWidth: 3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Anteprima della notifica sul Watch: %@. Il doppio tap sceglie %@.", title, buttons.first ?? ""))
    }
}

/// La settimana della regola di presenza: sette colonne, la fascia oraria colorata nei giorni scelti.
struct WeekStrip: View {
    let schedule: WorkSchedule
    @Environment(\.sgAccent) private var accent
    private var days: [(Int, String)] { Weekdays.ordered.map { ($0.0, $0.1) } }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days, id: \.0) { day in
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(SG.Fill.neutralButton)
                            if schedule.weekdays.contains(day.0) {
                                ForEach(segments, id: \.0) { seg in
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(accent.base)
                                        .frame(height: max(4, h * CGFloat(seg.1 - seg.0) / 1440))
                                        .offset(y: h * CGFloat(seg.0) / 1440)
                                }
                            }
                        }
                    }
                    .frame(width: 22, height: 96)
                    Text(day.1).font(SG.Font.label)
                        .foregroundStyle(schedule.weekdays.contains(day.0) ? SG.Ink.primary : SG.Ink.secondary)
                }
            }
        }
        .animation(SG.Motion.respecting(SG.Motion.snappy), value: schedule)
        .accessibilityHidden(true)
    }

    /// Minuti dall'inizio del giorno; una fascia oltre la mezzanotte diventa due pezzi.
    private var segments: [(Int, Int)] {
        let s = schedule.startMinutes, e = schedule.endMinutes
        if s == e { return [(0, 1440)] }
        return s < e ? [(s, e)] : [(s, 1440), (0, e)]
    }
}

/// Anteprima del glifo nella barra dei menu, su barra chiara e scura: una tessera di Sguardo, con l'anello dell'accento
/// quando è scelta.
struct MenuBarPreview: View {
    let style: MenuBarStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        SGOptionTile(style.title, isSelected: selected, size: CGSize(width: 220, height: 52), action: action) {
            HStack(spacing: 0) {
                bar(dark: false)
                bar(dark: true)
            }
        }
        .accessibilityLabel(L("Icona %@", style.title))
    }

    private func bar(dark: Bool) -> some View {
        HStack(spacing: 8) {
            ForEach([PresenceState.here, .leaving, .away], id: \.self) { state in
                Image(nsImage: MenuBarGlyph.image(state: state, style: style))
                    .renderingMode(.template)
                    .foregroundStyle(dark ? Color.white : Color.black)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(dark ? Color(white: 0.16) : Color(white: 0.93))
    }
}

/// Una riga della verifica delle notifiche: la spunti tu, o si spunta da sola se Nod lo può vedere.
struct ChecklistRow: View {
    let text: String
    var detail: String? = nil
    @Binding var done: Bool
    var automatic = false
    @Environment(\.sgAccent) private var accent

    var body: some View {
        Button {
            if !automatic { withAnimation(SG.Motion.respecting(SG.Motion.snappy)) { done.toggle() } }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? accent.base : SG.Ink.tertiary)
                    .font(.system(size: 15))
                VStack(alignment: .leading, spacing: 2) {
                    Text(text).font(SG.Font.body).foregroundStyle(SG.Ink.primary)
                    if let detail { Text(detail).font(SG.Font.caption).foregroundStyle(SG.Ink.secondary) }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(automatic)
        .accessibilityValue(done ? L("fatto") : L("da fare"))
    }
}

/// Una pillola del riepilogo finale: capsula di Sguardo, simbolo d'avviso se manca qualcosa.
struct SummaryPill: View {
    let symbol: String
    let text: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? symbol : "exclamationmark.circle")
                .foregroundStyle(ok ? SG.Ink.secondary : SG.Status.warning)
            Text(text).foregroundStyle(SG.Ink.primary)
        }
        .font(SG.Font.label)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(SG.Fill.row))
        .overlay(Capsule().strokeBorder(SG.Fill.rowBorder, lineWidth: SG.Stroke.hairline))
        .accessibilityElement(children: .combine)
    }
}
