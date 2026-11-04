import Foundation

enum PetActivity: String, CaseIterable {
    case sleeping   // 上班前：戴睡帽打瞌睡
    case working    // 上班中：对着电脑敲键盘，每赚一笔蹦一枚硬币进存钱罐
    case packing    // 下班前 30 分钟：收拾包、看表
    case eating     // 午休前段：吃面
    case napping    // 午休后段：趴着睡
    case waving     // 刚下班 15 分钟：背着包挥手
    case overtime   // 下班后还在用电脑：义务加班
    case resting    // 下班后没在用电脑：回家躺平
    case vacation   // 周末、节假日：戴墨镜拖行李箱
    case toilet     // 带薪如厕中
    case confused   // 还没设置好
}

enum PetAccessory: Equatable {
    case shirt, shoes, cup, food, ticket, controller, gift

    /// 按心愿名字猜它是什么东西；猜不出来就是礼物盒
    static func kind(for name: String) -> PetAccessory {
        let rules: [(PetAccessory, [String])] = [
            (.shirt, ["T 恤", "T恤", "衣", "衫", "裙", "裤"]),
            (.shoes, ["鞋"]),
            (.cup, ["奶茶", "咖啡", "茶", "饮", "可乐", "果汁"]),
            (.food, ["外卖", "饭", "面", "餐", "汉堡", "披萨", "火锅", "烧烤"]),
            (.ticket, ["电影", "票", "演唱会"]),
            (.controller, ["游戏", "Switch", "PS5", "Xbox", "手柄"]),
        ]
        for (kind, words) in rules where words.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
            return kind
        }
        return .gift
    }
}

/// 今天赚回来的心愿：衣服鞋子直接穿上，别的东西摆一件最贵的在旁边
struct PetOutfit: Equatable {
    var shirt = false
    var shoes = false
    var prop: PetAccessory?
}

enum PetLogic {
    static func activity(for s: DaySnapshot, idle: TimeInterval, onToilet: Bool, trackOvertime: Bool) -> PetActivity {
        if onToilet { return .toilet }
        switch s.phase {
        case .unconfigured: return .confused
        case .dayOff: return .vacation
        case .beforeWork: return .sleeping
        case .working:
            if let end = s.segments.last?.end, end.timeIntervalSince(s.now) <= 30 * 60 { return .packing }
            return .working
        case .lunch:
            guard let before = s.segments.last(where: { $0.end <= s.now }),
                  let after = s.segments.first(where: { $0.start > s.now }) else { return .napping }
            let progress = s.now.timeIntervalSince(before.end) / after.start.timeIntervalSince(before.end)
            return progress < 0.45 ? .eating : .napping
        case .afterWork:
            guard let end = s.segments.last?.end else { return .resting }
            if s.now.timeIntervalSince(end) < 15 * 60 { return .waving }
            return trackOvertime && idle < FunStore.idleThreshold ? .overtime : .resting
        }
    }

    /// 每赚多少钱蹦一枚硬币：挑一个让硬币大约至少 45 秒才蹦一次的整数
    static func coinStep(perSecond: Double) -> Int {
        guard perSecond > 0 else { return 1 }
        for step in [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000] where Double(step) / perSecond >= 45 {
            return step
        }
        return 1000
    }

    static func outfit(wishes: [WishItem], earned: Double) -> PetOutfit {
        var outfit = PetOutfit()
        var bestProp: (price: Double, kind: PetAccessory)?
        for wish in wishes where wish.price <= earned {
            switch PetAccessory.kind(for: wish.name) {
            case .shirt: outfit.shirt = true
            case .shoes: outfit.shoes = true
            case let kind:
                if wish.price > (bestProp?.price ?? -1) { bestProp = (wish.price, kind) }
            }
        }
        outfit.prop = bestProp?.kind
        return outfit
    }

