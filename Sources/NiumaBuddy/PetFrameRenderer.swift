import AppKit
import Combine
import SwiftUI

/// 把每一帧桌宠画成图片，直接贴到图层上。
/// 实测一帧不到 1 毫秒；让 SwiftUI 窗口每帧刷新要贵得多（每秒 6 帧就要 4% CPU）。
@MainActor
final class PetFrameRenderer {
    let view = NSView()

    private let pet: PetController
    private let store: ConfigStore
    private let renderer: ImageRenderer<PetFrame>
    private var timer: Timer?
    private var interval: Double?
    private var cancellables = Set<AnyCancellable>()

    init(pet: PetController, store: ConfigStore) {
        self.pet = pet
        self.store = store
        renderer = ImageRenderer(content: PetFrame(state: PetRenderState(activity: .sleeping), t: 0, scale: 1))
        view.wantsLayer = true
        view.layer?.contentsGravity = .resize
        // 换图时不要 Core Animation 默认的淡入淡出
        view.layer?.actions = ["contents": NSNull()]

        pet.$motion
            .combineLatest(pet.$isHidden)
            .sink { [weak self] motion, hidden in
                MainActor.assumeIsolated { self?.schedule(hidden ? nil : motion.frameInterval) }
            }
            .store(in: &cancellables)
        store.$config
            .map { [$0.petSize.rawValue, $0.petSkin.rawValue] }
            .removeDuplicates()
            // @Published 在新值写进去之前就发通知，等这一轮跑完再画，才读得到新的大小和形象
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.renderFrame() }
            }
            .store(in: &cancellables)
    }

    /// nil = 停下（窗口藏起来或被挡住）
    private func schedule(_ newInterval: Double?) {
        guard newInterval != interval else { return }
        timer?.invalidate()
        timer = nil
        interval = newInterval
        guard let newInterval else { return }
        let timer = Timer(timeInterval: newInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.renderFrame() }
        }
        timer.tolerance = newInterval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        renderFrame()
    }

    func renderFrame() {
        let now = Date()
        renderer.content = PetFrame(state: pet.renderState(at: now), t: now.timeIntervalSinceReferenceDate,
                                    scale: store.config.petSize.scale)
        renderer.scale = view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        view.layer?.contents = renderer.cgImage
    }
}
