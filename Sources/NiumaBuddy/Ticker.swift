import Combine
import Foundation

/// 每整秒发一次「现在」；暂停时把时间冻结在按下暂停的那一刻
final class Ticker: ObservableObject {
    @Published private(set) var now = Date()
    @Published private(set) var isPaused = false

    /// 截图模式：时间固定在给定时刻，不起定时器，也不算暂停
    private let isFixed: Bool
    private var timer: Timer?

    /// 计价屏用：非 nil 时金额停在这个时刻，不再跟着钟走
    var frozenDate: Date? { isPaused || isFixed ? now : nil }

    init(fixedAt date: Date? = nil) {
        if let date {
            now = date
            isFixed = true
        } else {
            isFixed = false
            start()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func togglePause() {
        guard !isFixed else { return }
        if isPaused {
            now = Date()
            isPaused = false
            start()
        } else {
            timer?.invalidate()
            timer = nil
            now = Date()
            isPaused = true
        }
    }

    private func start() {
        timer?.invalidate()
        // 对齐到下一个整秒，时钟的秒数才不会忽快忽慢
        let fire = Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.up))
        let timer = Timer(fire: fire, interval: 1, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
        timer.tolerance = 0.05
        // .common：菜单展开、拖动窗口时也照常走
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
