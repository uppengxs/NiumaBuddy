import Foundation

/// 没有官方放假安排的年份，用节日当天估一个「还有几天」（农历节日靠 Foundation 的农历推算）
enum Festivals {
    static func dates(inYear year: Int, calendar: Calendar) -> [(name: String, date: Date)] {
        var result: [(String, Date)] = []
        func add(_ name: String, _ month: Int, _ day: Int) {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                result.append((name, date))
            }
        }
        add("元旦", 1, 1)
        add("劳动节", 5, 1)
        add("国庆节", 10, 1)

        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? calendar.timeZone
        // 在大致的公历区间里逐天找农历日期，区间都不超过两个月
        func lunar(_ name: String, month: Int, day: Int, from: (Int, Int), to: (Int, Int)) {
            guard var cursor = calendar.date(from: DateComponents(year: year, month: from.0, day: from.1, hour: 12)),
                  let end = calendar.date(from: DateComponents(year: year, month: to.0, day: to.1, hour: 12)) else { return }
            while cursor <= end {
                let c = chinese.dateComponents([.month, .day], from: cursor)
                if c.month == month, c.day == day, c.isLeapMonth != true {
                    result.append((name, calendar.startOfDay(for: cursor)))
                    return
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { return }
                cursor = next
            }
        }
        lunar("春节", month: 1, day: 1, from: (1, 15), to: (2, 25))
        lunar("端午节", month: 5, day: 5, from: (5, 20), to: (6, 30))
        lunar("中秋节", month: 8, day: 15, from: (9, 1), to: (10, 15))
        return result.sorted { $0.1 < $1.1 }
    }
}

extension WorkCalculator {
    /// 一段时间里挣了多少（只算落在上班时段里的部分），带薪如厕用
    func earned(from start: Date, to end: Date) -> Double {
        guard end > start else { return 0 }
        if calendar.isDate(start, inSameDayAs: end) {
            return max(0, earnedToday(at: end) - earnedToday(at: start))
        }
        return earnedToday(at: end)
    }

    private func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// 下一段休息从哪天开始，以及这之前最后一个上班日
    private func upcomingRest(after now: Date) -> (lastWorkday: Date, firstRestDay: Date)? {
        let today = calendar.startOfDay(for: now)
        guard isWorkday(today) else { return nil }
        var lastWorkday = today
        for _ in 0..<30 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: lastWorkday) else { return nil }
            if !isWorkday(next) { return (lastWorkday, next) }
            lastWorkday = next
        }
        return nil
    }

    private func restName(for day: Date) -> String {
        if let holiday = holiday(on: day), holiday.isOffDay { return "\(holiday.name)假期" }
        let weekday = calendar.component(.weekday, from: day)
        return weekday == 1 || weekday == 7 ? "周末" : "休息日"
    }

    /// 「距离周末还有 3 天 2 小时」；今天本身就休息时返回 nil
    func restCountdown(at now: Date) -> String? {
        guard config.dailyWorkSeconds > 0, let rest = upcomingRest(after: now),
              let end = segments(on: rest.lastWorkday).last?.end else { return nil }
        let name = restName(for: rest.firstRestDay)
        let remaining = end.timeIntervalSince(now)
        if remaining <= 0 { return "已经下班，\(name)开始啦" }
        if calendar.isDate(rest.lastWorkday, inSameDayAs: now) {
            return "今天下班就是\(name)，还剩 \(Fmt.duration(remaining))"
        }
        return "距离\(name)还有 \(Fmt.dayHour(remaining))"
    }

    /// 「元旦假期还有 58 天」：优先用官方安排，当年没公布就按节日当天估
    func nextHolidayCountdown(at now: Date) -> String? {
        guard config.followHolidays else { return nil }
        let today = calendar.startOfDay(for: now)
        let imminent = upcomingRest(after: now)?.firstRestDay

        var candidates: [(name: String, date: Date)] = holidays.offBlocks.compactMap { block in
            date(fromKey: block.date).map { ("\(block.name)假期", $0) }
        }
        let year = calendar.component(.year, from: now)
        for y in [year, year + 1] where holidays.years[y]?.isPublished != true {
            candidates += Festivals.dates(inYear: y, calendar: calendar)
        }
        // 紧接着的那段休息已经在 restCountdown 里说过了，这里跳过
        let upcoming = candidates.filter { candidate in
            guard candidate.date > today else { return false }
            if let imminent, calendar.isDate(candidate.date, inSameDayAs: imminent) { return false }
            return true
        }
        guard let next = upcoming.min(by: { $0.date < $1.date }) else { return nil }
        let days = calendar.dateComponents([.day], from: today, to: next.date).day ?? 0
        return "\(next.name)还有 \(days) 天"
    }
}
