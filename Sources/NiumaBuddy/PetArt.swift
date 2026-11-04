import SwiftUI

/// 短暂的提醒动作，盖在当前状态上播十几秒
enum PetEvent: Equatable {
    case stretch   // 久坐提醒：伸懒腰
    case drink     // 喝水提醒：举杯喝水
}

/// 画一帧桌宠需要知道的一切
struct PetRenderState {
    var activity: PetActivity
    var event: PetEvent?
    var outfit = PetOutfit()
    /// 跳一下的进度 0…1
    var hop: Double?
    /// 被鼠标拎起来了
    var held = false
    var walking = false
    var facing: CGFloat = 1
    var talking = false
    /// 每枚硬币已经飞了几秒
    var coinPops: [Double] = []
    var coinStep = 1
    var skin = PetSkin.coin
}

/// 小铜板：一枚会走路的方孔铜钱，方孔就是它的嘴。全部用代码画，坐标按 240×200 的画布设计
enum PetArt {
    static let canvasSize = CGSize(width: 240, height: 200)
    /// 能点到桌宠的区域（其余透明部分鼠标直接穿过去）
    static let hitRect = CGRect(x: 78, y: 84, width: 84, height: 98)
    /// 气泡底边的位置
    static let bubbleBottom: CGFloat = 82

    static let ground: CGFloat = 178
    static let cx: CGFloat = 120
    static let cy: CGFloat = 128
    static let r: CGFloat = 30

    static let ink = Color(red: 0.32, green: 0.19, blue: 0.07)
    static let coinHi = Color(red: 1.0, green: 0.88, blue: 0.55)
    static let coinMid = Color(red: 0.99, green: 0.71, blue: 0.25)
    static let coinLo = Color(red: 0.85, green: 0.50, blue: 0.12)
    static let blush = Color(red: 1.0, green: 0.46, blue: 0.42)
    static let wood = Color(red: 0.66, green: 0.46, blue: 0.27)
    static let woodDark = Color(red: 0.50, green: 0.33, blue: 0.19)
    static let shirtBlue = Color(red: 0.30, green: 0.56, blue: 0.96)
    static let capBlue = Color(red: 0.38, green: 0.50, blue: 0.90)
    static let bagGreen = Color(red: 0.36, green: 0.62, blue: 0.47)

    // MARK: - 姿势

    enum Eyes { case open, closed, happy, tired, wide, cool, focused, shifty }
    enum Arms { case down, typing, wave, bowl, roll, suitcase, shrug, flail, bag, stretch, drink }

    struct Look {
        var eyes = Eyes.open
        var arms = Arms.down
        var mouth = CGSize(width: 8, height: 6)
        /// 画哪个状态的道具；nil = 不画道具（被拎起来、做提醒动作时）
        var scene: PetActivity?
        var nightcap = false
        var backpackWorn = false
        var tilt: Double = 0
    }

    static func look(_ s: PetRenderState, t: Double) -> Look {
        var l = Look()
        if s.held {
            l.eyes = .wide
            l.arms = .flail
            l.mouth = CGSize(width: 7, height: 8)
            return l
        }
        if let event = s.event, s.activity != .toilet {
            switch event {
            case .stretch:
                l.eyes = .happy
                l.arms = .stretch
                l.mouth = CGSize(width: 9, height: 6)
            case .drink:
                l.eyes = .closed
                l.arms = .drink
                l.mouth = CGSize(width: 5, height: 4)
            }
            return l
        }
        l.scene = s.activity
        switch s.activity {
        case .sleeping, .napping:
            l.eyes = .closed
            l.mouth = CGSize(width: 6, height: 3.5)
            l.nightcap = true
            l.tilt = -8
        case .working:
            l.eyes = .focused
            l.arms = .typing
            l.mouth = CGSize(width: 7, height: 5)
        case .overtime:
            l.eyes = .tired
            l.arms = .typing
            l.mouth = CGSize(width: 7, height: 3)
        case .packing:
            l.eyes = .shifty
            l.arms = .bag
            l.mouth = CGSize(width: 8, height: 6)
        case .eating:
            l.eyes = .happy
            l.arms = .bowl
            l.mouth = CGSize(width: 8, height: 3 + 5 * abs(sin(t * 6)))
        case .waving:
            l.eyes = .happy
            l.arms = .wave
            l.mouth = CGSize(width: 10, height: 7)
            l.backpackWorn = true
        case .resting:
            l.eyes = .closed
            l.mouth = CGSize(width: 7, height: 4)
            l.nightcap = true
        case .vacation:
            l.eyes = .cool
            l.arms = .suitcase
            l.mouth = CGSize(width: 10, height: 6)
        case .toilet:
            l.eyes = .wide
            l.arms = .roll
            l.mouth = CGSize(width: 7, height: 9)
        case .confused:
            l.eyes = .open
            l.arms = .shrug
            l.mouth = CGSize(width: 6, height: 3)
        }
        if s.talking && s.activity != .eating {
            l.mouth.height = max(l.mouth.height, 4 + 5 * abs(sin(t * 9)))
        }
        return l
    }

    static func bodyOffset(_ s: PetRenderState, t: Double) -> CGFloat {
        if s.held { return -8 }
        var dy: CGFloat
        if s.walking {
            dy = -abs(sin(t * 9)) * 3
        } else if s.event == .stretch {
            dy = -2 - abs(sin(t * 2.2)) * 3
        } else {
            switch s.activity {
            case .sleeping, .napping, .resting: dy = sin(t * 2 * .pi / 4) * 1.2
            case .working: dy = sin(t * 9) * 0.5
            case .overtime: dy = sin(t * 3) * 0.6
            case .packing: dy = -abs(sin(t * 5)) * 3
            case .waving: dy = -abs(sin(t * 3.2)) * 2
            case .toilet: dy = sin(t * 14) * 0.8
            default: dy = sin(t * 2 * .pi / 3) * 1.2
            }
        }
        if let hop = s.hop { dy -= sin(hop * .pi) * 16 }
        return dy
    }

