import Combine
import Foundation
import UserNotifications

/// 系统通知：下班前 10 分钟、下班那一刻、久坐、喝水。
/// 通知里不写金额：锁屏和投屏时也会显示出来。
final class ReminderCenter: NSObject, UNUserNotificationCenterDelegate {
    private let store: ConfigStore
    private let holidays: HolidayStore
    private var sent: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    init(store: ConfigStore, holidays: HolidayStore, fun: FunStore) {
        self.store = store
        self.holidays = holidays
        super.init()
        // 没有 bundle id（命令行直接跑二进制）时 UNUserNotificationCenter 会崩
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        store.$config
            .map { $0.remindOffWork || $0.sitReminder || $0.waterReminder }
            .removeDuplicates()
            .filter { $0 }
            .sink { _ in center.requestAuthorization(options: [.alert, .sound]) { _, _ in } }
            .store(in: &cancellables)

        fun.$now
            .sink { [weak self] now in self?.checkOffWork(at: now) }
            .store(in: &cancellables)

        fun.$nudge
            .compactMap { $0 }
            .sink { [weak self] nudge in self?.postHealth(nudge) }
            .store(in: &cancellables)
    }

    private func checkOffWork(at now: Date) {
        guard store.config.remindOffWork else { return }
        let calc = WorkCalculator(config: store.config, holidays: holidays.table)
        guard let end = calc.segments(on: now).last?.end else { return }
        let day = FunStore.dayKey(now, calendar: calc.calendar)
        let reminders = [
            (end.addingTimeInterval(-600), "\(day)-10", "还有 10 分钟下班", "可以开始收拾东西了。"),
            (end, "\(day)-0", "下班啦！", "今天辛苦了，明天见。"),
        ]
        // 到点后 2 分钟内才发；Mac 睡着错过了就算了，不补发
        for (time, key, title, body) in reminders
        where now >= time && now < time.addingTimeInterval(120) && !sent.contains(key) {
            sent.insert(key)
            post(id: key, title: title, body: body)
        }
    }

    private func postHealth(_ nudge: HealthNudge) {
        switch nudge.kind {
        case .stand:
            post(id: nudge.id.uuidString, title: "已经坐了 \(Fmt.duration(Double(nudge.minutes) * 60))", body: "起来走走，活动一下肩颈，让眼睛歇一歇。")
        case .water:
            post(id: nudge.id.uuidString, title: "该喝水啦", body: "起身倒杯水，顺便走两步。")
        }
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "niumabuddy.\(id)", content: content, trigger: nil))
    }

    // App 在前台（比如面板开着）时也弹横幅
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
