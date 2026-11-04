// 画 1024×1024 的 App 图标：深色计价屏底 + 琥珀色「¥」+ 一段表示当日进度的弧
// 用法：swift scripts/make_icon.swift <输出.png>
import AppKit

guard CommandLine.arguments.count == 2 else {
    print("用法：swift make_icon.swift <输出.png>")
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL

let px = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: rep) else {
    print("无法创建画布")
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let amber = NSColor(calibratedRed: 1.0, green: 0.73, blue: 0.30, alpha: 1)
let amberDeep = NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.12, alpha: 1)

// macOS 图标网格：824 的圆角方块居中，留出投影
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.set()
NSColor.black.setFill()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(
    starting: NSColor(calibratedRed: 0.19, green: 0.17, blue: 0.15, alpha: 1),
    ending: NSColor(calibratedRed: 0.06, green: 0.055, blue: 0.05, alpha: 1)
)?.draw(in: squircle, angle: -90)

NSColor.white.withAlphaComponent(0.07).setStroke()
let rim = NSBezierPath(roundedRect: body.insetBy(dx: 3, dy: 3), xRadius: 183, yRadius: 183)
rim.lineWidth = 6
rim.stroke()

// 进度弧：从左下走到右上，像一天过去了大半
let center = NSPoint(x: 512, y: 500)
let track = NSBezierPath()
track.appendArc(withCenter: center, radius: 300, startAngle: 215, endAngle: -35, clockwise: true)
track.lineWidth = 40
track.lineCapStyle = .round
NSColor.white.withAlphaComponent(0.09).setStroke()
track.stroke()

NSGraphicsContext.saveGraphicsState()
let glow = NSShadow()
glow.shadowBlurRadius = 36
glow.shadowColor = amber.withAlphaComponent(0.7)
glow.set()
let arc = NSBezierPath()
arc.appendArc(withCenter: center, radius: 300, startAngle: 215, endAngle: 40, clockwise: true)
arc.lineWidth = 40
arc.lineCapStyle = .round
amberDeep.setStroke()
arc.stroke()

let yen = NSAttributedString(string: "¥", attributes: [
    .font: NSFont.systemFont(ofSize: 380, weight: .bold),
    .foregroundColor: amber,
])
let size = yen.size()
yen.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2 + 6))
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    print("PNG 编码失败")
    exit(1)
}
do {
    try png.write(to: output)
} catch {
    print("写入失败：\(error.localizedDescription)")
    exit(1)
}
