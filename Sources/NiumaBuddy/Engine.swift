import Foundation

enum WorkPhase {
    case unconfigured, dayOff, beforeWork, working, lunch, afterWork

    var title: String {
        switch self {
        case .unconfigured: return "未设置"
        case .dayOff: return "休息日"
        case .beforeWork: return "还没上班"
        case .working: return "上班中"
        case .lunch: return "午休中"
        case .afterWork: return "已下班"
        }
    }
}

struct WishStatus {
    enum Outlook: Equatable {
        /// 今天之内，再过这么久（按钟表时间，含午休）就能赚回
        case todayIn(TimeInterval)
        /// 今天赚不回，还要再上这么多秒的班
        case moreWork(TimeInterval)
    }

    var next: WishItem?
    var outlook: Outlook?
    /// 今日已赚 / 下一项价格；清单全部赚回时为 1
    var progress: Double
    /// 今天已经赚回的最贵一项
    var best: WishItem?
}

struct DaySnapshot {
    let now: Date
    let phase: WorkPhase
    let segments: [DateInterval]
    let dailyPay: Double
    let hourlyRate: Double
    let perSecond: Double
    let workedSeconds: TimeInterval
    let dailySeconds: TimeInterval
    let earnedToday: Double
    let monthEarned: Double
    /// 倒计时的目标：上班前是上班时间，上班中是下班时间，午休中是下午开工时间
    let countdownTarget: Date?
    /// 休息日或下班后，下一次上班的时间
    let nextWorkStart: Date?
    /// 今天在放假安排里的身份：法定放假或调休补班
    let holiday: HolidayDay?
    let wish: WishStatus

    var progress: Double {
        dailySeconds > 0 ? min(workedSeconds / dailySeconds, 1) : 0
    }
}

struct WorkCalculator {
    let config: WorkConfig
    let holidays: HolidayTable
    let calendar: Calendar

    init(config: WorkConfig, holidays: HolidayTable = .empty, calendar: Calendar = .autoupdatingCurrent) {
        self.config = config.sanitized()
        self.holidays = holidays
        self.calendar = calendar
    }

    /// 这一天在放假安排里的记录；没开「跟随节假日」或当年还没公布时为 nil
    func holiday(on date: Date) -> HolidayDay? {
        config.followHolidays ? holidays.day(on: date, calendar: calendar) : nil
    }

    func isWorkday(_ date: Date) -> Bool {
        if let holiday = holiday(on: date) {
            return !holiday.isOffDay
        }
        return config.workdays.contains(calendar.component(.weekday, from: date))
    }

