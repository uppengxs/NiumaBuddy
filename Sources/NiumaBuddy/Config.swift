import Combine
import Foundation

struct WishItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var price: Double

    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        price = try c.decodeIfPresent(Double.self, forKey: .price) ?? 0
    }

    static let defaults: [WishItem] = [
        WishItem(name: "一杯奶茶", price: 18),
        WishItem(name: "一顿外卖", price: 35),
        WishItem(name: "一张电影票", price: 55),
        WishItem(name: "一件 T 恤", price: 129),
        WishItem(name: "一双跑鞋", price: 599),
        WishItem(name: "一台游戏机", price: 2299),
    ]
}

enum PetSize: String, Codable, CaseIterable {
    case small, medium, large

    var scale: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.25
        }
    }
}

/// 桌宠形象
enum PetSkin: String, Codable, CaseIterable {
    /// 小铜板：会走路的方孔铜钱
    case coin
    /// 浩浩：照着用户家的布偶猫画的
    case haohao
    /// 球球：照着用户家的黑猫画的
    case qiuqiu
    /// 薯条：照着用户家的金渐层画的
    case shutiao

    var name: String {
        switch self {
        case .coin: return "小铜板"
        case .haohao: return "浩浩"
        case .qiuqiu: return "球球"
        case .shutiao: return "薯条"
        }
    }

    var isCat: Bool { self != .coin }
}

enum PayDayMode: String, Codable, CaseIterable {
    /// 按法定月计薪天数 21.75 天折算日薪
    case legal
    /// 按本月实际工作日天数折算日薪
    case actual
}

struct WorkConfig: Codable, Equatable {
    static let legalPayDays = 21.75
    static let maxSalary = 100_000_000.0
    static let maxWishPrice = 10_000_000.0
    static let maxWishes = 20
    static let maxWishNameLength = 20

    var monthlySalary = 6000.0
    var payDayMode = PayDayMode.legal
    var startMinute = 9 * 60
    var endMinute = 18 * 60
    var lunchEnabled = true
    var lunchStartMinute = 12 * 60
    var lunchEndMinute = 13 * 60 + 30
    /// Calendar 的 weekday：1 = 周日，2 = 周一 … 7 = 周六
    var workdays: Set<Int> = [2, 3, 4, 5, 6]
    /// 按国务院放假安排：放假日不上班、调休补班日照常上班
    var followHolidays = true
    var showAmountInMenuBar = true
    var wishes = WishItem.defaults
    var petEnabled = true
    var petSize = PetSize.medium
    var petSkin = PetSkin.coin
    /// 桌宠浮在其他窗口前面；关掉后只在桌面上露脸
    var petOnTop = true
    var remindOffWork = true
    var trackOvertime = true
    /// 连续坐满多少分钟提醒起来走走
    var sitReminder = true
    var sitMinutes = 60
    /// 上班时段每隔多少分钟提醒喝水
    var waterReminder = true
    var waterMinutes = 60

    static let reminderMinuteChoices = [30, 45, 60, 90, 120]

    init() {}