    /// 状态切换时自己冒一句。这些话会自动弹出，所以不带金额，免得投屏时露出工资
    static func announcement(from old: PetActivity, to new: PetActivity, skin: PetSkin) -> String? {
        let cat = skin.isCat
        switch new {
        case .working where old == .sleeping: return cat ? "喵！开工啦，今天也要赚罐罐钱" : "开工！今天也要好好赚钱"
        case .working where old == .napping: return cat ? "伸个懒腰，下午继续！" : "下午继续，冲！"
        case .packing: return "还有 30 分钟下班，收拾收拾"
        case .eating: return cat ? "开饭啦！小鱼干！" : "开饭啦！"
        case .waving: return cat ? "下班啦！快回家陪我" : "下班啦！明天见"
        case .overtime: return "下班了还在忙？我帮你记着加班时间"
        default: return nil
        }
    }

    /// 单击时随机说一句（用户自己点的，可以带金额）
    static func tapLines(_ s: DaySnapshot, activity: PetActivity, calc: WorkCalculator, overtime: TimeInterval, skin: PetSkin) -> [String] {
        let cat = skin.isCat
        let earned = "¥" + Fmt.money2(s.earnedToday)
        let left = s.countdownTarget.map { Fmt.duration($0.timeIntervalSince(s.now)) }
        var lines: [String]
        switch activity {
        case .working:
            lines = ["今天已经赚了 \(earned)",
                     cat ? "本喵在旁边监工，放心摸鱼" : "摸鱼也在计薪，放心摸",
                     cat ? "喝口水，顺便给我的碗也添点" : "喝口水，活动一下脖子"]
            if let left { lines.append("离下班还有 \(left)") }
            if s.wish.next != nil { lines.append(Copy.wishLine(s, wishes: calc.config.wishes)) }
            if let rest = calc.restCountdown(at: s.now) { lines.append(rest) }
        case .packing:
            lines = [cat ? "包收拾好了，本喵也准备回家了" : "包都收拾好了，就等钟点了", "今天已经赚了 \(earned)"]
            if let left { lines.append("还有 \(left) 下班！") }
        case .eating:
            lines = [cat ? "小鱼干真香，午饭不计薪也值" : "午饭不计薪，但是香啊", "吃饱了下午才有力气赚钱"]
            if let left { lines.append("午休还剩 \(left)") }
        case .napping:
            lines = [cat ? "呼噜呼噜……别吵，下午还要接着赚" : "Zzz……别吵，下午还要接着赚"]
            if let left { lines.append("午休还剩 \(left)，再睡会儿") }
        case .sleeping:
            lines = [cat ? "喵……还没开工，再团一会儿" : "还没开工，让我再睡会儿"]
            if let left { lines.append("距离上班还有 \(left)") }
        case .waving:
            lines = ["下班啦！今天赚了 \(earned)", cat ? "今天辛苦了，回家记得开罐罐" : "今天辛苦了，明天见"]
        case .overtime:
            let gift = "¥" + Fmt.money2(overtime * s.perSecond)
            lines = ["已经义务加班 \(Fmt.duration(overtime))，白送老板 \(gift)",
                     cat ? "该下班啦，本喵的饭还没放" : "该下班啦，身体要紧", "加班不计薪，我替你记着"]
        case .resting:
            lines = [cat ? "今天赚了 \(earned)，翻肚皮躺平中" : "今天赚了 \(earned)，躺平中", "早点休息，明天接着赚"]
        case .vacation:
            if let holiday = s.holiday, holiday.isOffDay {
                lines = ["\(holiday.name)快乐！今天不聊工作"]
            } else {
                lines = ["周末愉快，今天不聊工作"]
            }
            if let next = s.nextWorkStart { lines.append("下次开工：\(Fmt.relativeDayTime(next, from: s.now))") }
            if let holiday = calc.nextHolidayCountdown(at: s.now) { lines.append(holiday) }
        case .toilet:
            lines = ["带薪如厕中，别催", "这一分一秒都是工资"]
        case .confused:
            lines = ["先去设置里填好月薪和作息吧", "双击我可以打开面板"]
        }
        return lines
    }
}