    func segments(on date: Date) -> [DateInterval] {
        guard isWorkday(date) else { return [] }
        let day = calendar.startOfDay(for: date)
        return config.workRanges.compactMap { range in
            guard let start = calendar.date(byAdding: .minute, value: range.lowerBound, to: day),
                  let end = calendar.date(byAdding: .minute, value: range.upperBound, to: day),
                  end > start else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

    func workdaysInMonth(of date: Date) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date) else { return [] }
        var days: [Date] = []
        var day = month.start
        while day < month.end {
            if isWorkday(day) { days.append(day) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    func payDays(inMonthOf date: Date) -> Double {
        switch config.payDayMode {
        case .legal: return WorkConfig.legalPayDays
        case .actual: return Double(max(workdaysInMonth(of: date).count, 1))
        }
    }

    func dailyPay(on date: Date) -> Double {
        config.monthlySalary / payDays(inMonthOf: date)
    }

    func perSecond(on date: Date) -> Double {
        let seconds = config.dailyWorkSeconds
        return seconds > 0 ? dailyPay(on: date) / seconds : 0
    }

    func earnedToday(at now: Date) -> Double {
        workedSeconds(in: segments(on: now), at: now) * perSecond(on: now)
    }

    /// 已过的工作日按满勤补算，再加上今天已赚
    func monthEarned(at now: Date) -> Double {
        let today = calendar.startOfDay(for: now)
        let pastWorkdays = workdaysInMonth(of: now).filter { $0 < today }.count
        return Double(pastWorkdays) * dailyPay(on: now) + earnedToday(at: now)
    }

    func nextWorkStart(after now: Date) -> Date? {
        let today = calendar.startOfDay(for: now)
        for offset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if let first = segments(on: day).first, first.start > now {
                return first.start
            }
        }
        return nil
    }

    func snapshot(at now: Date) -> DaySnapshot {
        let segs = segments(on: now)
        let rate = perSecond(on: now)
        let worked = workedSeconds(in: segs, at: now)
        let earned = worked * rate

        let phase: WorkPhase
        var target: Date?
        if config.dailyWorkSeconds == 0 || config.monthlySalary == 0 {
            phase = .unconfigured
        } else if let first = segs.first, let last = segs.last {
            if now < first.start {
                phase = .beforeWork
                target = first.start
            } else if now >= last.end {
                phase = .afterWork
            } else if segs.contains(where: { $0.start <= now && now < $0.end }) {
                phase = .working
                target = last.end
            } else {
                phase = .lunch
                target = segs.first(where: { $0.start > now })?.start
            }
        } else {
            phase = .dayOff
        }

        let showsNextStart = phase == .dayOff || phase == .afterWork
        return DaySnapshot(
            now: now,
            phase: phase,
            segments: segs,
            dailyPay: dailyPay(on: now),
            hourlyRate: rate * 3600,
            perSecond: rate,
            workedSeconds: worked,
            dailySeconds: config.dailyWorkSeconds,
            earnedToday: earned,
            monthEarned: monthEarned(at: now),
            countdownTarget: target,
            nextWorkStart: showsNextStart ? nextWorkStart(after: now) : nil,
            holiday: holiday(on: now),
            wish: wishStatus(earned: earned, now: now, segments: segs, perSecond: rate)
        )
    }

    private func workedSeconds(in segments: [DateInterval], at now: Date) -> TimeInterval {
        segments.reduce(0) { sum, seg in
            sum + max(0, min(now, seg.end).timeIntervalSince(seg.start))
        }
    }

    private func wishStatus(earned: Double, now: Date, segments: [DateInterval], perSecond: Double) -> WishStatus {
        let sorted = config.wishes.sorted { $0.price < $1.price }
        let best = sorted.last { $0.price <= earned }
        guard let next = sorted.first(where: { $0.price > earned }) else {
            return WishStatus(next: nil, outlook: nil, progress: sorted.isEmpty ? 0 : 1, best: best)
        }
        let progress = earned / next.price
        guard perSecond > 0 else {
            return WishStatus(next: next, outlook: nil, progress: progress, best: best)
        }

        // 沿着今天剩下的上班时段往后走，找到攒够钱的那个钟点
        let totalNeed = (next.price - earned) / perSecond
        var need = totalNeed
        for seg in segments where seg.end > now {
            let from = max(now, seg.start)
            let available = seg.end.timeIntervalSince(from)
            if need <= available {
                let wait = from.addingTimeInterval(need).timeIntervalSince(now)
                return WishStatus(next: next, outlook: .todayIn(wait), progress: progress, best: best)
            }
            need -= available
        }
        return WishStatus(next: next, outlook: .moreWork(totalNeed), progress: progress, best: best)
    }
}

enum Copy {
    static func headline(_ s: DaySnapshot) -> (label: String, value: String)? {
        guard let target = s.countdownTarget else { return nil }
        let remaining = Fmt.countdown(target.timeIntervalSince(s.now))
        switch s.phase {
        case .beforeWork: return ("距离上班", remaining)
        case .working: return ("距离下班", remaining)
        case .lunch: return ("午休还剩", remaining)
        default: return nil
        }
    }

    /// 法定放假的那一天（调休补班不算）
    private static func offHoliday(_ s: DaySnapshot) -> HolidayDay? {
        guard let holiday = s.holiday, holiday.isOffDay else { return nil }
        return holiday
    }

    /// 状态胶囊上的字：法定放假时直接写节日名
    static func pillTitle(_ s: DaySnapshot) -> String {
        if s.phase == .dayOff, let holiday = offHoliday(s) { return holiday.name }
        return s.phase.title
    }

    /// 周末被调成上班日时，在状态旁边提醒一下
    static func dayTag(_ s: DaySnapshot) -> String? {
        guard let holiday = s.holiday, !holiday.isOffDay else { return nil }
        return "调休补班"
    }

    static func restLine(_ s: DaySnapshot) -> String {
        switch s.phase {
        case .afterWork: return "下班啦，今天辛苦了"
        case .dayOff: return offHoliday(s) != nil ? "放假啦，好好玩" : "今天休息"
        default: return "还没设置好"
        }
    }

    static func wishLine(_ s: DaySnapshot, wishes: [WishItem]) -> String {
        switch s.phase {
        case .unconfigured:
            return "先到设置里填好月薪和作息，计价器就开始跳了。"
        case .dayOff:
            let opening = offHoliday(s).map { "\($0.name)假期" } ?? "今天不用上班"
            if let next = s.nextWorkStart {
                return "\(opening)。下次开工是\(Fmt.relativeDayTime(next, from: s.now))，先好好休息。"
            }
            return "\(opening)，好好休息。"
        case .beforeWork:
            let line = "还没开工，今天满勤能赚 ¥\(Fmt.money2(s.dailyPay))"
            if let w = wishes.filter({ $0.price <= s.dailyPay }).max(by: { $0.price < $1.price }) {
                return line + "，够买\(w.name)。"
            }
            return line + "。"
        case .working, .lunch:
            guard let next = s.wish.next else {
                return s.wish.best != nil ? "心愿清单上的都赚回来了，接下来全是纯赚。" : "每一秒都在进账，稳住。"
            }
            switch s.wish.outlook {
            case .todayIn(let wait):
                return "再过 \(Fmt.duration(wait))，\(next.name)就赚回来了。"
            case .moreWork(let work):
                return "照这个速度，再上\(Fmt.workSpan(work, daily: s.dailySeconds))的班，就能赚回\(next.name)。"
            case nil:
                return "再坚持一下，\(next.name)在向你招手。"
            }
        case .afterWork:
            if let best = s.wish.best {
                return "今天赚回了\(best.name)，下班快乐！"
            }
            return "今天辛苦了，下班快乐！"
        }
    }
}