    // 逐字段 decodeIfPresent：以后加字段时，老配置也能读出来
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = WorkConfig()
        monthlySalary = try c.decodeIfPresent(Double.self, forKey: .monthlySalary) ?? d.monthlySalary
        payDayMode = try c.decodeIfPresent(PayDayMode.self, forKey: .payDayMode) ?? d.payDayMode
        startMinute = try c.decodeIfPresent(Int.self, forKey: .startMinute) ?? d.startMinute
        endMinute = try c.decodeIfPresent(Int.self, forKey: .endMinute) ?? d.endMinute
        lunchEnabled = try c.decodeIfPresent(Bool.self, forKey: .lunchEnabled) ?? d.lunchEnabled
        lunchStartMinute = try c.decodeIfPresent(Int.self, forKey: .lunchStartMinute) ?? d.lunchStartMinute
        lunchEndMinute = try c.decodeIfPresent(Int.self, forKey: .lunchEndMinute) ?? d.lunchEndMinute
        workdays = try c.decodeIfPresent(Set<Int>.self, forKey: .workdays) ?? d.workdays
        followHolidays = try c.decodeIfPresent(Bool.self, forKey: .followHolidays) ?? d.followHolidays
        showAmountInMenuBar = try c.decodeIfPresent(Bool.self, forKey: .showAmountInMenuBar) ?? d.showAmountInMenuBar
        wishes = try c.decodeIfPresent([WishItem].self, forKey: .wishes) ?? d.wishes
        petEnabled = try c.decodeIfPresent(Bool.self, forKey: .petEnabled) ?? d.petEnabled
        petSize = try c.decodeIfPresent(PetSize.self, forKey: .petSize) ?? d.petSize
        // 认不出的形象（比如新版本加的）退回默认，别让整份配置读不出来
        petSkin = (try? c.decode(PetSkin.self, forKey: .petSkin)) ?? d.petSkin
        petOnTop = try c.decodeIfPresent(Bool.self, forKey: .petOnTop) ?? d.petOnTop
        remindOffWork = try c.decodeIfPresent(Bool.self, forKey: .remindOffWork) ?? d.remindOffWork
        trackOvertime = try c.decodeIfPresent(Bool.self, forKey: .trackOvertime) ?? d.trackOvertime
        sitReminder = try c.decodeIfPresent(Bool.self, forKey: .sitReminder) ?? d.sitReminder
        sitMinutes = try c.decodeIfPresent(Int.self, forKey: .sitMinutes) ?? d.sitMinutes
        waterReminder = try c.decodeIfPresent(Bool.self, forKey: .waterReminder) ?? d.waterReminder
        waterMinutes = try c.decodeIfPresent(Int.self, forKey: .waterMinutes) ?? d.waterMinutes
    }

    /// 计算前统一做范围校验，避免存储里的脏值把计算搞坏
    func sanitized() -> WorkConfig {
        var c = self
        c.monthlySalary = monthlySalary.isFinite ? min(max(monthlySalary, 0), Self.maxSalary) : 0
        c.startMinute = min(max(startMinute, 0), 24 * 60)
        c.endMinute = min(max(endMinute, 0), 24 * 60)
        c.lunchStartMinute = min(max(lunchStartMinute, 0), 24 * 60)
        c.lunchEndMinute = min(max(lunchEndMinute, 0), 24 * 60)
        c.workdays = workdays.filter { (1...7).contains($0) }
        c.sitMinutes = min(max(sitMinutes, 15), 240)
        c.waterMinutes = min(max(waterMinutes, 15), 240)
        c.wishes = wishes.prefix(Self.maxWishes).compactMap { wish in
            let name = String(wish.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxWishNameLength))
            guard !name.isEmpty, wish.price.isFinite, wish.price > 0 else { return nil }
            var w = wish
            w.name = name
            w.price = min(wish.price, Self.maxWishPrice)
            return w
        }
        return c
    }

    var scheduleIsValid: Bool { endMinute > startMinute }

    var lunchIsValid: Bool {
        lunchEnabled && startMinute < lunchStartMinute && lunchStartMinute < lunchEndMinute && lunchEndMinute < endMinute
    }

    /// 一天里的上班分钟段（从 0 点起算）
    var workRanges: [Range<Int>] {
        guard scheduleIsValid else { return [] }
        if lunchIsValid {
            return [startMinute..<lunchStartMinute, lunchEndMinute..<endMinute]
        }
        return [startMinute..<endMinute]
    }

    var dailyWorkSeconds: TimeInterval {
        workRanges.reduce(0) { $0 + TimeInterval($1.count * 60) }
    }
}

final class ConfigStore: ObservableObject {
    private static let key = "workConfig.v1"

    @Published var config: WorkConfig {
        didSet { persist() }
    }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(WorkConfig.self, from: data) {
            config = saved
        } else {
            config = WorkConfig()
        }
    }

    /// 只在内存里用（截图、自检），不落盘
    init(config: WorkConfig) {
        defaults = nil
        self.config = config
    }

    private func persist() {
        guard let defaults, let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
