import Foundation

/// `NiumaBuddy --selftest`：不依赖 XCTest 的计算逻辑自检（只装了 Command Line Tools 也能跑）
enum SelfTest {
    private static var failures = 0

    static func run() -> Int32 {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        func at(_ day: Int, _ h: Int, _ m: Int, _ s: Int = 0) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h, minute: m, second: s)) ?? Date()
        }

        var cfg = WorkConfig()
        cfg.monthlySalary = 3000
        let calc = WorkCalculator(config: cfg, calendar: cal)

        print("— 典型的上班日：2026-11-02 周一 15:05:36，月薪 3000，9:00–18:00，午休 12:00–13:30")
        let s = calc.snapshot(at: at(2, 15, 5, 36))
        check(s.phase == .working, "状态是上班中")
        check(s.workedSeconds == 16536, "已工作 \(Fmt.hours(s.workedSeconds)) / \(Fmt.hours(s.dailySeconds)) 小时")
        check(abs(s.hourlyRate - 18.39) < 0.01, "时薪 ¥\(Fmt.money2(s.hourlyRate))")
        check(abs(s.dailyPay - 137.93) < 0.01, "今日满勤 ¥\(Fmt.money2(s.dailyPay))")
        check(abs(s.earnedToday - 84.48) < 0.01, "今日已赚 ¥\(Fmt.money4(s.earnedToday))")
        check(Fmt.rate(s.perSecond) == "0.0051", "每秒 ¥\(Fmt.rate(s.perSecond))")
        let remaining = Fmt.countdown(s.countdownTarget.map { $0.timeIntervalSince(s.now) } ?? -1)
        check(remaining == "2:54:24", "距离下班 \(remaining)")
        let pct = String(format: "%.1f", s.progress * 100)
        check(pct == "61.2", "工时进度 \(pct)%")
        check(abs(s.monthEarned - s.earnedToday) < 1e-9, "11 月第一个工作日，本月累计 = 今日已赚")
        let line = Copy.wishLine(s, wishes: calc.config.wishes)
        check(line == "再过 2 小时 25 分，一件 T 恤就赚回来了。", "心愿提示：\(line)")

        print("— 一天里的其他时刻")
        let before = calc.snapshot(at: at(2, 8, 20))
        check(before.phase == .beforeWork && before.earnedToday == 0, "08:20 还没上班，已赚 0")
        check(Copy.headline(before)?.value == "0:40:00", "08:20 距离上班 \(Copy.headline(before)?.value ?? "-")")
        let lunch = calc.snapshot(at: at(2, 12, 40))
        check(lunch.phase == .lunch, "12:40 午休中")
        check(lunch.countdownTarget == at(2, 13, 30), "午休倒计时指向 13:30")
        check(abs(lunch.earnedToday - 3 * lunch.hourlyRate) < 1e-6, "午休时不涨钱，停在 3 小时的收入")
        let after = calc.snapshot(at: at(2, 19, 0))
        check(after.phase == .afterWork && abs(after.earnedToday - after.dailyPay) < 1e-6, "19:00 已下班，今日 = 满勤")
        check(after.nextWorkStart == at(3, 9, 0), "下次上班是明天 09:00")

        print("— 休息日与月累计")
        let saturday = calc.snapshot(at: at(7, 10, 0))
        check(saturday.phase == .dayOff && saturday.earnedToday == 0, "周六休息，已赚 0")
        check(saturday.nextWorkStart == at(9, 9, 0), "周六 → 下次开工周一 09:00")
        let wed = calc.snapshot(at: at(4, 19, 0))
        check(abs(wed.monthEarned - 3 * wed.dailyPay) < 1e-6, "周三下班后本月累计 = 3 天满勤")
        check(abs(saturday.monthEarned - 5 * saturday.dailyPay) < 1e-6, "周六本月累计 = 5 天满勤")

        print("— 计薪方式与异常配置")
        var actual = cfg
        actual.payDayMode = .actual
        let actualCalc = WorkCalculator(config: actual, calendar: cal)
        check(actualCalc.workdaysInMonth(of: at(2, 12, 0)).count == 21, "2026 年 11 月有 21 个工作日")
        check(abs(actualCalc.dailyPay(on: at(2, 12, 0)) - cfg.monthlySalary / 21) < 1e-9, "按实际工作日折算日薪")
        let lastDay = actualCalc.snapshot(at: at(30, 19, 0))
        check(abs(lastDay.monthEarned - cfg.monthlySalary) < 1e-6, "按实际工作日计，月底累计正好等于月薪")

        var badLunch = cfg
        badLunch.lunchStartMinute = 19 * 60
        badLunch.lunchEndMinute = 20 * 60
        check(WorkCalculator(config: badLunch, calendar: cal).config.dailyWorkSeconds == 9 * 3600, "午休不在上班时间内 → 按无午休算 9 小时")

        var reversed = cfg
        reversed.startMinute = 18 * 60
        reversed.endMinute = 9 * 60
        check(WorkCalculator(config: reversed, calendar: cal).snapshot(at: at(2, 12, 0)).phase == .unconfigured, "下班早于上班 → 未设置")

        var dirty = cfg
        dirty.monthlySalary = -100
        dirty.wishes = [WishItem(name: "  ", price: 10), WishItem(name: "咖啡", price: -1), WishItem(name: "书", price: 40)]
        dirty.workdays = [0, 2, 9]
        let clean = dirty.sanitized()
        check(clean.monthlySalary == 0, "负数月薪被归零")
        check(clean.wishes.map(\.name) == ["书"], "空名字、非正价格的心愿被过滤")
        check(clean.workdays == [2], "非法的星期值被过滤")

        print("— 法定节假日（2026 年安排，国办发明电〔2025〕7号）")
        func on(_ month: Int, _ day: Int, _ h: Int, _ m: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: h, minute: m)) ?? Date()
        }
        let table = HolidayTable(years: BuiltinHolidays.years)
        let hcalc = WorkCalculator(config: cfg, holidays: table, calendar: cal)
        let national = hcalc.snapshot(at: on(10, 1, 10, 0))
        check(national.phase == .dayOff && national.earnedToday == 0, "10-01 周四国庆放假，已赚 0")
        check(Copy.pillTitle(national) == "国庆节", "状态写「国庆节」")
        check(national.nextWorkStart == on(10, 8, 9, 0), "国庆假期 → 下次开工 10-08 09:00")
        let holidayLine = Copy.wishLine(national, wishes: hcalc.config.wishes)
        check(holidayLine == "国庆节假期。下次开工是10月8日 09:00，先好好休息。", "提示：\(holidayLine)")
        let makeup = hcalc.snapshot(at: on(10, 10, 15, 0))
        check(makeup.phase == .working && Copy.dayTag(makeup) == "调休补班", "10-10 周六调休补班，照常上班")
        check(hcalc.snapshot(at: on(10, 3, 10, 0)).phase == .dayOff, "10-03 周六放假")
        check(hcalc.snapshot(at: on(9, 25, 10, 0)).phase == .dayOff, "09-25 周五中秋放假")
        check(hcalc.snapshot(at: on(9, 20, 10, 0)).phase == .working, "09-20 周日调休补班")

        var actualHoliday = cfg
        actualHoliday.payDayMode = .actual
        let ahcalc = WorkCalculator(config: actualHoliday, holidays: table, calendar: cal)
        check(ahcalc.workdaysInMonth(of: on(10, 15, 12, 0)).count == 18, "2026 年 10 月实际上班 18 天（22 个工作日 − 5 天假 + 1 天补班）")
        check(ahcalc.workdaysInMonth(of: on(9, 15, 12, 0)).count == 22, "2026 年 9 月实际上班 22 天（22 − 中秋 1 天 + 补班 1 天）")
        check(abs(ahcalc.snapshot(at: on(10, 31, 12, 0)).monthEarned - cfg.monthlySalary) < 1e-6, "按实际工作日计，10 月底累计正好等于月薪")

        var noFollow = cfg
        noFollow.followHolidays = false
        check(WorkCalculator(config: noFollow, holidays: table, calendar: cal).snapshot(at: on(10, 1, 10, 0)).phase == .working,
              "关掉「跟随节假日」→ 10-01 按普通周四上班")
        check(hcalc.snapshot(at: on(11, 2, 10, 0)).holiday == nil, "11 月没有安排，按每周工作日算")

        print("— 小铜板的状态")
        func act(_ date: Date, idle: TimeInterval = 0, toilet: Bool = false, track: Bool = true) -> PetActivity {
            PetLogic.activity(for: calc.snapshot(at: date), idle: idle, onToilet: toilet, trackOvertime: track)
        }
        check(act(at(2, 8, 20)) == .sleeping, "08:20 戴睡帽打瞌睡")
        check(act(at(2, 10, 0)) == .working, "10:00 对着电脑敲键盘")
        check(act(at(2, 17, 40)) == .packing, "17:40 下班前 30 分钟，收拾包")
        check(act(at(2, 12, 10)) == .eating, "12:10 午休前段吃面")
        check(act(at(2, 13, 10)) == .napping, "13:10 午休后段小睡")
        check(act(at(2, 18, 5)) == .waving, "18:05 刚下班挥手")
        check(act(at(2, 19, 0), idle: 10) == .overtime, "19:00 还在用电脑 → 义务加班")
        check(act(at(2, 19, 0), idle: 600) == .resting, "19:00 人走开了 → 回家躺平")
        check(act(at(2, 19, 0), idle: 10, track: false) == .resting, "关掉义务加班统计 → 不显示加班")
        check(act(at(7, 10, 0)) == .vacation, "周六戴墨镜度假")
        check(act(at(2, 10, 0), toilet: true) == .toilet, "带薪如厕时优先显示如厕")
        check(PetLogic.coinStep(perSecond: 0.0051) == 1 && PetLogic.coinStep(perSecond: 0.05) == 5, "硬币面额随时薪调整（约 45 秒以上蹦一枚）")

        print("— 心愿换装")
        let outfit = PetLogic.outfit(wishes: WishItem.defaults, earned: 140)
        check(outfit.shirt && !outfit.shoes && outfit.prop == .ticket, "赚到 ¥140：穿上 T 恤，旁边摆电影票")
        check(PetLogic.outfit(wishes: WishItem.defaults, earned: 20).prop == .cup, "赚到 ¥20：旁边摆一杯奶茶")
        check(PetAccessory.kind(for: "一台游戏机") == .controller && PetAccessory.kind(for: "一双跑鞋") == .shoes, "按名字认出游戏机和鞋")
        check(PetAccessory.kind(for: "一本书") == .gift, "认不出来的心愿画成礼物盒")

        print("— 桌宠形象")
        func decodeConfig(_ json: String) -> WorkConfig? {
            try? JSONDecoder().decode(WorkConfig.self, from: Data(json.utf8))
        }
        check(decodeConfig(#"{"monthlySalary": 8000}"#)?.petSkin == .coin, "老配置没有形象字段 → 默认小铜板")
        let future = decodeConfig(#"{"monthlySalary": 8000, "petSkin": "dragon"}"#)
        check(future?.petSkin == .coin && future?.monthlySalary == 8000, "认不出的形象退回小铜板，月薪等其他设置照常读出")
        check(PetLogic.announcement(from: .sleeping, to: .working, skin: .haohao)?.contains("喵") == true
              && PetLogic.announcement(from: .sleeping, to: .working, skin: .coin)?.contains("喵") == false,
              "浩浩开工时说猫的台词，小铜板不说")
        check(PetSkin.allCases.filter(\.isCat).allSatisfy { PetLogic.announcement(from: .sleeping, to: .working, skin: $0)?.contains("喵") == true },
              "浩浩、球球、薯条都说猫的台词")
        check(PetSkin.allCases.allSatisfy { ($0 == .coin) == (CatCoat.of($0) == nil) }, "每只猫都有自己的毛色")

        print("— 带薪如厕")
        let rate = calc.perSecond(on: at(2, 10, 0))
        check(abs(calc.earned(from: at(2, 10, 0), to: at(2, 10, 5)) - 300 * rate) < 1e-9, "10:00–10:05 赚 5 分钟的钱")
        check(calc.earned(from: at(2, 12, 10), to: at(2, 12, 20)) == 0, "午休时间上厕所不算带薪")
        check(abs(calc.earned(from: at(2, 11, 55), to: at(2, 12, 5)) - 300 * rate) < 1e-9, "11:55–12:05 跨进午休，只算前 5 分钟")

        print("— 假期倒计时")
        let rest1 = calc.restCountdown(at: at(2, 15, 5, 36)) ?? "-"
        check(rest1 == "距离周末还有 4 天 2 小时", "周一 15:05：\(rest1)")
        let rest2 = calc.restCountdown(at: at(6, 15, 0)) ?? "-"
        check(rest2 == "今天下班就是周末，还剩 3 小时", "周五 15:00：\(rest2)")
        check(calc.restCountdown(at: at(7, 10, 0)) == nil, "周六本身休息，不显示")
        let rest3 = hcalc.restCountdown(at: on(9, 28, 10, 0)) ?? "-"
        check(rest3 == "距离国庆节假期还有 2 天 8 小时", "09-28 周一：\(rest3)")
        let rest4 = hcalc.restCountdown(at: on(9, 30, 10, 0)) ?? "-"
        check(rest4 == "今天下班就是国庆节假期，还剩 8 小时", "09-30 周三：\(rest4)")
        let next1 = hcalc.nextHolidayCountdown(at: on(6, 1, 10, 0)) ?? "-"
        check(next1 == "端午节假期还有 18 天", "06-01：\(next1)")
        let next2 = hcalc.nextHolidayCountdown(at: at(2, 10, 0)) ?? "-"
        check(next2 == "元旦还有 60 天", "11-02（2027 年安排未公布，按 1 月 1 日估）：\(next2)")
        let cny = Festivals.dates(inYear: 2027, calendar: cal).first { $0.name == "春节" }?.date
        check(cny == cal.date(from: DateComponents(year: 2027, month: 2, day: 6)), "农历推算 2027 年春节是 2 月 6 日")

        print("— 节假日数据校验")
        let unpublished = Data(#"{"year":2027,"papers":[],"days":[]}"#.utf8)
        check(HolidayParser.parse(unpublished, expectedYear: 2027)?.isPublished == false, "空安排识别为「还没公布」")
        let good = Data(#"{"year":2027,"papers":[],"days":[{"name":"元旦","date":"2027-01-01","isOffDay":true}]}"#.utf8)
        check(HolidayParser.parse(good, expectedYear: 2027)?.days.count == 1, "合法数据能解析")
        check(HolidayParser.parse(good, expectedYear: 2028) == nil, "年份对不上 → 丢弃")
        let badDate = Data(#"{"year":2027,"days":[{"name":"元旦","date":"2027-02-30","isOffDay":true}]}"#.utf8)
        check(HolidayParser.parse(badDate, expectedYear: 2027) == nil, "不存在的日期 → 丢弃")
        let sneaky = Data(#"{"year":2027,"days":[{"name":"元旦","date":"2027-+1-01","isOffDay":true}]}"#.utf8)
        check(HolidayParser.parse(sneaky, expectedYear: 2027) == nil, "日期里混了非数字 → 丢弃")
        let longName = Data(#"{"year":2027,"days":[{"name":"一二三四五六七八九十一二三四五六七八九十一","date":"2027-01-01","isOffDay":true}]}"#.utf8)
        check(HolidayParser.parse(longName, expectedYear: 2027) == nil, "节日名超长 → 丢弃")

        print(failures == 0 ? "\n全部通过" : "\n失败 \(failures) 项")
        return failures == 0 ? 0 : 1
    }

    private static func check(_ ok: Bool, _ message: @autoclosure () -> String) {
        if ok {
            print("  ✓ " + message())
        } else {
            failures += 1
            print("  ✗ " + message())
        }
    }
}
