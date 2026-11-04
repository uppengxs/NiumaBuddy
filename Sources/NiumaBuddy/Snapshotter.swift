import AppKit
import SwiftUI

/// `NiumaBuddy --snapshot <目录>`：把面板在几个典型时刻渲染成 PNG，用来检查界面
enum Snapshotter {
    static func run(outputDir: String) -> Int32 {
        let dir = URL(fileURLWithPath: outputDir).standardizedFileURL
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            print("无法创建目录 \(dir.path)：\(error.localizedDescription)")
            return 1
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        var config = WorkConfig()
        config.monthlySalary = 3000
        let store = ConfigStore(config: config)
        let holidays = HolidayStore(offline: BuiltinHolidays.years)

        let cal = Calendar.autoupdatingCurrent
        func at(_ day: Int, _ h: Int, _ m: Int, _ s: Int = 0, month: Int = 11) -> Date {
            cal.date(from: DateComponents(year: 2026, month: month, day: day, hour: h, minute: m, second: s)) ?? Date()
        }

        let cases: [(name: String, date: Date, dark: Bool)] = [
            ("1-working-light", at(2, 15, 5, 36), false),
            ("2-working-dark", at(2, 15, 5, 36), true),
            ("3-before-work", at(2, 8, 20), false),
            ("4-lunch-dark", at(2, 12, 40), true),
            ("5-after-work", at(2, 18, 30), false),
            ("6-day-off", at(7, 10, 0), false),
            ("8-national-day", at(1, 10, 0, month: 10), false),
            ("9-makeup-workday", at(10, 15, 0, month: 10), false),
        ]
        let quiet = FunStore(store: store, holidays: holidays, preview: FunDay(date: "2026-11-02"), now: at(2, 18, 30))
        var busyDay = FunDay(date: "2026-11-02")
        busyDay.toiletCount = 2
        busyDay.toiletEarned = 1.84
        busyDay.overtimeSeconds = 1920
        busyDay.waterCups = 4
        let busy = FunStore(store: store, holidays: holidays, preview: busyDay, now: at(2, 18, 30))
        for c in cases {
            let ticker = Ticker(fixedAt: c.date)
            let fun = c.name.hasPrefix("5-") ? busy : quiet
            render(DashboardView(store: store, holidays: holidays, fun: fun, ticker: ticker), dark: c.dark, to: dir.appendingPathComponent(c.name + ".png"))
        }
        render(SettingsView(store: store, holidays: holidays), dark: false, to: dir.appendingPathComponent("7-settings.png"))
        render(PetGallery(skin: .coin), dark: false, to: dir.appendingPathComponent("10-pet-gallery.png"))
        render(PetGallery(skin: .haohao), dark: false, to: dir.appendingPathComponent("11-cat-gallery.png"))
        render(PetGallery(skin: .qiuqiu), dark: false, to: dir.appendingPathComponent("12-qiuqiu-gallery.png"))
        // 黑猫在深色桌面上最容易看不清，单独出一张深色背景的
        render(PetGallery(skin: .qiuqiu, darkBackground: true), dark: false, to: dir.appendingPathComponent("13-qiuqiu-dark.png"))
        render(PetGallery(skin: .shutiao), dark: false, to: dir.appendingPathComponent("14-shutiao-gallery.png"))
        for skin in PetSkin.allCases {
            let ms = MainActor.assumeIsolated { frameCost(skin) }
            print("\(skin.name)每帧耗时 \(String(format: "%.2f", ms)) 毫秒")
        }
        print("截图已输出到 \(dir.path)")
        return 0
    }

    /// 和桌面上实时画帧的方式一样（ImageRenderer 画成图片），量一帧要多久
    @MainActor
    private static func frameCost(_ skin: PetSkin) -> Double {
        var state = PetRenderState(activity: .working)
        state.skin = skin
        state.coinPops = [0.5]
        let renderer = ImageRenderer(content: PetFrame(state: state, t: 0, scale: 1))
        renderer.scale = 2
        let frames = 120
        let start = Date()
        for i in 0..<frames {
            renderer.content = PetFrame(state: state, t: Double(i) / 6, scale: 1)
            _ = renderer.cgImage
        }
        return Date().timeIntervalSince(start) / Double(frames) * 1000
    }

    private static func render<V: View>(_ view: V, dark: Bool, to url: URL) {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = appearance
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
    }
}

/// 桌宠各种状态排成一张图，方便检查画面
private struct PetGallery: View {
    let skin: PetSkin
    var darkBackground = false

    private static func state(_ activity: PetActivity, _ edit: (inout PetRenderState) -> Void = { _ in }) -> PetRenderState {
        var s = PetRenderState(activity: activity)
        edit(&s)
        return s
    }

    private let items: [(String, PetRenderState, String?)] = [
        ("上班前", state(.sleeping), nil),
        ("上班中 · 蹦硬币", state(.working) { $0.coinPops = [0.45, 1.15]; $0.outfit = PetOutfit(prop: .cup) }, nil),
        ("下班前 30 分钟", state(.packing), nil),
        ("午休吃面", state(.eating), nil),
        ("午休小睡", state(.napping), nil),
        ("刚下班 · 心愿换装", state(.waving) { $0.outfit = PetOutfit(shirt: true, shoes: true, prop: .ticket) }, nil),
        ("义务加班", state(.overtime) { $0.outfit = PetOutfit(prop: .controller) }, nil),
        ("回家躺平", state(.resting) { $0.outfit = PetOutfit(prop: .food) }, nil),
        ("周末度假", state(.vacation), nil),
        ("带薪如厕", state(.toilet), "带薪如厕中 3 分 12 秒\n已赚 ¥0.98"),
        ("久坐提醒", state(.working) { $0.event = .stretch }, "坐了 1 小时啦，起来走走！"),
        ("喝水提醒", state(.working) { $0.event = .drink }, nil),
        ("被拎起来", state(.working) { $0.held = true }, nil),
        ("还没设置", state(.confused), nil),
        ("单击说话", state(.working) { $0.talking = true; $0.outfit = PetOutfit(prop: .gift) }, "再过 2 小时 25 分，一件 T 恤就赚回来了。"),
        ("周末散步", state(.vacation) { $0.walking = true; $0.facing = -1 }, nil),
    ]

    private func skinned(_ state: PetRenderState) -> PetRenderState {
        var s = state
        s.skin = skin
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { column in
                        let item = items[row * 4 + column]
                        VStack(spacing: 2) {
                            PetComposite(state: skinned(item.1), t: 0.6, scale: 1, bubble: item.2)
                            Text(item.0)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(LinearGradient(colors: darkBackground
                                       ? [Color(white: 0.11), Color(red: 0.14, green: 0.15, blue: 0.19)]
                                       : [Color(red: 0.32, green: 0.42, blue: 0.58), Color(red: 0.55, green: 0.48, blue: 0.62)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}
