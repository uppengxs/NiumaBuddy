import AppKit
import Combine
import CoreGraphics
import Foundation

/// 当天的趣味统计，跨天自动清零
struct FunDay: Codable, Equatable {
    var date: String
    var toiletCount = 0
    var toiletSeconds: TimeInterval = 0
    var toiletEarned = 0.0
    var overtimeSeconds: TimeInterval = 0
    var waterCups = 0

    init(date: String) {
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(String.self, forKey: .date)
        toiletCount = try c.decodeIfPresent(Int.self, forKey: .toiletCount) ?? 0
        toiletSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .toiletSeconds) ?? 0
        toiletEarned = try c.decodeIfPresent(Double.self, forKey: .toiletEarned) ?? 0
        overtimeSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .overtimeSeconds) ?? 0
        waterCups = try c.decodeIfPresent(Int.self, forKey: .waterCups) ?? 0
    }
}

struct ToiletResult: Equatable {
    let id = UUID()
    let seconds: TimeInterval
    let earned: Double
    let autoStopped: Bool
}

/// 久坐、喝水提醒；小铜板做动作，系统通知也会弹
struct HealthNudge: Equatable {
    enum Kind { case stand, water }
    let id = UUID()
    let kind: Kind
    let minutes: Int
}

/// 带薪如厕、义务加班的数据；每秒心跳一次，小铜板和下班提醒都跟着它走（不受「暂停计时」影响）
final class FunStore: ObservableObject {
    /// 键鼠超过这么久没动，就当人不在电脑前
    static let idleThreshold: TimeInterval = 120
    /// 带薪如厕忘了点结束时，最多算一小时
    static let toiletLimit: TimeInterval = 3600
    /// 离开电脑超过这么久，就算起来活动过了，久坐重新计时
    static let breakThreshold: TimeInterval = 300
    private static let key = "fun.day.v1"

    @Published private(set) var now = Date()
    @Published private(set) var today: FunDay
    @Published private(set) var toiletStart: Date?
    @Published private(set) var lastToilet: ToiletResult?
    @Published private(set) var idleSeconds: TimeInterval = 0
    @Published private(set) var nudge: HealthNudge?
    @Published private(set) var lastWaterLogged: Date?

    private var sittingSince: Date?
    private var lastWater: Date?

    private let store: ConfigStore
    private let holidays: HolidayStore
    private let defaults: UserDefaults?
    private let calendar = Calendar.autoupdatingCurrent
    private var timer: Timer?
    private var lastTick = Date()
    private var lastSaved = Date.distantPast
    private var dirty = false
    private var terminateObserver: NSObjectProtocol?

    private var calculator: WorkCalculator {
        WorkCalculator(config: store.config, holidays: holidays.table)
    }

    init(store: ConfigStore, holidays: HolidayStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.holidays = holidays
        self.defaults = defaults
        let todayKey = Self.dayKey(Date(), calendar: calendar)
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(FunDay.self, from: data), saved.date == todayKey {
            today = saved
        } else {
            today = FunDay(date: todayKey)
        }

        let fire = Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.up))
        let timer = Timer(fire: fire, interval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.save()
        }
    }

    /// 截图用：固定的数据，不起定时器、不落盘
    init(store: ConfigStore, holidays: HolidayStore, preview day: FunDay, now: Date) {
        self.store = store
        self.holidays = holidays
        defaults = nil
        today = day
        self.now = now
    }

    deinit {
        timer?.invalidate()
        if let terminateObserver { NotificationCenter.default.removeObserver(terminateObserver) }
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// 系统级的键鼠空闲秒数；不需要任何权限
    static func systemIdleSeconds() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// 右键「我喝了一杯水」：记一杯，喝水提醒重新计时
    func logWater() {
        let date = Date()
        rollOver(date)
        today.waterCups += 1
        lastWater = date
        lastWaterLogged = date
        save()
    }

    func toggleToilet() {
        if toiletStart == nil {
            toiletStart = Date()
        } else {
            finishToilet(autoStopped: false)
        }
    }

    private func finishToilet(autoStopped: Bool) {
        guard let start = toiletStart else { return }
        let end = autoStopped ? start.addingTimeInterval(Self.toiletLimit) : Date()
        let earned = calculator.earned(from: start, to: end)
        toiletStart = nil
        rollOver(end)
        today.toiletCount += 1
        today.toiletSeconds += end.timeIntervalSince(start)
        today.toiletEarned += earned
        lastToilet = ToiletResult(seconds: end.timeIntervalSince(start), earned: earned, autoStopped: autoStopped)
        save()
    }

    private func tick() {
        let date = Date()
        // 睡眠唤醒后会隔很久才来一次心跳，单次最多记 5 秒
        let elapsed = min(max(date.timeIntervalSince(lastTick), 0), 5)
        lastTick = date
        rollOver(date)

        let idle = Self.systemIdleSeconds()
        idleSeconds = idle
        let config = store.config.sanitized()
        let segments = calculator.segments(on: date)
        if config.trackOvertime, idle < Self.idleThreshold, let end = segments.last?.end, date > end {
            today.overtimeSeconds += elapsed
            dirty = true
        }

        // 久坐：一直在电脑前（中间没离开超过 5 分钟）满 N 分钟提醒一次；不理它就再过 N 分钟提醒
        if idle >= Self.breakThreshold {
            sittingSince = nil
        } else if sittingSince == nil {
            sittingSince = date.addingTimeInterval(-idle)
        }
        if config.sitReminder, let since = sittingSince, date.timeIntervalSince(since) >= Double(config.sitMinutes) * 60 {
            nudge = HealthNudge(kind: .stand, minutes: config.sitMinutes)
            sittingSince = date
        }

        // 喝水：只在上班时段里算，每段开工重新计时；到点时人不在就等回来再提醒
        if config.waterReminder, let segment = segments.first(where: { $0.start <= date && date < $0.end }) {
            if lastWater.map({ $0 < segment.start }) ?? true {
                lastWater = segment.start
            }
            if idle < Self.idleThreshold, let last = lastWater, date.timeIntervalSince(last) >= Double(config.waterMinutes) * 60 {
                nudge = HealthNudge(kind: .water, minutes: config.waterMinutes)
                lastWater = date
            }
        }
        if let start = toiletStart, date.timeIntervalSince(start) >= Self.toiletLimit {
            finishToilet(autoStopped: true)
        }
        now = date
        if dirty && date.timeIntervalSince(lastSaved) > 15 {
            save()
        }
    }

    private func rollOver(_ date: Date) {
        let key = Self.dayKey(date, calendar: calendar)
        if today.date != key {
            today = FunDay(date: key)
            dirty = true
        }
    }

    private func save() {
        guard let defaults, let data = try? JSONEncoder().encode(today) else { return }
        defaults.set(data, forKey: Self.key)
        lastSaved = Date()
        dirty = false
    }
}
