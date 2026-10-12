// Pezzi grafici della configurazione: icona che galleggia, spunta che si disegna, onde, indicatore dei passi,
// anteprima della notifica sul Watch, settimana della regola di presenza, anteprima della barra dei menu.
// Con Riduci movimento: niente galleggiamento né onde, la spunta compare già disegnata.

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

/// Una spunta che si disegna quando `trigger` cambia.
struct DrawnCheck: View {
    var trigger: Int
    var size: CGFloat = 64
    var color: Color = Brand.aurora
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CheckShape()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.13, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.6), radius: 10)
            .onAppear { draw() }
            .onChange(of: trigger) { draw() }
            .accessibilityHidden(true)
    }

    private func draw() {
        guard trigger > 0 else { progress = 0; return }
        if reduceMotion { progress = 1; return }
        progress = 0
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { progress = 1 }
    }
}

/// L'icona dell'app, grande, che galleggia piano.
struct FloatingAppIcon: View {
    var size: CGFloat = 128
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .shadow(color: Brand.aurora.opacity(0.35), radius: size * 0.18, y: size * 0.06)
            .offset(y: up ? -size * 0.04 : size * 0.04)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { up = true }
            }
            .accessibilityHidden(true)
    }
}

/// Onde che si allargano attorno a qualcosa che aspetta (il Watch che aspetta il doppio clic).
struct PulseRings: View {
    var active: Bool
    var color: Color = Brand.aurora
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let phase = (t / 1.8 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(color.opacity(active && !reduceMotion ? 0.5 * (1 - phase) : 0), lineWidth: 2)
                        .scaleEffect(0.6 + phase * 0.8)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Indicatore dei passi: capsule, quella attuale più lunga e colorata.
struct StepDots: View {
    var count: Int
    var current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.secondary.opacity(i < current ? 0.6 : 0.25)))
                    .frame(width: i == current ? 26 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Passo %d di %d", current + 1, count))
    }
}

/// Una funzione di Nod in una pillola: simbolo e due righe.
struct FeatureTile: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Brand.gradient)
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentCard(padding: 16)
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
                Text(verbatim: "NTFY").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
            }
            Text(title).font(.callout.weight(.semibold)).foregroundStyle(.white)
            Text(message).font(.caption).foregroundStyle(.white.opacity(0.8))
            ForEach(Array(buttons.enumerated()), id: \.offset) { item in
                Text(item.element)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(item.offset == 0 ? 0.28 : 0.14)))
                    .overlay(alignment: .trailing) {
                        if item.offset == 0 {
                            Image(systemName: "hand.tap.fill").font(.caption2).foregroundStyle(.white.opacity(0.7)).padding(.trailing, 8)
                        }
                    }
            }
        }
        .padding(12)
        .frame(width: 168)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.black))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Anteprima della notifica sul Watch: %@. Il doppio tap sceglie %@.", title, buttons.first ?? ""))
    }
}

/// La settimana della regola di presenza: sette colonne, la fascia oraria colorata nei giorni scelti.
struct WeekStrip: View {
    let schedule: WorkSchedule
    private var days: [(Int, String)] { Weekdays.ordered.map { ($0.0, $0.1) } }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(days, id: \.0) { day in
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15))
                            if schedule.weekdays.contains(day.0) {
                                ForEach(segments, id: \.0) { seg in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Brand.gradient)
                                        .frame(height: max(4, h * CGFloat(seg.1 - seg.0) / 1440))
                                        .offset(y: h * CGFloat(seg.0) / 1440)
                                }
                            }
                        }
                    }
                    .frame(width: 22, height: 96)
                    Text(day.1).font(.caption.weight(.semibold))
                        .foregroundStyle(schedule.weekdays.contains(day.0) ? Color.primary : Color.secondary)
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: schedule)
        .accessibilityHidden(true)
    }

    /// Minuti dall'inizio del giorno; una fascia oltre la mezzanotte diventa due pezzi.
    private var segments: [(Int, Int)] {
        let s = schedule.startMinutes, e = schedule.endMinutes
        if s == e { return [(0, 1440)] }
        return s < e ? [(s, e)] : [(s, 1440), (0, e)]
    }
}

/// Anteprima del glifo nella barra dei menu, su barra chiara e scura.
struct MenuBarPreview: View {
    let style: MenuBarStyle
    let selected: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                bar(dark: false)
                bar(dark: true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(style.title).font(.callout.weight(selected ? .semibold : .regular))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.secondary.opacity(0.3)), lineWidth: selected ? 2.5 : 1))
        .contentShape(Rectangle())
    }

    private func bar(dark: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach([PresenceState.here, .leaving, .away], id: \.self) { state in
                Image(nsImage: MenuBarGlyph.image(state: state, style: style))
                    .renderingMode(.template)
                    .foregroundStyle(dark ? Color.white : Color.black)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(dark ? Color(white: 0.16) : Color(white: 0.93))
    }
}

/// Una riga della verifica delle notifiche: la spunti tu, o si spunta da sola se Nod lo può vedere.
struct ChecklistRow: View {
    let text: String
    var detail: String? = nil
    @Binding var done: Bool
    var automatic = false

    var body: some View {
        Button {
            if !automatic { done.toggle() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.secondary))
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text).foregroundStyle(.primary)
                    if let detail { Text(detail).font(.callout).foregroundStyle(.secondary) }
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

/// Una pillola del riepilogo finale.
struct SummaryPill: View {
    let symbol: String
    let text: String
    let ok: Bool

    var body: some View {
        Label(text, systemImage: ok ? symbol : "exclamationmark.circle")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(ok ? AnyShapeStyle(Brand.accent.opacity(0.18)) : AnyShapeStyle(Color.orange.opacity(0.18))))
            .foregroundStyle(ok ? Color.primary : Color.orange)
    }
}
