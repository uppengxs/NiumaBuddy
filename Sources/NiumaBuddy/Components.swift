import SwiftUI

enum Theme {
    static let amber = Color(red: 1.0, green: 0.73, blue: 0.30)
    static let amberDeep = Color(red: 0.95, green: 0.55, blue: 0.12)
    static let amberGradient = LinearGradient(colors: [amberDeep, amber], startPoint: .leading, endPoint: .trailing)
    static let meterTop = Color(red: 0.15, green: 0.135, blue: 0.12)
    static let meterBottom = Color(red: 0.07, green: 0.065, blue: 0.06)

    static func color(for phase: WorkPhase) -> Color {
        switch phase {
        case .working: return Color(red: 0.20, green: 0.70, blue: 0.40)
        case .lunch: return Color(red: 0.93, green: 0.55, blue: 0.15)
        case .beforeWork: return Color(red: 0.25, green: 0.52, blue: 0.95)
        case .afterWork: return Color(red: 0.55, green: 0.42, blue: 0.85)
        case .dayOff: return Color(red: 0.15, green: 0.62, blue: 0.68)
        case .unconfigured: return .secondary
        }
    }
}

struct StatusPill: View {
    let phase: WorkPhase
    let title: String
    @State private var pulsing = false

    var body: some View {
        let color = Theme.color(for: phase)
        HStack(spacing: 6) {
            ZStack {
                if phase == .working {
                    Circle()
                        .fill(color.opacity(0.5))
                        .scaleEffect(pulsing ? 2.4 : 1)
                        .opacity(pulsing ? 0 : 1)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulsing)
                }
                Circle().fill(color)
            }
            .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.14)))
        .onAppear { pulsing = true }
    }
}

/// 状态胶囊旁边的小标记，比如「调休补班」
struct DayTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.amberDeep)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(Theme.amberDeep.opacity(0.6), lineWidth: 1))
    }
}

/// 计价屏：深色底 + 琥珀色数字，每 0.25 秒刷新一次
struct MeterView: View {
    let calculator: WorkCalculator
    let phase: WorkPhase
    let frozenDate: Date?
    let isPaused: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let date = frozenDate ?? context.date
            screen(earned: calculator.earnedToday(at: date), perSecond: calculator.perSecond(on: date))
        }
    }

    private func rateLine(_ perSecond: Double) -> String {
        let rate = "¥\(Fmt.rate(perSecond))"
        switch phase {
        case .working: return "每秒 +\(rate)"
        case .lunch: return "午休不计薪 · 下午继续每秒 +\(rate)"
        case .beforeWork: return "还没开工 · 上班后每秒 +\(rate)"
        case .afterWork: return "已收工，今天的工资已经到手"
        case .dayOff: return "今天休息，不计薪"
        case .unconfigured: return "到设置里填好月薪和作息"
        }
    }

    private func screen(earned: Double, perSecond: Double) -> some View {
        let amount = Fmt.money4(earned)
        // 背后垫一层同宽的「8」，像数码管没亮的笔画
        let ghost = String(amount.map { $0.isNumber ? "8" : $0 })
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("今日已赚")
                Spacer()
                if isPaused {
                    Label("已暂停", systemImage: "pause.fill")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.amber.opacity(0.65))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("¥")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.amber.opacity(0.8))
                ZStack(alignment: .leading) {
                    Text(ghost)
                        .foregroundStyle(Theme.amber.opacity(0.06))
                    Text(amount)
                        .foregroundStyle(Theme.amber)
                        .shadow(color: Theme.amber.opacity(0.5), radius: 8)
                        .contentTransition(.numericText(value: earned))
                        .animation(.snappy(duration: 0.2), value: earned)
                }
                // 等宽数字：跳字时整串不左右晃，背后的「8」也能对齐
                .font(.system(size: 42, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }

            Text(rateLine(perSecond))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.amber.opacity(0.65))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Theme.meterTop, Theme.meterBottom], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .environment(\.colorScheme, .dark)
    }
}

/// 当日时间轴：长度按真实时间比例画，午休是中间断开的虚线
struct DayTimelineBar: View {
    let segments: [DateInterval]
    let now: Date

    private var dayStart: Date { segments.first?.start ?? now }
    private var dayEnd: Date { segments.last?.end ?? now }

    private var gaps: [DateInterval] {
        zip(segments, segments.dropFirst()).compactMap { a, b in
            b.start > a.end ? DateInterval(start: a.end, end: b.start) : nil
        }
    }

    private func xPosition(_ date: Date, width: CGFloat) -> CGFloat {
        let total = max(dayEnd.timeIntervalSince(dayStart), 1)
        return CGFloat(date.timeIntervalSince(dayStart) / total) * width
    }

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    ForEach(gaps.indices, id: \.self) { i in
                        Path { p in
                            p.move(to: CGPoint(x: xPosition(gaps[i].start, width: w) + 5, y: 6))
                            p.addLine(to: CGPoint(x: xPosition(gaps[i].end, width: w) - 5, y: 6))
                        }
                        .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.5, 4]))
                    }
                    ForEach(segments.indices, id: \.self) { i in
                        let seg = segments[i]
                        let x0 = xPosition(seg.start, width: w)
                        let filledTo = min(max(now, seg.start), seg.end)
                        Capsule()
                            .fill(Color.primary.opacity(0.09))
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Theme.amberGradient)
                                    .frame(width: xPosition(filledTo, width: w) - x0)
                            }
                            .clipShape(Capsule())
                            .frame(width: xPosition(seg.end, width: w) - x0, height: 8)
                            .offset(x: x0, y: 2)
                    }
                    if now > dayStart && now < dayEnd {
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().strokeBorder(Theme.amberDeep, lineWidth: 2.5))
                            .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                            .frame(width: 12, height: 12)
                            .offset(x: xPosition(now, width: w) - 6)
                    }
                }
            }
            .frame(height: 12)

            GeometryReader { geo in
                ZStack {
                    HStack {
                        Text(Fmt.hm(dayStart))
                        Spacer()
                        Text(Fmt.hm(dayEnd))
                    }
                    ForEach(gaps.indices, id: \.self) { i in
                        Text("午休")
                            .position(x: xPosition(gaps[i].start.addingTimeInterval(gaps[i].duration / 2), width: geo.size.width), y: 6)
                    }
                }
            }
            .frame(height: 12)
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }
}

struct WishRow: View {
    let text: String
    let progress: Double

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.1), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(Theme.amberDeep, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "gift.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.amberDeep)
            }
            .frame(width: 28, height: 28)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct StatCell: View {
    let title: String
    let value: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
            Text(note)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PanelButton: View {
    let systemImage: String
    var title: String?
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                if let title { Text(title) }
            }
            .font(.callout)
            .padding(.horizontal, title == nil ? 8 : 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.13 : 0.06))
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