    // MARK: - 总装

    static func draw(_ gc: inout GraphicsContext, _ s: PetRenderState, t: Double) {
        if s.skin.isCat {
            drawCat(&gc, s, t: t)
            return
        }
        let l = look(s, t: t)
        let dy = bodyOffset(s, t: t)

        drawShadow(&gc, lift: max(0, -dy), faint: s.held)

        // 身后的布景
        switch l.scene {
        case .toilet: drawWCSign(&gc)
        case .packing, .resting: drawBackpack(&gc, rect: CGRect(x: 158, y: 150, width: 24, height: 28))
        default: break
        }
        if let prop = s.outfit.prop, let scene = l.scene, [.packing, .waving, .resting].contains(scene) {
            drawProp(&gc, prop, base: CGPoint(x: 62, y: ground))
        }

        // 小铜板本体：可以左右翻转（散步时），再整体上下浮动
        var flip = gc
        if s.facing < 0 {
            flip.translateBy(x: cx * 2, y: 0)
            flip.scaleBy(x: -1, y: 1)
        }
        if l.scene == .vacation { drawSuitcase(&flip) }
        var pet = flip
        pet.translateBy(x: 0, y: dy)
        if l.tilt != 0 {
            pet.translateBy(x: cx, y: ground)
            pet.rotate(by: .degrees(l.tilt))
            pet.translateBy(x: -cx, y: -ground)
        }
        if l.backpackWorn {
            pet.fill(Path(roundedRect: CGRect(x: cx - 40, y: cy - 10, width: 20, height: 32), cornerRadius: 6), with: .color(bagGreen))
        }
        drawLegs(&pet, s, t: t)
        drawBody(&pet)
        if s.outfit.shirt { drawShirt(&pet) }
        if l.backpackWorn {
            var strap = Path()
            strap.move(to: CGPoint(x: cx - 26, y: cy - 14))
            strap.addQuadCurve(to: CGPoint(x: cx - 25, y: cy + 16), control: CGPoint(x: cx - 20, y: cy + 1))
            pet.stroke(strap, with: .color(bagGreen), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        drawFace(&pet, l, t: t)
        if l.nightcap { drawNightcap(&pet) }
        drawArms(&pet, l, t: t, shirt: s.outfit.shirt)
        switch l.arms {
        case .bowl: drawBowl(&pet, t: t)
        case .roll: drawToiletRoll(&pet)
        case .drink: drawGlass(&pet, t: t)
        default: break
        }

        // 身前的布景
        if l.scene == .working || l.scene == .overtime {
            drawDesk(&gc, dim: l.scene == .overtime)
            if let prop = s.outfit.prop { drawProp(&gc, prop, base: CGPoint(x: 80, y: 156)) }
        }

        // 飘在空中的小东西
        switch l.scene {
        case .sleeping, .napping: drawZzz(&gc, t: t, dy: dy)
        case .resting: drawNight(&gc, t: t)
        case .confused: drawQuestion(&gc, t: t)
        case .packing: drawClock(&gc, t: t)
        case .overtime, .toilet: drawSweat(&gc, t: t, dy: dy)
        case .working: drawCoins(&gc, s, dy: dy)
        default: break
        }
        if l.arms == .stretch { drawSparkles(&gc, t: t, dy: dy) }
    }

    // MARK: - 身体

    static func drawShadow(_ gc: inout GraphicsContext, lift: CGFloat, faint: Bool, width: CGFloat = 48) {
        let w = width - min(lift, 16) * 1.2
        gc.fill(Path(ellipseIn: CGRect(x: cx - w / 2, y: ground - 3.5, width: w, height: 7)),
                with: .color(.black.opacity(faint ? 0.08 : 0.16)))
    }

    private static func drawLegs(_ gc: inout GraphicsContext, _ s: PetRenderState, t: Double) {
        let top = cy + r - 7
        var swing: CGFloat = 0
        if s.walking { swing = sin(t * 9) * 4 } else if s.held { swing = sin(t * 7) * 5 }
        for (i, x) in [cx - 10, cx + 10].enumerated() {
            let foot = CGPoint(x: x + (i == 0 ? swing : -swing), y: ground - 3)
            var leg = Path()
            leg.move(to: CGPoint(x: x, y: top))
            leg.addLine(to: foot)
            gc.stroke(leg, with: .color(ink), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            if s.outfit.shoes {
                let shoe = CGRect(x: foot.x - 5, y: foot.y - 4, width: 14, height: 7)
                gc.fill(Path(roundedRect: shoe, cornerRadius: 3.5), with: .color(Color(red: 0.92, green: 0.27, blue: 0.25)))
                var sole = Path()
                sole.move(to: CGPoint(x: shoe.minX + 1.5, y: shoe.maxY - 1.2))
                sole.addLine(to: CGPoint(x: shoe.maxX - 1.5, y: shoe.maxY - 1.2))
                gc.stroke(sole, with: .color(.white), lineWidth: 1.6)
                gc.fill(Path(ellipseIn: CGRect(x: shoe.maxX - 5.5, y: shoe.minY + 1.5, width: 3.5, height: 2.5)), with: .color(.white.opacity(0.9)))
            } else {
                gc.fill(Path(ellipseIn: CGRect(x: foot.x - 4, y: foot.y - 2.5, width: 10, height: 5.5)), with: .color(ink))
            }
        }
    }

    private static func drawBody(_ gc: inout GraphicsContext) {
        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        gc.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [coinHi, coinMid, coinLo]),
            center: CGPoint(x: cx - 10, y: cy - 12), startRadius: 2, endRadius: r * 1.6))
        gc.stroke(Path(ellipseIn: rect.insetBy(dx: 4.5, dy: 4.5)), with: .color(coinLo.opacity(0.7)), lineWidth: 1.6)
        gc.stroke(Path(ellipseIn: rect), with: .color(ink.opacity(0.55)), lineWidth: 1.4)
        var shine = Path()
        shine.addArc(center: CGPoint(x: cx, y: cy), radius: r - 9, startAngle: .degrees(200), endAngle: .degrees(245), clockwise: false)
        gc.stroke(shine, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    }

    private static func drawShirt(_ gc: inout GraphicsContext) {
        var shirt = gc
        shirt.clip(to: Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)))
        shirt.fill(Path(CGRect(x: cx - r, y: cy + 15, width: r * 2, height: r)), with: .color(shirtBlue))
        var collar = Path()
        collar.move(to: CGPoint(x: cx - 7, y: cy + 15))
        collar.addLine(to: CGPoint(x: cx, y: cy + 21))
        collar.addLine(to: CGPoint(x: cx + 7, y: cy + 15))
        shirt.stroke(collar, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
    }

