import AppKit
import Combine
import SwiftUI

extension Notification.Name {
    static let resetPetPosition = Notification.Name("NiumaBuddy.resetPetPosition")
}

/// 不抢焦点、不进 ⌘Tab、所有桌面都在的透明小窗
private final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 双击桌宠弹出的面板。无边框窗口默认当不了焦点窗口，要能点按钮、按 Esc 就得放开
private final class DashboardPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// 窗口不在前台时第一下点击也直接交给小铜板，不用先点一下「激活」
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class PetWindowController {
    private static let originKey = "pet.origin"

    private let store: ConfigStore
    private let holidays: HolidayStore
    private let fun: FunStore
    private let ticker: Ticker
    private let pet: PetController
    private let panel: PetPanel
    private let frames: PetFrameRenderer
    private var monitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var dashboard: DashboardPanel?
    private var dashboardObserver: NSObjectProtocol?
    private var dashboardMonitors: [Any] = []
    private var dragStartMouse: NSPoint?
    private var dragStartOrigin: NSPoint?
    private var walkTimer: Timer?
    private var nextStroll = Date().addingTimeInterval(60)

    /// 不直接读 store.config：@Published 在新值写进去之前就发通知，订阅里读到的还是旧大小
    private var scale: CGFloat

    init(store: ConfigStore, holidays: HolidayStore, fun: FunStore, ticker: Ticker) {
        self.store = store
        self.holidays = holidays
        self.fun = fun
        self.ticker = ticker
        scale = store.config.petSize.scale
        let pet = PetController(store: store, holidays: holidays, fun: fun)
        self.pet = pet
        frames = MainActor.assumeIsolated { PetFrameRenderer(pet: pet, store: store) }

        panel = PetPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let actions = PetActions(
            tap: { [weak self] in self?.pet.tapped() },
            doubleTap: { [weak self] in self?.togglePopover() },
            dragChanged: { [weak self] in self?.dragChanged() },
            dragEnded: { [weak self] in self?.dragEnded() },
            toggleToilet: { [weak self] in self?.fun.toggleToilet() },
            drankWater: { [weak self] in self?.fun.logWater() },
            openSettings: { AppActions.shared.openSettings() },
            hide: { [weak self] in self?.store.config.petEnabled = false }
        )
        // 底下一层是逐帧贴图的小铜板，上面一层是很少刷新的气泡和点击区域
        let host = FirstMouseHostingView(rootView: PetOverlay(pet: pet, store: store, actions: actions))
        // 窗口大小由我们自己管，别让 SwiftUI 每次刷新都重新算一遍
        host.sizingOptions = []
        let frames = self.frames
        let frameView = MainActor.assumeIsolated { frames.view }
        let container = NSView()
        for view in [frameView, host] {
            view.autoresizingMask = [.width, .height]
            container.addSubview(view)
        }
        panel.contentView = container

        applyConfig(store.config, resize: true)
        store.$config
            .removeDuplicates { $0.petEnabled == $1.petEnabled && $0.petSize == $1.petSize && $0.petOnTop == $1.petOnTop }
            .dropFirst()
            .sink { [weak self] config in self?.applyConfig(config, resize: true) }
            .store(in: &cancellables)

        // 只有鼠标在小铜板身上时窗口才接收点击，其余透明区域直接穿透到后面的窗口
        let follow: (NSEvent) -> Void = { [weak self] _ in self?.updateMousePassThrough() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: follow) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { event in
            follow(event)
            return event
        }) {
            monitors.append(local)
        }

        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.keepOnScreen() })
        observers.append(NotificationCenter.default.addObserver(
            forName: .resetPetPosition, object: nil, queue: .main
        ) { [weak self] _ in self?.resetPosition() })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.updateHidden() })

        // 放假时偶尔溜达两步
        fun.$now
            .sink { [weak self] now in self?.maybeStroll(at: now) }
            .store(in: &cancellables)
    }

    deinit {
        monitors.forEach(NSEvent.removeMonitor)
        dashboardMonitors.forEach(NSEvent.removeMonitor)
        observers.forEach(NotificationCenter.default.removeObserver)
        walkTimer?.invalidate()
    }

    // MARK: - 位置与显示

    private var windowSize: CGSize {
        CGSize(width: PetArt.canvasSize.width * scale, height: PetArt.canvasSize.height * scale)
    }

    private func applyConfig(_ config: WorkConfig, resize: Bool) {
        scale = config.petSize.scale
        panel.level = config.petOnTop ? .floating : .normal
        if resize {
            let origin = savedOrigin() ?? defaultOrigin()
            panel.setFrame(NSRect(origin: origin, size: windowSize), display: true)
            keepOnScreen()
        }
        if config.petEnabled {
            panel.orderFrontRegardless()
        } else {
            closeDashboard()
            panel.orderOut(nil)
        }
        // 刚 orderFront 时遮挡状态还没更新，先只按开关决定；之后由遮挡通知接管
        if pet.isHidden != !config.petEnabled { pet.isHidden = !config.petEnabled }
    }

    private func updateHidden() {
        let hidden = !store.config.petEnabled || !panel.occlusionState.contains(.visible)
        if pet.isHidden != hidden { pet.isHidden = hidden }
    }

    private func defaultOrigin() -> NSPoint {
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(x: visible.maxX - windowSize.width - 24, y: visible.minY)
    }

    private func savedOrigin() -> NSPoint? {
        guard let values = UserDefaults.standard.array(forKey: Self.originKey) as? [Double], values.count == 2,
              values.allSatisfy(\.isFinite) else { return nil }
        return NSPoint(x: values[0], y: values[1])
    }

    private func saveOrigin() {
        let origin = panel.frame.origin
        UserDefaults.standard.set([Double(origin.x), Double(origin.y)], forKey: Self.originKey)
    }

    /// 外接显示器拔掉之后，别让小铜板留在看不见的地方
    private func keepOnScreen() {
        let frame = panel.frame
        let petRect = petScreenRect(for: frame)
        if !NSScreen.screens.contains(where: { $0.frame.intersects(petRect) }) {
            panel.setFrameOrigin(defaultOrigin())
            saveOrigin()
        }
    }

    private func resetPosition() {
        stopWalking()
        panel.setFrameOrigin(defaultOrigin())
        saveOrigin()
        pet.hop()
    }

    /// 小铜板身体在屏幕坐标里的范围（屏幕坐标 y 轴朝上，画布 y 轴朝下）
    private func petScreenRect(for frame: NSRect) -> NSRect {
        let hit = PetArt.hitRect
        return NSRect(x: frame.minX + hit.minX * scale,
                      y: frame.maxY - hit.maxY * scale,
                      width: hit.width * scale,
                      height: hit.height * scale)
    }

    private func updateMousePassThrough() {
        guard dragStartMouse == nil, panel.isVisible else { return }
        let inside = petScreenRect(for: panel.frame).contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside {
            panel.ignoresMouseEvents = !inside
        }
    }

    // MARK: - 拖动

    private func dragChanged() {
        let mouse = NSEvent.mouseLocation
        if dragStartMouse == nil {
            stopWalking()
            closeDashboard()
            dragStartMouse = mouse
            dragStartOrigin = panel.frame.origin
            pet.isHeld = true
        }
        guard let startMouse = dragStartMouse, let startOrigin = dragStartOrigin else { return }
        panel.setFrameOrigin(NSPoint(x: startOrigin.x + mouse.x - startMouse.x, y: startOrigin.y + mouse.y - startMouse.y))
    }

    private func dragEnded() {
        dragStartMouse = nil
        dragStartOrigin = nil
        pet.isHeld = false
        keepOnScreen()
        saveOrigin()
        pet.hop()
    }

    // MARK: - 双击弹出面板

    // 不用 NSPopover：在菜单栏 App 里它会把面板压到桌宠身上，往上、往下两种弹法都一样（11-04 实测），所以自己摆位置
    private func togglePopover() {
        if dashboard != nil {
            closeDashboard()
            return
        }
        // App 不在前台时，面板上的按钮第一下点击也要直接生效
        let content = FirstMouseHostingView(rootView: DashboardView(store: store, holidays: holidays, fun: fun, ticker: ticker))
        let size = content.fittingSize
        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        content.frame = background.bounds
        content.autoresizingMask = [.width, .height]
        background.addSubview(content)

        let panel = DashboardPanel(contentRect: NSRect(origin: dashboardOrigin(for: size), size: size),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // 和桌宠同一层，后摆上来的在上面
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        panel.contentView = background
        panel.onCancel = { [weak self] in self?.closeDashboard() }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        // 点到面板外面就收起来，和原来的弹出面板一样。不能只靠「失去焦点」：App 没被激活时面板根本拿不到焦点
        dashboardObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.closeDashboard() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            self?.closeDashboard()
        }) {
            dashboardMonitors.append(global)
        }
        // 点桌宠本身不收：双击桌宠由 togglePopover 自己开关
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            if let self, event.window !== self.dashboard, event.window !== self.panel { self.closeDashboard() }
            return event
        }) {
            dashboardMonitors.append(local)
        }
        dashboard = panel
    }

    private func closeDashboard() {
        if let dashboardObserver { NotificationCenter.default.removeObserver(dashboardObserver) }
        dashboardObserver = nil
        dashboardMonitors.forEach(NSEvent.removeMonitor)
        dashboardMonitors = []
        dashboard?.orderOut(nil)
        dashboard = nil
    }

    /// 面板摆在桌宠头顶；头顶放不下就摆到旁边（左边优先），反正不压住桌宠
    private func dashboardOrigin(for size: CGSize) -> NSPoint {
        let frame = panel.frame
        // 桌宠连同桌子、存钱罐、耳朵和睡帽占的范围（画布坐标 y 朝下）
        let drawn = CGRect(x: 56, y: 64, width: 148, height: 120)
        let pet = NSRect(x: frame.minX + drawn.minX * scale, y: frame.maxY - drawn.maxY * scale,
                         width: drawn.width * scale, height: drawn.height * scale)
        let visible = (NSScreen.screens.first { $0.frame.intersects(pet) } ?? NSScreen.main)?.visibleFrame ?? frame
        let gap: CGFloat = 8

        if pet.maxY + gap + size.height <= visible.maxY {
            let x = min(max(pet.midX - size.width / 2, visible.minX + gap), visible.maxX - size.width - gap)
            return NSPoint(x: x, y: pet.maxY + gap)
        }
        let y = min(max(pet.midY - size.height / 2, visible.minY + gap), visible.maxY - size.height - gap)
        if pet.minX - gap - size.width >= visible.minX {
            return NSPoint(x: pet.minX - gap - size.width, y: y)
        }
        return NSPoint(x: min(pet.maxX + gap, visible.maxX - size.width - gap), y: y)
    }

    // MARK: - 散步

    private func maybeStroll(at now: Date) {
        guard store.config.petEnabled, pet.activity == .vacation, walkTimer == nil, dragStartMouse == nil, now >= nextStroll else { return }
        nextStroll = now.addingTimeInterval(.random(in: 90...240))
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) }) else { return }
        let visible = screen.visibleFrame
        let distance = CGFloat.random(in: 60...160) * (Bool.random() ? 1 : -1)
        let minX = visible.minX - PetArt.hitRect.minX * scale
        let maxX = visible.maxX - PetArt.hitRect.maxX * scale
        let target = min(max(panel.frame.minX + distance, minX), maxX)
        walk(to: target)
    }

    private func walk(to targetX: CGFloat) {
        let startX = panel.frame.minX
        let distance = targetX - startX
        guard abs(distance) > 10 else { return }
        pet.facing = distance > 0 ? 1 : -1
        pet.isWalking = true
        let duration = abs(distance) / 40
        let begin = Date()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            let p = min(Date().timeIntervalSince(begin) / duration, 1)
            self.panel.setFrameOrigin(NSPoint(x: startX + distance * p, y: self.panel.frame.minY))
            if p >= 1 { self.stopWalking() }
        }
        RunLoop.main.add(timer, forMode: .common)
        walkTimer = timer
    }

    private func stopWalking() {
        guard walkTimer != nil else { return }
        walkTimer?.invalidate()
        walkTimer = nil
        pet.isWalking = false
        pet.facing = 1
        saveOrigin()
    }
}
