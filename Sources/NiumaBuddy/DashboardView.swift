import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: ConfigStore
    @ObservedObject var holidays: HolidayStore
    @ObservedObject var fun: FunStore
    @ObservedObject var ticker: Ticker
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let calc = WorkCalculator(config: store.config, holidays: holidays.table)
        let snap = calc.snapshot(at: ticker.now)

        VStack(alignment: .leading, spacing: 14) {
            header(snap)
            MeterView(calculator: calc, phase: snap.phase, frozenDate: ticker.frozenDate, isPaused: ticker.isPaused)
            if !snap.segments.isEmpty {
                progress(snap)
            }
            WishRow(text: Copy.wishLine(snap, wishes: calc.config.wishes), progress: wishRing(snap))
            Divider()
            HStack(alignment: .top, spacing: 12) {
                StatCell(title: "本月累计", value: "¥" + Fmt.money2(snap.monthEarned), note: "已过的工作日按满勤计")
                StatCell(title: "今日满勤", value: "¥" + Fmt.money2(snap.dailyPay), note: "时薪 ¥" + Fmt.money2(snap.hourlyRate))
            }
            let extras = funLines(snap, calc: calc)
            if !extras.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(extras) { line in
                        Label {
                            Text(line.text)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: line.icon)
                                .foregroundStyle(Theme.amberDeep)
                                .frame(width: 16)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        // 面板一弹出来焦点会落在第一个按钮上，蓝框看着像「已经按下暂停」
        .focusEffectDisabled()
    }

    private func header(_ s: DaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                StatusPill(phase: s.phase, title: Copy.pillTitle(s))
                if let tag = Copy.dayTag(s) {
                    DayTag(text: tag)
                        .help(s.holiday.map { "\($0.name)调休，今天照常上班" } ?? "")
                }
                Spacer()
                Text("\(Fmt.dayTitle(s.now))  \(Fmt.clock(s.now))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let headline = Copy.headline(s) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(headline.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(headline.value)
                        .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                }
            } else {
                Text(Copy.restLine(s))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
            }
        }
    }

    /// 假期倒计时、带薪如厕、义务加班、喝水：有内容才显示
    private func funLines(_ s: DaySnapshot, calc: WorkCalculator) -> [FunLine] {
        var lines: [FunLine] = []
        let countdown = [calc.restCountdown(at: s.now), calc.nextHolidayCountdown(at: s.now)].compactMap { $0 }
        if !countdown.isEmpty {
            lines.append(FunLine(icon: "beach.umbrella", text: countdown.joined(separator: " · ")))
        }
        let day = fun.today
        if day.toiletCount > 0 {
            lines.append(FunLine(icon: "toilet", text: "今日带薪如厕 \(day.toiletCount) 次，共赚 ¥\(Fmt.money2(day.toiletEarned))"))
        }
        if day.overtimeSeconds >= 60 {
            lines.append(FunLine(icon: "moon.stars", text: "今日义务加班 \(Fmt.duration(day.overtimeSeconds))，白送老板 ¥\(Fmt.money2(day.overtimeSeconds * s.perSecond))"))
        }
        if day.waterCups > 0 {
            lines.append(FunLine(icon: "drop", text: "今日喝水 \(day.waterCups) 杯"))
        }
        return lines
    }

    /// 心愿环跟着文案走：上班时是「离下一项还差多少」，下班后赚回过东西就画满
    private func wishRing(_ s: DaySnapshot) -> Double {
        switch s.phase {
        case .working, .lunch: return s.wish.progress
        case .afterWork: return s.wish.best != nil ? 1 : s.wish.progress
        case .beforeWork, .dayOff, .unconfigured: return 0
        }
    }

    private func progress(_ s: DaySnapshot) -> some View {
        VStack(spacing: 6) {
            DayTimelineBar(segments: s.segments, now: s.now)
            HStack {
                Text("已工作 \(Fmt.hours(s.workedSeconds)) / \(Fmt.hours(s.dailySeconds)) 小时")
                Spacer()
                Text(String(format: "%.1f%%", s.progress * 100))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private func toiletTimer(since start: Date) -> String {
        let seconds = max(0, Int(fun.now.timeIntervalSince(start)))
        return String(format: "如厕中 %d:%02d", seconds / 60, seconds % 60)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            PanelButton(
                systemImage: ticker.isPaused ? "play.fill" : "pause.fill",
                title: ticker.isPaused ? "继续计时" : "暂停计时",
                help: ticker.isPaused ? "恢复实时跳字" : "把金额定格在此刻"
            ) {
                ticker.togglePause()
            }
            PanelButton(
                systemImage: fun.toiletStart == nil ? "toilet" : "stop.fill",
                title: fun.toiletStart.map { toiletTimer(since: $0) } ?? "带薪如厕",
                help: fun.toiletStart == nil ? "开始计时，回来再点一下看看赚了多少" : "结束带薪如厕"
            ) {
                fun.toggleToilet()
            }
            Spacer()
            PanelButton(systemImage: "gearshape", help: "设置（⌘,）") {
                // 在小铜板弹出的面板里，环境里的 openSettings 不一定能用，借菜单栏那边的
                if let action = AppActions.shared.openSettingsAction {
                    action()
                } else {
                    openSettings()
                }
                NSApp.activate()
            }
            PanelButton(systemImage: "power", help: "退出牛马搭子") {
                NSApp.terminate(nil)
            }
        }
    }
}

private struct FunLine: Identifiable {
    let icon: String
    let text: String
    var id: String { text }
}

struct MenuBarLabel: View {
    @ObservedObject var store: ConfigStore
    @ObservedObject var holidays: HolidayStore
    @ObservedObject var ticker: Ticker
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            if store.config.showAmountInMenuBar {
                let earned = WorkCalculator(config: store.config, holidays: holidays.table).earnedToday(at: ticker.now)
                Text((ticker.isPaused ? "⏸ ¥" : "¥") + Fmt.money2(earned))
                    .monospacedDigit()
            } else {
                Image(systemName: "yensign.circle")
            }
        }
        .onAppear {
            // 菜单栏图标一直在场景里，把它的「打开设置」借给小铜板用
            let action = openSettings
            AppActions.shared.openSettingsAction = { action() }
        }
    }
}