    private static func drawFace(_ gc: inout GraphicsContext, _ l: Look, t: Double) {
        let eyeY = cy - 6
        let blinking = t.truncatingRemainder(dividingBy: 4.3) < 0.13
        var lookX: CGFloat = 0, lookY: CGFloat = 0
        switch l.eyes {
        case .focused: lookX = 1.2; lookY = 2
        case .shifty: lookX = sin(t * 2.6) * 2.2
        default: break
        }

        for x in [cx - 10, cx + 10] {
            switch l.eyes {
            case .open, .focused, .shifty, .wide:
                if blinking {
                    var lid = Path()
                    lid.move(to: CGPoint(x: x - 3.5, y: eyeY + lookY))
                    lid.addLine(to: CGPoint(x: x + 3.5, y: eyeY + lookY))
                    gc.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                } else {
                    let w: CGFloat = l.eyes == .wide ? 7 : 6
                    let h: CGFloat = l.eyes == .wide ? 9 : 8
                    gc.fill(Path(ellipseIn: CGRect(x: x + lookX - w / 2, y: eyeY + lookY - h / 2, width: w, height: h)), with: .color(ink))
                    gc.fill(Path(ellipseIn: CGRect(x: x + lookX - 2.4, y: eyeY + lookY - 3.2, width: 2.6, height: 2.6)), with: .color(.white))
                }
            case .closed:
                var arc = Path()
                arc.move(to: CGPoint(x: x - 4, y: eyeY - 0.5))
                arc.addQuadCurve(to: CGPoint(x: x + 4, y: eyeY - 0.5), control: CGPoint(x: x, y: eyeY + 3.5))
                gc.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            case .happy:
                var arc = Path()
                arc.move(to: CGPoint(x: x - 4, y: eyeY + 1.5))
                arc.addQuadCurve(to: CGPoint(x: x + 4, y: eyeY + 1.5), control: CGPoint(x: x, y: eyeY - 4))
                gc.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
            case .tired:
                // 半睁的眼睛 + 往外耷拉的眼皮 + 黑眼圈；眼皮要外低内高，反过来就成了生气
                let outerLow = x < cx
                let left = CGPoint(x: x - 4.4, y: outerLow ? eyeY + 0.6 : eyeY - 2.4)
                let right = CGPoint(x: x + 4.4, y: outerLow ? eyeY - 2.4 : eyeY + 0.6)
                var below = Path()
                below.move(to: left)
                below.addLine(to: right)
                below.addLine(to: CGPoint(x: x + 6, y: eyeY + 8))
                below.addLine(to: CGPoint(x: x - 6, y: eyeY + 8))
                below.closeSubpath()
                var pupil = gc
                pupil.clip(to: below)
                pupil.fill(Path(ellipseIn: CGRect(x: x - 3, y: eyeY - 3, width: 6, height: 7)), with: .color(ink))
                var lid = Path()
                lid.move(to: left)
                lid.addLine(to: right)
                gc.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                var bag = Path()
                bag.move(to: CGPoint(x: x - 3.5, y: eyeY + 5.5))
                bag.addQuadCurve(to: CGPoint(x: x + 3.5, y: eyeY + 5.5), control: CGPoint(x: x, y: eyeY + 8))
                gc.stroke(bag, with: .color(Color(red: 0.55, green: 0.40, blue: 0.62).opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            case .cool:
                break
            }
        }
        if l.eyes == .cool { drawSunglasses(&gc, eyeY: eyeY) }

        let cheek = l.eyes == .tired ? 0.18 : 0.45
        for x in [cx - 18, cx + 18] {
            gc.fill(Path(ellipseIn: CGRect(x: x - 4, y: cy + 1, width: 8, height: 4.5)), with: .color(blush.opacity(cheek)))
        }

        // 方孔就是嘴
        let m = l.mouth
        let hole = CGRect(x: cx - m.width / 2, y: cy + 9 - m.height / 2, width: m.width, height: m.height)
        gc.fill(Path(roundedRect: hole.insetBy(dx: -1.6, dy: -1.6), cornerRadius: 2.6), with: .color(coinLo.opacity(0.55)))
        gc.fill(Path(roundedRect: hole, cornerRadius: 1.6), with: .color(Color(red: 0.38, green: 0.18, blue: 0.05)))
    }

    private static func drawSunglasses(_ gc: inout GraphicsContext, eyeY: CGFloat) {
        let frame = Color(white: 0.12)
        for x in [cx - 10, cx + 10] {
            let lens = CGRect(x: x - 7, y: eyeY - 5, width: 14, height: 9)
            gc.fill(Path(roundedRect: lens, cornerRadius: 3.5), with: .color(frame.opacity(0.94)))
            var shine = Path()
            shine.move(to: CGPoint(x: lens.minX + 3, y: lens.minY + 2.5))
            shine.addLine(to: CGPoint(x: lens.minX + 6.5, y: lens.minY + 2.5))
            gc.stroke(shine, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        var rim = Path()
        rim.move(to: CGPoint(x: cx - 3, y: eyeY - 2))
        rim.addLine(to: CGPoint(x: cx + 3, y: eyeY - 2))
        rim.move(to: CGPoint(x: cx - 17, y: eyeY - 3))
        rim.addLine(to: CGPoint(x: cx - 27, y: eyeY - 6))
        rim.move(to: CGPoint(x: cx + 17, y: eyeY - 3))
        rim.addLine(to: CGPoint(x: cx + 27, y: eyeY - 6))
        gc.stroke(rim, with: .color(frame), lineWidth: 1.6)
    }

    private static func drawNightcap(_ gc: inout GraphicsContext) {
        var cap = Path()
        cap.move(to: CGPoint(x: cx - 23, y: cy - 17))
        cap.addQuadCurve(to: CGPoint(x: cx + 20, y: cy - 20), control: CGPoint(x: cx - 2, y: cy - 31))
        cap.addQuadCurve(to: CGPoint(x: cx - 34, y: cy - 44), control: CGPoint(x: cx + 6, y: cy - 52))
        cap.addQuadCurve(to: CGPoint(x: cx - 23, y: cy - 17), control: CGPoint(x: cx - 31, y: cy - 30))
        gc.fill(cap, with: .color(capBlue))
        var band = Path()
        band.move(to: CGPoint(x: cx - 23, y: cy - 17))
        band.addQuadCurve(to: CGPoint(x: cx + 20, y: cy - 20), control: CGPoint(x: cx - 2, y: cy - 31))
        gc.stroke(band, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        gc.fill(Path(ellipseIn: CGRect(x: cx - 39, y: cy - 49, width: 9, height: 9)), with: .color(.white))
    }

    private static func drawArms(_ gc: inout GraphicsContext, _ l: Look, t: Double, shirt: Bool) {
        let raised: Set<Arms> = [.stretch, .shrug, .flail, .wave]
        let shoulderY = raised.contains(l.arms) ? cy - 2 : cy + 5
        let left = CGPoint(x: cx - 26, y: shoulderY), right = CGPoint(x: cx + 26, y: shoulderY)
        let sway = sin(t * 2) * 1.5
        let lh: CGPoint, rh: CGPoint
        switch l.arms {
        case .down:
            lh = CGPoint(x: cx - 34, y: cy + 19 + sway); rh = CGPoint(x: cx + 34, y: cy + 19 - sway)
        case .typing:
            // 平时只有每秒 8 帧，频率太高会糊成乱抖
            let tap = sin(t * 6.5) * 1.6
            lh = CGPoint(x: cx - 13, y: cy + 5 + tap); rh = CGPoint(x: cx + 13, y: cy + 5 - tap)
        case .wave:
            lh = CGPoint(x: cx - 34, y: cy + 19); rh = CGPoint(x: cx + 40 + sin(t * 7) * 5, y: cy - 19)
        case .bowl:
            lh = CGPoint(x: cx - 17, y: cy + 20); rh = CGPoint(x: cx + 16, y: cy + 16)
        case .roll:
            lh = CGPoint(x: cx - 33, y: cy + 16); rh = CGPoint(x: cx + 31, y: cy + 10)
        case .suitcase:
            lh = CGPoint(x: cx - 34, y: cy + 19 + sway); rh = CGPoint(x: cx + 44, y: cy + 1)
        case .shrug:
            lh = CGPoint(x: cx - 38, y: cy - 4); rh = CGPoint(x: cx + 38, y: cy - 4)
        case .flail:
            let f = sin(t * 10) * 5
            lh = CGPoint(x: cx - 38, y: cy - 13 + f); rh = CGPoint(x: cx + 38, y: cy - 13 - f)
        case .bag:
            lh = CGPoint(x: cx - 34, y: cy + 19 + sway); rh = CGPoint(x: cx + 40, y: cy + 23)
        case .stretch:
            let s = sin(t * 2.2) * 2
            lh = CGPoint(x: cx - 24, y: cy - 46 + s); rh = CGPoint(x: cx + 24, y: cy - 46 + s)
        case .drink:
            lh = CGPoint(x: cx - 33, y: cy + 18); rh = CGPoint(x: cx + 13, y: cy + 13)
        }
        for (shoulder, hand) in [(left, lh), (right, rh)] {
            var arm = Path()
            arm.move(to: shoulder)
            arm.addLine(to: hand)
            gc.stroke(arm, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            if shirt {
                let dx = hand.x - shoulder.x, dy = hand.y - shoulder.y
                let len = max(sqrt(dx * dx + dy * dy), 1)
                var sleeve = Path()
                sleeve.move(to: shoulder)
                sleeve.addLine(to: CGPoint(x: shoulder.x + dx / len * 7, y: shoulder.y + dy / len * 7))
                gc.stroke(sleeve, with: .color(shirtBlue), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
            }
            let palm = CGRect(x: hand.x - 3.6, y: hand.y - 3.6, width: 7.2, height: 7.2)
            gc.fill(Path(ellipseIn: palm), with: .color(coinMid))
            gc.stroke(Path(ellipseIn: palm), with: .color(ink), lineWidth: 1.2)
        }
    }

    // MARK: - 拿在手里的东西

    private static func drawBowl(_ gc: inout GraphicsContext, t: Double) {
        let rim = cy + 17
        var noodles = Path()
        noodles.move(to: CGPoint(x: cx - 15, y: rim))
        noodles.addQuadCurve(to: CGPoint(x: cx - 5, y: rim), control: CGPoint(x: cx - 10, y: rim - 6))
        noodles.addQuadCurve(to: CGPoint(x: cx + 5, y: rim), control: CGPoint(x: cx, y: rim - 7))
        noodles.addQuadCurve(to: CGPoint(x: cx + 15, y: rim), control: CGPoint(x: cx + 10, y: rim - 6))
        noodles.closeSubpath()
        gc.fill(noodles, with: .color(Color(red: 1.0, green: 0.87, blue: 0.52)))

        var bowl = Path()
        bowl.move(to: CGPoint(x: cx - 21, y: rim))
        bowl.addLine(to: CGPoint(x: cx + 21, y: rim))
        bowl.addQuadCurve(to: CGPoint(x: cx - 21, y: rim), control: CGPoint(x: cx, y: rim + 30))
        gc.fill(bowl, with: .color(Color(white: 0.97)))
        gc.stroke(bowl, with: .color(ink.opacity(0.6)), lineWidth: 1.2)
        var stripe = Path()
        stripe.move(to: CGPoint(x: cx - 19, y: rim + 4))
        stripe.addQuadCurve(to: CGPoint(x: cx + 19, y: rim + 4), control: CGPoint(x: cx, y: rim + 8))
        gc.stroke(stripe, with: .color(Color(red: 0.30, green: 0.50, blue: 0.85)), lineWidth: 1.8)

        let lift = sin(t * 6) * 2
        var sticks = Path()
        sticks.move(to: CGPoint(x: cx + 24, y: cy + 24))
        sticks.addLine(to: CGPoint(x: cx + 4, y: cy + 9 + lift))
        sticks.move(to: CGPoint(x: cx + 26, y: cy + 21))
        sticks.addLine(to: CGPoint(x: cx + 6, y: cy + 7 + lift))
        gc.stroke(sticks, with: .color(woodDark), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

        // 热气从碗沿两边往外飘，别糊到脸上
        for (i, side) in [CGFloat(-1), 1].enumerated() {
            let p = (t / 1.8 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
            let x = cx + side * (24 + p * 6)
            let y = rim - 2 - p * 10
            var steam = Path()
            steam.move(to: CGPoint(x: x, y: y + 4))
            steam.addQuadCurve(to: CGPoint(x: x, y: y - 4), control: CGPoint(x: x + 3 * side, y: y))
            gc.stroke(steam, with: .color(.white.opacity(0.9 * sin(p * .pi))), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
    }

    static func drawToiletRoll(_ gc: inout GraphicsContext) {
        let roll = CGRect(x: cx + 26, y: cy + 2, width: 11, height: 14)
        var tail = Path()
        tail.move(to: CGPoint(x: roll.maxX - 1, y: roll.maxY - 3))
        tail.addQuadCurve(to: CGPoint(x: roll.maxX + 3, y: roll.maxY + 13), control: CGPoint(x: roll.maxX + 6, y: roll.maxY + 4))
        gc.stroke(tail, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        gc.fill(Path(roundedRect: roll, cornerRadius: 2.5), with: .color(.white))
        gc.stroke(Path(roundedRect: roll, cornerRadius: 2.5), with: .color(Color(white: 0.6)), lineWidth: 1)
        gc.fill(Path(ellipseIn: CGRect(x: roll.minX + 3.5, y: roll.minY + 1, width: 4, height: 2.6)), with: .color(Color(white: 0.7)))
    }

    static func drawGlass(_ gc: inout GraphicsContext, t: Double) {
        var g = gc
        g.translateBy(x: cx + 14, y: cy + 4)
        g.rotate(by: .degrees(-35 + sin(t * 3) * 4))
        let glass = CGRect(x: -8, y: -13, width: 16, height: 22)
        g.fill(Path(roundedRect: glass, cornerRadius: 2.5), with: .color(.white.opacity(0.55)))
        g.fill(Path(roundedRect: CGRect(x: -7, y: -4, width: 14, height: 12), cornerRadius: 2), with: .color(Color(red: 0.35, green: 0.65, blue: 1.0)))
        g.stroke(Path(roundedRect: glass, cornerRadius: 2.5), with: .color(Color(red: 0.25, green: 0.50, blue: 0.85)), lineWidth: 1.5)
        var shine = Path()
        shine.move(to: CGPoint(x: -5, y: -10))
        shine.addLine(to: CGPoint(x: -5, y: 5))
        g.stroke(shine, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    // MARK: - 布景

    static func drawDesk(_ gc: inout GraphicsContext, dim: Bool) {
        gc.fill(Path(roundedRect: CGRect(x: 64, y: 156, width: 132, height: 6), cornerRadius: 2), with: .color(wood))
        gc.fill(Path(CGRect(x: 72, y: 162, width: 4, height: 16)), with: .color(woodDark))
        gc.fill(Path(CGRect(x: 184, y: 162, width: 4, height: 16)), with: .color(woodDark))

        let lid = CGRect(x: 88, y: 133, width: 64, height: 24)
        gc.fill(Path(roundedRect: lid, cornerRadius: 4), with: .linearGradient(
            Gradient(colors: [Color(white: 0.88), Color(white: 0.70)]),
            startPoint: CGPoint(x: lid.midX, y: lid.minY), endPoint: CGPoint(x: lid.midX, y: lid.maxY)))
        gc.stroke(Path(roundedRect: lid, cornerRadius: 4), with: .color(Color(white: 0.48)), lineWidth: 1)
        let logo = CGRect(x: lid.midX - 4.5, y: lid.midY - 4.5, width: 9, height: 9)
        gc.fill(Path(ellipseIn: logo), with: .color(coinMid.opacity(dim ? 0.35 : 0.95)))
        gc.fill(Path(CGRect(x: lid.midX - 1.2, y: lid.midY - 1.2, width: 2.4, height: 2.4)), with: .color(Color(white: 0.75)))

        drawPiggy(&gc)
    }

    private static func drawPiggy(_ gc: inout GraphicsContext) {
        let pink = Color(red: 1.0, green: 0.75, blue: 0.80)
        let dark = Color(red: 0.86, green: 0.52, blue: 0.60)
        gc.fill(Path(CGRect(x: 166, y: 152, width: 4, height: 4)), with: .color(dark))
        gc.fill(Path(CGRect(x: 182, y: 152, width: 4, height: 4)), with: .color(dark))
        var tail = Path()
        tail.move(to: CGPoint(x: 163, y: 146))
        tail.addQuadCurve(to: CGPoint(x: 158, y: 144), control: CGPoint(x: 159, y: 149))
        tail.addQuadCurve(to: CGPoint(x: 160, y: 141), control: CGPoint(x: 157, y: 141))
        gc.stroke(tail, with: .color(dark), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        let body = CGRect(x: 162, y: 137, width: 28, height: 18)
        gc.fill(Path(ellipseIn: body), with: .color(pink))
        gc.stroke(Path(ellipseIn: body), with: .color(dark), lineWidth: 1)
        var ear = Path()
        ear.move(to: CGPoint(x: 179, y: 139))
        ear.addLine(to: CGPoint(x: 183, y: 132))
        ear.addLine(to: CGPoint(x: 186, y: 140))
        ear.closeSubpath()
        gc.fill(ear, with: .color(pink))
        gc.stroke(ear, with: .color(dark), lineWidth: 1)
        let snout = CGRect(x: 187, y: 142, width: 7, height: 7)
        gc.fill(Path(ellipseIn: snout), with: .color(Color(red: 1.0, green: 0.66, blue: 0.74)))
        gc.stroke(Path(ellipseIn: snout), with: .color(dark), lineWidth: 0.8)
        for x in [189.3, 191.7] {
            gc.fill(Path(ellipseIn: CGRect(x: x - 0.7, y: 145, width: 1.4, height: 1.4)), with: .color(dark))
        }
        gc.fill(Path(ellipseIn: CGRect(x: 181, y: 143, width: 2.4, height: 2.4)), with: .color(ink))
        var slot = Path()
        slot.move(to: CGPoint(x: 171, y: 138.5))
        slot.addLine(to: CGPoint(x: 178, y: 138.5))
        gc.stroke(slot, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    static func drawBackpack(_ gc: inout GraphicsContext, rect: CGRect) {
        var handle = Path()
        handle.move(to: CGPoint(x: rect.midX - 5, y: rect.minY + 2))
        handle.addQuadCurve(to: CGPoint(x: rect.midX + 5, y: rect.minY + 2), control: CGPoint(x: rect.midX, y: rect.minY - 7))
        gc.stroke(handle, with: .color(bagGreen.opacity(0.85)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        gc.fill(Path(roundedRect: rect, cornerRadius: 7), with: .color(bagGreen))
        let pocket = CGRect(x: rect.minX + 4, y: rect.midY + 1, width: rect.width - 8, height: rect.height / 3)
        gc.fill(Path(roundedRect: pocket, cornerRadius: 3), with: .color(.white.opacity(0.22)))
        gc.stroke(Path(roundedRect: rect, cornerRadius: 7), with: .color(ink.opacity(0.35)), lineWidth: 1)
    }

    static func drawSuitcase(_ gc: inout GraphicsContext) {
        var handle = Path()
        handle.move(to: CGPoint(x: 163, y: 144))
        handle.addLine(to: CGPoint(x: 163, y: 128))
        handle.addLine(to: CGPoint(x: 177, y: 128))
        handle.addLine(to: CGPoint(x: 177, y: 144))
        gc.stroke(handle, with: .color(Color(white: 0.55)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        let body = CGRect(x: 158, y: 143, width: 24, height: 32)
        let teal = Color(red: 0.20, green: 0.63, blue: 0.67)
        gc.fill(Path(roundedRect: body, cornerRadius: 4), with: .color(teal))
        gc.stroke(Path(roundedRect: body, cornerRadius: 4), with: .color(ink.opacity(0.35)), lineWidth: 1)
        var stripes = Path()
        for x in [165.0, 175.0] {
            stripes.move(to: CGPoint(x: x, y: body.minY + 3))
            stripes.addLine(to: CGPoint(x: x, y: body.maxY - 3))
        }
        gc.stroke(stripes, with: .color(.white.opacity(0.35)), lineWidth: 1.4)
        gc.fill(Path(ellipseIn: CGRect(x: 166, y: 151, width: 8, height: 8)), with: .color(Color(red: 1.0, green: 0.82, blue: 0.30)))
        for x in [162.0, 178.0] {
            gc.fill(Path(ellipseIn: CGRect(x: x - 2.2, y: 174, width: 4.4, height: 4.4)), with: .color(ink))
        }
    }

    static func drawWCSign(_ gc: inout GraphicsContext) {
        var post = Path()
        post.move(to: CGPoint(x: 66, y: 138))
        post.addLine(to: CGPoint(x: 66, y: ground))
        gc.stroke(post, with: .color(woodDark), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        let sign = CGRect(x: 50, y: 122, width: 32, height: 17)
        gc.fill(Path(roundedRect: sign, cornerRadius: 3.5), with: .color(Color(red: 0.27, green: 0.52, blue: 0.92)))
        var text = gc.resolve(Text("WC").font(.system(size: 10, weight: .heavy, design: .rounded)))
        text.shading = .color(.white)
        gc.draw(text, at: CGPoint(x: sign.midX, y: sign.midY), anchor: .center)
    }

    /// 赚回来的心愿：base 是物件底边中点
    static func drawProp(_ gc: inout GraphicsContext, _ kind: PetAccessory, base b: CGPoint) {
        switch kind {
        case .cup:
            var cup = Path()
            cup.move(to: CGPoint(x: b.x - 6, y: b.y))
            cup.addLine(to: CGPoint(x: b.x + 6, y: b.y))
            cup.addLine(to: CGPoint(x: b.x + 7.5, y: b.y - 18))
            cup.addLine(to: CGPoint(x: b.x - 7.5, y: b.y - 18))
            cup.closeSubpath()
            gc.fill(cup, with: .color(Color(red: 0.88, green: 0.73, blue: 0.56)))
            gc.stroke(cup, with: .color(ink.opacity(0.4)), lineWidth: 1)
            var straw = Path()
            straw.move(to: CGPoint(x: b.x + 1, y: b.y - 20))
            straw.addLine(to: CGPoint(x: b.x + 4, y: b.y - 29))
            gc.stroke(straw, with: .color(Color(red: 0.95, green: 0.38, blue: 0.48)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            gc.fill(Path(roundedRect: CGRect(x: b.x - 8.5, y: b.y - 21, width: 17, height: 3.5), cornerRadius: 1.5), with: .color(Color(white: 0.95)))
            for (dx, dy) in [(-3.0, -3.0), (1.0, -4.2), (4.0, -2.6)] {
                gc.fill(Path(ellipseIn: CGRect(x: b.x + dx - 1.6, y: b.y + dy - 1.6, width: 3.2, height: 3.2)), with: .color(Color(red: 0.25, green: 0.15, blue: 0.10)))
            }
        case .food:
            var handle = Path()
            handle.move(to: CGPoint(x: b.x - 6, y: b.y - 15))
            handle.addQuadCurve(to: CGPoint(x: b.x + 6, y: b.y - 15), control: CGPoint(x: b.x, y: b.y - 25))
            gc.stroke(handle, with: .color(Color(white: 0.55)), lineWidth: 1.3)
            var box = Path()
            box.move(to: CGPoint(x: b.x - 8, y: b.y))
            box.addLine(to: CGPoint(x: b.x + 8, y: b.y))
            box.addLine(to: CGPoint(x: b.x + 10, y: b.y - 13))
            box.addLine(to: CGPoint(x: b.x + 4, y: b.y - 17))
            box.addLine(to: CGPoint(x: b.x - 4, y: b.y - 17))
            box.addLine(to: CGPoint(x: b.x - 10, y: b.y - 13))
            box.closeSubpath()
            gc.fill(box, with: .color(.white))
            gc.stroke(box, with: .color(Color(white: 0.6)), lineWidth: 1)
            gc.fill(Path(ellipseIn: CGRect(x: b.x - 2.5, y: b.y - 9.5, width: 5, height: 5)), with: .color(Color(red: 0.9, green: 0.25, blue: 0.22)))
        case .ticket:
            var g = gc
            g.translateBy(x: b.x, y: b.y - 7)
            g.rotate(by: .degrees(-12))
            let rect = CGRect(x: -11, y: -6, width: 22, height: 12)
            g.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color(red: 1.0, green: 0.82, blue: 0.30)))
            g.stroke(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color(red: 0.80, green: 0.55, blue: 0.10)), lineWidth: 1)
            var perforation = Path()
            perforation.move(to: CGPoint(x: -5, y: -6))
            perforation.addLine(to: CGPoint(x: -5, y: 6))
            g.stroke(perforation, with: .color(Color(red: 0.80, green: 0.55, blue: 0.10)), style: StrokeStyle(lineWidth: 1, dash: [1.5, 1.5]))
            var star = g.resolve(Text("★").font(.system(size: 7)))
            star.shading = .color(Color(red: 0.85, green: 0.40, blue: 0.10))
            g.draw(star, at: CGPoint(x: 3, y: 0), anchor: .center)
        case .controller:
            let body = CGRect(x: b.x - 12, y: b.y - 11, width: 24, height: 11)
            gc.fill(Path(roundedRect: body, cornerRadius: 5.5), with: .color(Color(white: 0.27)))
            gc.fill(Path(CGRect(x: b.x - 8.5, y: b.y - 6.5, width: 5, height: 1.6)), with: .color(.white.opacity(0.85)))
            gc.fill(Path(CGRect(x: b.x - 6.8, y: b.y - 8.2, width: 1.6, height: 5)), with: .color(.white.opacity(0.85)))
            gc.fill(Path(ellipseIn: CGRect(x: b.x + 4, y: b.y - 8, width: 2.8, height: 2.8)), with: .color(Color(red: 0.95, green: 0.35, blue: 0.35)))
            gc.fill(Path(ellipseIn: CGRect(x: b.x + 7, y: b.y - 5.5, width: 2.8, height: 2.8)), with: .color(Color(red: 0.35, green: 0.55, blue: 0.95)))
        case .gift:
            let red = Color(red: 0.92, green: 0.30, blue: 0.32)
            let gold = Color(red: 1.0, green: 0.82, blue: 0.30)
            gc.fill(Path(CGRect(x: b.x - 8, y: b.y - 12, width: 16, height: 12)), with: .color(red))
            gc.fill(Path(CGRect(x: b.x - 9.5, y: b.y - 15.5, width: 19, height: 4)), with: .color(red.opacity(0.85)))
            gc.fill(Path(CGRect(x: b.x - 1.5, y: b.y - 15.5, width: 3, height: 15.5)), with: .color(gold))
            for x in [b.x - 5.5, b.x + 0.5] {
                gc.stroke(Path(ellipseIn: CGRect(x: x, y: b.y - 20, width: 5, height: 4.5)), with: .color(gold), lineWidth: 1.6)
            }
        case .shirt, .shoes:
            break
        }
    }

    // MARK: - 飘在空中的

    static func drawZzz(_ gc: inout GraphicsContext, t: Double, dy: CGFloat, dx: CGFloat = 0) {
        for i in 0..<3 {
            let p = (t / 2.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            var z = gc.resolve(Text("z").font(.system(size: 9 + p * 7, weight: .heavy, design: .rounded)))
            z.shading = .color(capBlue.opacity(sin(p * .pi)))
            gc.draw(z, at: CGPoint(x: cx + 24 + dx + p * 18, y: cy - 36 - p * 28 + dy), anchor: .center)
        }
    }

    static func drawNight(_ gc: inout GraphicsContext, t: Double) {
        gc.drawLayer { layer in
            layer.fill(Path(ellipseIn: CGRect(x: cx + 26, y: cy - 58, width: 16, height: 16)), with: .color(Color(red: 1.0, green: 0.86, blue: 0.45)))
            layer.blendMode = .destinationOut
            layer.fill(Path(ellipseIn: CGRect(x: cx + 31, y: cy - 62, width: 15, height: 15)), with: .color(.black))
        }
        for (i, point) in [CGPoint(x: cx + 16, y: cy - 62), CGPoint(x: cx + 52, y: cy - 40)].enumerated() {
            let size = 2.5 + abs(sin(t * 1.7 + Double(i) * 1.3)) * 2
            var star = Path()
            star.move(to: CGPoint(x: point.x, y: point.y - size))
            star.addLine(to: CGPoint(x: point.x, y: point.y + size))
            star.move(to: CGPoint(x: point.x - size, y: point.y))
            star.addLine(to: CGPoint(x: point.x + size, y: point.y))
            gc.stroke(star, with: .color(Color(red: 1.0, green: 0.86, blue: 0.45)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    static func drawQuestion(_ gc: inout GraphicsContext, t: Double, at c: CGPoint = CGPoint(x: cx + 34, y: cy - 42)) {
        var mark = gc.resolve(Text("?").font(.system(size: 22, weight: .heavy, design: .rounded)))
        mark.shading = .color(ink)
        gc.draw(mark, at: CGPoint(x: c.x, y: c.y + sin(t * 3) * 2), anchor: .center)
    }

    static func drawClock(_ gc: inout GraphicsContext, t: Double, at c: CGPoint = CGPoint(x: cx + 36, y: cy - 42)) {
        let face = CGRect(x: c.x - 10, y: c.y - 10, width: 20, height: 20)
        gc.fill(Path(ellipseIn: face), with: .color(.white))
        gc.stroke(Path(ellipseIn: face), with: .color(ink), lineWidth: 1.6)
        let angle = t * 3
        var hands = Path()
        hands.move(to: c)
        hands.addLine(to: CGPoint(x: c.x + CGFloat(sin(angle)) * 7, y: c.y - CGFloat(cos(angle)) * 7))
        hands.move(to: c)
        hands.addLine(to: CGPoint(x: c.x + 4, y: c.y))
        gc.stroke(hands, with: .color(ink), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    static func drawSweat(_ gc: inout GraphicsContext, t: Double, dy: CGFloat, dx: CGFloat = 0) {
        let fall = CGFloat((t * 8).truncatingRemainder(dividingBy: 10))
        let top = CGPoint(x: cx + 25 + dx, y: cy - 24 + fall + dy)
        var drop = Path()
        drop.move(to: top)
        drop.addQuadCurve(to: CGPoint(x: top.x, y: top.y + 9), control: CGPoint(x: top.x + 6, y: top.y + 8))
        drop.addQuadCurve(to: top, control: CGPoint(x: top.x - 6, y: top.y + 8))
        gc.fill(drop, with: .color(Color(red: 0.55, green: 0.78, blue: 1.0).opacity(1 - Double(fall) / 14)))
    }

    static func drawSparkles(_ gc: inout GraphicsContext, t: Double, dy: CGFloat) {
        for (i, point) in [CGPoint(x: cx - 40, y: cy - 40), CGPoint(x: cx + 40, y: cy - 36), CGPoint(x: cx, y: cy - 58)].enumerated() {
            let size = 2 + abs(sin(t * 3 + Double(i))) * 3
            var star = Path()
            star.move(to: CGPoint(x: point.x, y: point.y - size + dy))
            star.addLine(to: CGPoint(x: point.x, y: point.y + size + dy))
            star.move(to: CGPoint(x: point.x - size, y: point.y + dy))
            star.addLine(to: CGPoint(x: point.x + size, y: point.y + dy))
            gc.stroke(star, with: .color(coinMid), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    static func drawCoins(_ gc: inout GraphicsContext, _ s: PetRenderState, dy: CGFloat) {
        let start = CGPoint(x: cx, y: cy - r - 2 + dy)
        let control = CGPoint(x: cx + 44, y: cy - r - 46)
        let end = CGPoint(x: 174.5, y: 139)
        for age in s.coinPops where age >= 0 && age < 1.7 {
            if age < 0.9 {
                let p = age / 0.9, q = 1 - p
                let x = q * q * start.x + 2 * q * p * control.x + p * p * end.x
                let y = q * q * start.y + 2 * q * p * control.y + p * p * end.y
                let coin = CGRect(x: x - 5, y: y - 5, width: 10, height: 10)
                gc.fill(Path(ellipseIn: coin), with: .color(coinMid))
                gc.stroke(Path(ellipseIn: coin), with: .color(ink), lineWidth: 1)
                gc.fill(Path(CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)), with: .color(ink))
            }
            if age > 0.8 {
                let q = (age - 0.8) / 0.9
                var plus = gc.resolve(Text("+¥\(s.coinStep)").font(.system(size: 11, weight: .heavy, design: .rounded)))
                plus.shading = .color(coinLo.opacity(max(0, 1 - q)))
                gc.draw(plus, at: CGPoint(x: 176, y: 128 - q * 14), anchor: .center)
            }
        }
    }
}
