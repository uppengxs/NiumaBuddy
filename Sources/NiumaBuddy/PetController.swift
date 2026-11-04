import Combine
import Foundation

struct PetBubble: Equatable {
    var id = UUID()
    let text: String
    var shownAt = Date()
    let expires: Date
}

private struct PetEventState {
    let kind: PetEvent
    let until: Date
}

/// 动画帧率档位：常驻桌面的东西要省电，只有动作快的时候才提帧
enum PetMotion {
    case calm     // 人不在电脑前：每秒 2 帧
    case normal   // 平时：每秒 6 帧
    case lively   // 蹦跳、拖动、散步、说话、蹦硬币：每秒 20 帧

    var frameInterval: Double {
        switch self {
        case .calm: return 1.0 / 2
        case .normal: return 1.0 / 6
        case .lively: return 1.0 / 20
        }
    }
}

/// 桌宠的「大脑」：跟着每秒心跳判断该做什么动作、说什么话、穿什么
final class PetController: ObservableObject {
    @Published private(set) var activity: PetActivity = .sleeping
    @Published private(set) var outfit = PetOutfit()
    @Published private(set) var bubble: PetBubble?
    @Published private(set) var coinPops: [Date] = []
    @Published private(set) var coinStep = 1
    @Published private(set) var hopStart: Date?
    @Published fileprivate var event: PetEventState?
    @Published private(set) var motion = PetMotion.normal
    /// 右键菜单要显示「开始/结束带薪如厕」，单独发布，免得界面去观察每秒都变的 FunStore
    @Published private(set) var onToilet = false
    @Published var isHeld = false {
        didSet { refreshMotion(at: Date()) }
    }
    @Published var isWalking = false {
        didSet { refreshMotion(at: Date()) }
    }
    @Published var facing: CGFloat = 1
    /// 窗口被完全挡住或桌宠被关掉时，动画整个停下
    @Published var isHidden = false

    private let store: ConfigStore
    private let holidays: HolidayStore
    private let fun: FunStore
    private var cancellables = Set<AnyCancellable>()
    private var lastActivity: PetActivity?
    private var lastCoinUnit: Int?
    private var lastBestWish: String??
    private var announced: Set<String> = []
    private var announcedDay = ""
    private var lastLine: String?
    private let toiletBubbleID = UUID()

