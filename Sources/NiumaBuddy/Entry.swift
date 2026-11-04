import AppKit
import SwiftUI

@main
enum Entry {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--selftest") {
            exit(SelfTest.run())
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            exit(Snapshotter.run(outputDir: args[i + 1]))
        }
        if isAlreadyRunning() {
            exit(0)
        }
        NiumaBuddyApp.main()
    }

    /// 菜单栏里已经有一个在跑了，就别再放第二个图标
    private static func isAlreadyRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let me = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains { $0.processIdentifier != me }
    }
}

/// 小铜板和通知不属于任何 SwiftUI 场景，需要从场景里借来「打开设置」的动作
final class AppActions {
    static let shared = AppActions()
    var openSettingsAction: (() -> Void)?

    func openSettings() {
        if let openSettingsAction {
            openSettingsAction()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        NSApp.activate()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ConfigStore()
    let holidays = HolidayStore()
    let ticker = Ticker()
    let fun: FunStore
    private var pet: PetWindowController?
    private var reminders: ReminderCenter?

    override init() {
        fun = FunStore(store: store, holidays: holidays)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        reminders = ReminderCenter(store: store, holidays: holidays, fun: fun)
        pet = PetWindowController(store: store, holidays: holidays, fun: fun, ticker: ticker)
    }
}

struct NiumaBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var app

    var body: some Scene {
        MenuBarExtra {
            DashboardView(store: app.store, holidays: app.holidays, fun: app.fun, ticker: app.ticker)
        } label: {
            MenuBarLabel(store: app.store, holidays: app.holidays, ticker: app.ticker)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: app.store, holidays: app.holidays)
        }
    }
}
