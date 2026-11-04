import SwiftUI

/// 只有桌宠本身的一帧画面（实时显示时由 PetFrameRenderer 画成图片）
struct PetFrame: View {
    let state: PetRenderState
    let t: Double
    let scale: CGFloat

    var body: some View {
        Canvas { gc, _ in
            gc.scaleBy(x: scale, y: scale)
            PetArt.draw(&gc, state, t: t)
        }
        .frame(width: PetArt.canvasSize.width * scale, height: PetArt.canvasSize.height * scale)
    }
}

/// 桌宠 + 头顶的气泡，截图用
struct PetComposite: View {
    let state: PetRenderState
    let t: Double
    let scale: CGFloat
    let bubble: String?

    var body: some View {
        ZStack(alignment: .top) {
            PetFrame(state: state, t: t, scale: scale)
            if let bubble {
                PetBubbleSlot(text: bubble, scale: scale)
            }
        }
        .frame(width: PetArt.canvasSize.width * scale, height: PetArt.canvasSize.height * scale, alignment: .top)
    }
}

/// 气泡摆在桌宠头顶：底边固定，字多了往上长
struct PetBubbleSlot: View {
    let text: String
    let scale: CGFloat

    var body: some View {
        let width = PetArt.canvasSize.width * scale
        PetBubbleView(text: text)
            .frame(maxWidth: width - 8)
            .frame(width: width, height: PetArt.bubbleBottom * scale, alignment: .bottom)
    }
}

struct PetBubbleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(red: 0.25, green: 0.15, blue: 0.05))
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 6 + BubbleShape.tail)
            .background(BubbleShape().fill(Color(red: 1.0, green: 0.98, blue: 0.92)))
            .overlay(BubbleShape().stroke(PetArt.coinLo.opacity(0.55), lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }
}

/// 圆角气泡，底边正中伸出一个小尖角，一笔画完边框才不会在尖角处断开
struct BubbleShape: Shape {
    static let tail: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 10
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - Self.tail)
        var p = Path()
        p.move(to: CGPoint(x: body.minX + radius, y: body.minY))
        p.addLine(to: CGPoint(x: body.maxX - radius, y: body.minY))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.minY + radius), radius: radius)
        p.addLine(to: CGPoint(x: body.maxX, y: body.maxY - radius))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX - radius, y: body.maxY), radius: radius)
        p.addLine(to: CGPoint(x: rect.midX + 6, y: body.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX - 6, y: body.maxY))
        p.addLine(to: CGPoint(x: body.minX + radius, y: body.maxY))
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY - radius), radius: radius)
        p.addLine(to: CGPoint(x: body.minX, y: body.minY + radius))
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX + radius, y: body.minY), radius: radius)
        p.closeSubpath()
        return p
    }
}

struct PetActions {
    var tap: () -> Void
    var doubleTap: () -> Void
    var dragChanged: () -> Void
    var dragEnded: () -> Void
    var toggleToilet: () -> Void
    var drankWater: () -> Void
    var openSettings: () -> Void
    var hide: () -> Void
}

/// 盖在桌宠图层上面的一层：气泡 + 可点击区域。只在说话、状态变化时刷新，平时不动
struct PetOverlay: View {
    // 不直接观察 FunStore：它每秒都会变，会让整个窗口每秒重排一次，白白耗电
    @ObservedObject var pet: PetController
    @ObservedObject var store: ConfigStore
    let actions: PetActions

    var body: some View {
        let scale = store.config.petSize.scale
        let hit = PetArt.hitRect
        ZStack(alignment: .topLeading) {
            Color.clear
            if let bubble = pet.bubble, !pet.isHidden {
                PetBubbleSlot(text: bubble.text, scale: scale)
            }
            Color.clear
                .frame(width: hit.width * scale, height: hit.height * scale)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: actions.doubleTap)
                .onTapGesture(perform: actions.tap)
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { _ in actions.dragChanged() }
                        .onEnded { _ in actions.dragEnded() }
                )
                .contextMenu {
                    Button("打开面板", action: actions.doubleTap)
                    Button(pet.onToilet ? "结束带薪如厕" : "开始带薪如厕", action: actions.toggleToilet)
                    Button("我喝了一杯水", action: actions.drankWater)
                    Divider()
                    Button("设置…", action: actions.openSettings)
                    Button("隐藏\(store.config.petSkin.name)", action: actions.hide)
                }
                .padding(.leading, hit.minX * scale)
                .padding(.top, hit.minY * scale)
        }
        .frame(width: PetArt.canvasSize.width * scale, height: PetArt.canvasSize.height * scale, alignment: .topLeading)
    }
}