    init(store: ConfigStore, holidays: HolidayStore, fun: FunStore) {
        self.store = store
        self.holidays = holidays
        self.fun = fun

        fun.$now
            .sink { [weak self] now in self?.update(at: now) }
            .store(in: &cancellables)
        fun.$lastToilet
            .compactMap { $0 }
            .sink { [weak self] result in self?.toiletFinished(result) }
            .store(in: &cancellables)
        fun.$nudge
            .compactMap { $0 }
            .sink { [weak self] nudge in self?.healthNudge(nudge) }
            .store(in: &cancellables)
        fun.$lastWaterLogged
            .compactMap { $0 }
            .sink { [weak self] _ in
                self?.startEvent(.drink, seconds: 6)
                self?.say("咕嘟咕嘟，喝饱了！今天第 \(fun.today.waterCups) 杯", for: 5)
            }
            .store(in: &cancellables)

        let greetedKey = "pet.greeted"
        if !UserDefaults.standard.bool(forKey: greetedKey) {
            UserDefaults.standard.set(true, forKey: greetedKey)
            greet(store.config.petSkin)
        }
        // 在设置里换了形象，新来的先打个招呼
        store.$config
            .map(\.petSkin)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] skin in
                self?.greet(skin)
                self?.hop()
            }
            .store(in: &cancellables)
    }

    private func greet(_ skin: PetSkin) {
        switch skin {
        case .coin: say("我是小铜板！单击我聊两句，双击打开面板，右键还有更多", for: 9)
        case .haohao: say("喵～我是浩浩！单击我聊两句，双击打开面板，右键还有更多", for: 9)
        case .qiuqiu: say("喵～我是球球！单击我聊两句，双击打开面板，右键还有更多", for: 9)
        case .shutiao: say("喵～我是薯条！单击我聊两句，双击打开面板，右键还有更多", for: 9)
        }
    }

    private var calculator: WorkCalculator {
        WorkCalculator(config: store.config, holidays: holidays.table)
    }

    func renderState(at date: Date) -> PetRenderState {
        var s = PetRenderState(activity: activity)
        s.skin = store.config.petSkin
        if let event, event.until > date { s.event = event.kind }
        s.outfit = outfit
        if let hopStart {
            let p = date.timeIntervalSince(hopStart) / 0.45
            if p >= 0 && p <= 1 { s.hop = p }
        }
        s.held = isHeld
        s.walking = isWalking
        s.facing = facing
        if let bubble { s.talking = date.timeIntervalSince(bubble.shownAt) < 1.4 }
        s.coinPops = coinPops.map { date.timeIntervalSince($0) }
        s.coinStep = coinStep
        return s
    }

    func tapped() {
        hop()
        let calc = calculator
        let snapshot = calc.snapshot(at: fun.now)
        let lines = PetLogic.tapLines(snapshot, activity: activity, calc: calc, overtime: fun.today.overtimeSeconds,
                                      skin: store.config.petSkin)
        let fresh = lines.filter { $0 != lastLine }
        guard let line = (fresh.isEmpty ? lines : fresh).randomElement() else { return }
        lastLine = line
        say(line, for: 4.5)
    }

    func hop() {
        hopStart = Date()
        refreshMotion(at: Date())
    }

    func say(_ text: String, for seconds: TimeInterval) {
        bubble = PetBubble(text: text, expires: Date().addingTimeInterval(seconds))
        refreshMotion(at: Date())
    }

    private func refreshMotion(at now: Date) {
        let lively = isHeld || isWalking
            || (hopStart.map { now.timeIntervalSince($0) < 0.6 } ?? false)
            || coinPops.contains { now.timeIntervalSince($0) < 1.8 }
            || (bubble.map { now.timeIntervalSince($0.shownAt) < 1.5 } ?? false)
        let calm = !lively && bubble == nil && event == nil && fun.idleSeconds > FunStore.idleThreshold
        let level: PetMotion = lively ? .lively : (calm ? .calm : .normal)
        if motion != level { motion = level }
    }

    private func startEvent(_ kind: PetEvent, seconds: TimeInterval) {
        event = PetEventState(kind: kind, until: Date().addingTimeInterval(seconds))
    }

    private func update(at now: Date) {
        let calc = calculator
        let s = calc.snapshot(at: now)
        let new = PetLogic.activity(for: s, idle: fun.idleSeconds, onToilet: fun.toiletStart != nil,
                                    trackOvertime: store.config.trackOvertime)

        let day = FunStore.dayKey(now, calendar: calc.calendar)
        if day != announcedDay {
            announcedDay = day
            announced = []
        }
        // 状态切换时自己冒一句；同一种话一天只说一次（义务加班进进出出不会一直弹）
        if let old = lastActivity, old != new, let text = PetLogic.announcement(from: old, to: new, skin: store.config.petSkin),
           announced.insert(new.rawValue).inserted {
            say(text, for: 5)
            hop()
        }
        if activity != new { activity = new }
        lastActivity = new
        if onToilet != (fun.toiletStart != nil) { onToilet = fun.toiletStart != nil }

        let step = PetLogic.coinStep(perSecond: s.perSecond)
        if coinStep != step { coinStep = step }
        let unit = Int(s.earnedToday / Double(step))
        if let last = lastCoinUnit, unit > last, new == .working { coinPops.append(now) }
        lastCoinUnit = unit
        if coinPops.contains(where: { now.timeIntervalSince($0) > 2 }) {
            coinPops.removeAll { now.timeIntervalSince($0) > 2 }
        }

        let newOutfit = PetLogic.outfit(wishes: calc.config.wishes, earned: s.earnedToday)
        if outfit != newOutfit { outfit = newOutfit }
        // 心愿刚赚回来时庆祝一下（启动时已经赚回的不算）
        let best = s.wish.best?.name
        if let previous = lastBestWish, let best, best != previous, [.working, .packing].contains(new) {
            say("赚回\(best)啦！", for: 5)
            hop()
        }
        lastBestWish = .some(best)

        if let start = fun.toiletStart {
            let elapsed = now.timeIntervalSince(start)
            let earned = calc.earned(from: start, to: now)
            bubble = PetBubble(id: toiletBubbleID, text: "带薪如厕中 \(Fmt.minuteSecond(elapsed))\n已赚 ¥\(Fmt.money2(earned))",
                               shownAt: bubble?.id == toiletBubbleID ? bubble?.shownAt ?? now : now,
                               expires: now.addingTimeInterval(3))
        } else if let bubble, bubble.expires <= now {
            self.bubble = nil
        }
        if let event, event.until <= now { self.event = nil }
        refreshMotion(at: now)
    }

    private func toiletFinished(_ result: ToiletResult) {
        let text: String
        if result.earned < 0.005 {
            text = "这趟不在上班时间，不算带薪哦"
        } else if result.autoStopped {
            text = "蹲了一小时？我帮你结束了，赚了 ¥\(Fmt.money2(result.earned))"
        } else {
            text = "这趟带薪如厕 \(Fmt.minuteSecond(result.seconds))，赚了 ¥\(Fmt.money2(result.earned))！"
        }
        say(text, for: 6)
        hop()
    }

    private func healthNudge(_ nudge: HealthNudge) {
        switch nudge.kind {
        case .stand:
            startEvent(.stretch, seconds: 20)
            say("坐了 \(Fmt.duration(Double(nudge.minutes) * 60)) 啦，起来走走！", for: 10)
        case .water:
            startEvent(.drink, seconds: 20)
            say("喝水时间到！喝完右键告诉我一声", for: 10)
        }
        hop()
    }
}
