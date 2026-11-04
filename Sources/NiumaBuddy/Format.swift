import Foundation

enum Fmt {
    private static func decimal(_ digits: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.minimumFractionDigits = digits
        f.maximumFractionDigits = digits
        return f
    }

    private static let four = decimal(4)
    private static let two = decimal(2)
    private static let upToTwo: NumberFormatter = {
        let f = decimal(0)
        f.maximumFractionDigits = 2
        return f
    }()

    private static let weekdayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    static func money4(_ value: Double) -> String {
        four.string(from: NSNumber(value: value)) ?? "0.0000"
    }

    static func money2(_ value: Double) -> String {
        two.string(from: NSNumber(value: value)) ?? "0.00"
    }

    static func number(_ value: Double) -> String {
        upToTwo.string(from: NSNumber(value: value)) ?? "0"
    }

    /// 每秒赚多少：工资很低时 4 位小数会显示成 0，就多给几位
    static func rate(_ value: Double) -> String {
        if value > 0 && value < 0.0001 {
            return String(format: "%.6f", value)
        }
        return money4(value)
    }

    static func hours(_ seconds: TimeInterval) -> String {
        String(format: "%.2f", seconds / 3600)
    }

    /// 2:54:24 这种倒计时；向上取整，正好到点时显示 0:00:00
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
    }

    /// 「2 小时 25 分」这种口语化时长
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "不到 1 分钟" }
        let h = minutes / 60, m = minutes % 60
        if h > 0 && m > 0 { return "\(h) 小时 \(m) 分" }
        if h > 0 { return "\(h) 小时" }
        return "\(m) 分钟"
    }

    /// 「3 天 2 小时」；不到一天就用 duration
    static func dayHour(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds / 3600)
        guard hours >= 24 else { return duration(seconds) }
        let d = hours / 24, h = hours % 24
        return h > 0 ? "\(d) 天 \(h) 小时" : "\(d) 天"
    }

    /// 「3 分 12 秒」，带薪如厕用
    static func minuteSecond(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60, s = total % 60
        return m > 0 ? "\(m) 分 \(s) 秒" : "\(s) 秒"
    }

    /// 需要的上班时长：超过一天按「约 N.N 天」说
    static func workSpan(_ seconds: TimeInterval, daily: TimeInterval) -> String {
        if daily > 0 && seconds >= daily {
            return String(format: "约 %.1f 天", seconds / daily)
        }
        return " \(duration(seconds))"
    }

    static func clock(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return String(format: "%02d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }

    static func hm(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func weekday(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        weekdayNames[(calendar.component(.weekday, from: date) - 1) % 7]
    }

    /// 「11月2日 周一」
    static func dayTitle(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        "\(monthDay(date, calendar: calendar)) \(weekday(date, calendar: calendar))"
    }

    /// 「明天 09:00」/「周一 09:00」；长假隔了一周以上就写日期，免得「周四」分不清是哪个周四
    static func relativeDayTime(_ date: Date, from now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        let day: String
        switch days {
        case 0: day = "今天"
        case 1: day = "明天"
        case 2..<7: day = weekday(date, calendar: calendar)
        default: day = monthDay(date, calendar: calendar)
        }
        return "\(day) \(hm(date, calendar: calendar))"
    }

    /// 「10月8日」
    static func monthDay(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0)月\(c.day ?? 0)日"
    }
}
