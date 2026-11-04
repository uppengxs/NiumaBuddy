import SwiftUI

/// 猫的毛色和长相。姿势、动作几只猫共用，换的只是这些
struct CatCoat {
    enum Face {
        case blaze    // 白色倒 V：额头一道细线往下变宽，盖住鼻子嘴巴下巴（布偶猫）
        case muzzle   // 只有胡须垫和下巴是白的（金渐层）
        case solid    // 整张脸一个颜色（黑猫）
    }

    var fur: Color
    var furShade: Color
    /// 脸中间、背上反光的地方
    var furLight: Color
    var ear: Color
    var earInner: Color
    /// 眼睛周围的深色面罩；纯色猫没有
    var mask: Color?
    /// 白色的部分：脸上（看 face）、胸口、肚皮；纯色猫没有
    var white: Color?
    var face: Face
    /// 额头上的虎斑条纹
    var stripes: Color?
    var whiteShade: Color
    /// 手脚的颜色
    var paw: Color
    var tail: [Color]
    var tailTip: Color?
    /// 身体轮廓线；黑猫用浅色，像一圈反光，深色桌面上才看得出轮廓
    var outline: Color
    /// 嘴巴、闭着的眼睛、脚趾这些线条
    var line: Color
    /// 上眼皮的颜色，要和眼睛周围的毛一样
    var lid: Color
    var eye: Color
    var eyeDeep: Color
    var eyeSize: CGSize
    var pupil: CGSize
    /// 平时上眼皮盖住多少：浩浩 0.2 是嫌弃脸，薯条眼睛瞪得圆圆的
    var restingLid: CGFloat
    var nose: Color
    var noseEdge: Color
    var whisker: Color
    var blush: Double
    /// 长毛猫：腮帮子上有几撮长毛、胸口毛一撮一撮的、耳朵大
    var longFur: Bool

    /// 浩浩：布偶猫。奶咖色身子、深棕面罩中间一道白色倒 V、蓝眼睛、粉鼻头、白胸口白手套、深棕大尾巴带白尖
    static let haohao = CatCoat(
        fur: Color(red: 0.76, green: 0.67, blue: 0.60),
        furShade: Color(red: 0.61, green: 0.51, blue: 0.44),
        furLight: Color(red: 0.76, green: 0.67, blue: 0.60),
        ear: Color(red: 0.26, green: 0.18, blue: 0.14),
        earInner: Color(red: 0.82, green: 0.60, blue: 0.58),
        mask: Color(red: 0.40, green: 0.29, blue: 0.23),
        white: Color(red: 1.0, green: 0.985, blue: 0.96),
        face: .blaze,
        stripes: nil,
        whiteShade: Color(red: 0.88, green: 0.84, blue: 0.79),
        paw: Color(red: 1.0, green: 0.985, blue: 0.96),
        tail: [Color(red: 0.61, green: 0.51, blue: 0.44), Color(red: 0.40, green: 0.29, blue: 0.23), Color(red: 0.26, green: 0.18, blue: 0.14)],
        tailTip: Color(red: 1.0, green: 0.985, blue: 0.96),
        outline: Color(red: 0.27, green: 0.19, blue: 0.15).opacity(0.5),
        line: Color(red: 0.13, green: 0.09, blue: 0.07),
        lid: Color(red: 0.40, green: 0.29, blue: 0.23),
        eye: Color(red: 0.52, green: 0.73, blue: 0.98),
        eyeDeep: Color(red: 0.20, green: 0.38, blue: 0.70),
        eyeSize: CGSize(width: 10.8, height: 11.6),
        pupil: CGSize(width: 3.6, height: 7.6),
        restingLid: 0.2,
        nose: Color(red: 0.97, green: 0.62, blue: 0.68),
        noseEdge: Color(red: 0.80, green: 0.42, blue: 0.48),
        whisker: Color(red: 0.27, green: 0.19, blue: 0.15).opacity(0.3),
        blush: 0.4,
        longFur: true
    )

    /// 球球：黑色短毛猫。全身黑、圆脸小耳朵、金黄色大眼睛
    static let qiuqiu = CatCoat(
        fur: Color(red: 0.19, green: 0.19, blue: 0.22),
        furShade: Color(red: 0.09, green: 0.09, blue: 0.11),
        furLight: Color(red: 0.30, green: 0.30, blue: 0.35),
        ear: Color(red: 0.13, green: 0.13, blue: 0.15),
        earInner: Color(red: 0.50, green: 0.38, blue: 0.42),
        mask: nil,
        white: nil,
        face: .solid,
        stripes: nil,
        whiteShade: Color(red: 0.26, green: 0.26, blue: 0.30),
        paw: Color(red: 0.17, green: 0.17, blue: 0.20),
        tail: [Color(red: 0.17, green: 0.17, blue: 0.20), Color(red: 0.12, green: 0.12, blue: 0.14), Color(red: 0.08, green: 0.08, blue: 0.09)],
        tailTip: nil,
        outline: Color(red: 0.70, green: 0.70, blue: 0.76).opacity(0.55),
        line: Color(red: 0.68, green: 0.66, blue: 0.72),
        lid: Color(red: 0.21, green: 0.21, blue: 0.25),
        eye: Color(red: 0.97, green: 0.85, blue: 0.32),
        eyeDeep: Color(red: 0.62, green: 0.63, blue: 0.18),
        eyeSize: CGSize(width: 12, height: 12.4),
        pupil: CGSize(width: 3.6, height: 7.6),
        restingLid: 0.2,
        nose: Color(red: 0.14, green: 0.13, blue: 0.15),
        noseEdge: Color(red: 0.55, green: 0.53, blue: 0.58),
        whisker: Color.white.opacity(0.45),
        blush: 0,
        longFur: false
    )

    /// 薯条：金渐层。金黄色身子、额头几道深色条纹、奶白色下巴和胸口、绿眼睛瞪得圆圆的、粉鼻头、尾巴尖是黑的
    static let shutiao = CatCoat(
        fur: Color(red: 0.97, green: 0.75, blue: 0.46),
        furShade: Color(red: 0.87, green: 0.61, blue: 0.34),
        furLight: Color(red: 1.0, green: 0.86, blue: 0.62),
        ear: Color(red: 0.90, green: 0.64, blue: 0.36),
        earInner: Color(red: 1.0, green: 0.74, blue: 0.74),
        mask: nil,
        white: Color(red: 1.0, green: 0.95, blue: 0.86),
        face: .muzzle,
        stripes: Color(red: 0.78, green: 0.48, blue: 0.22),
        whiteShade: Color(red: 0.93, green: 0.83, blue: 0.68),
        paw: Color(red: 0.98, green: 0.82, blue: 0.58),
        tail: [Color(red: 0.97, green: 0.75, blue: 0.46), Color(red: 0.92, green: 0.67, blue: 0.39), Color(red: 0.87, green: 0.61, blue: 0.34)],
        tailTip: Color(red: 0.17, green: 0.13, blue: 0.11),
        outline: Color(red: 0.50, green: 0.30, blue: 0.12).opacity(0.5),
        line: Color(red: 0.32, green: 0.18, blue: 0.08),
        lid: Color(red: 0.97, green: 0.75, blue: 0.46),
        eye: Color(red: 0.82, green: 0.86, blue: 0.45),
        eyeDeep: Color(red: 0.34, green: 0.55, blue: 0.29),
        eyeSize: CGSize(width: 12.4, height: 12.8),
        pupil: CGSize(width: 5.2, height: 7),
        restingLid: 0.04,
        nose: Color(red: 0.96, green: 0.66, blue: 0.62),
        noseEdge: Color(red: 0.80, green: 0.46, blue: 0.42),
        whisker: Color(red: 0.50, green: 0.30, blue: 0.12).opacity(0.3),
        blush: 0.3,
        longFur: false
    )

    static func of(_ skin: PetSkin) -> CatCoat? {
        switch skin {
        case .coin: return nil
        case .haohao: return .haohao
        case .qiuqiu: return .qiuqiu
        case .shutiao: return .shutiao
        }
    }
}

extension PetArt {
    /// 画眼珠描边、瞳孔、小鱼眼睛这些不随毛色变的深色
    static let catInk = Color(red: 0.13, green: 0.09, blue: 0.07)

    static func drawCat(_ gc: inout GraphicsContext, _ s: PetRenderState, t: Double) {
        CatPainter(coat: CatCoat.of(s.skin) ?? .haohao).draw(&gc, s, t: t)
    }

    /// Q 版猫：和小铜板共用 240×200 的画布和桌子、行李箱这些道具，只是换了身体，再加上团成一团、侧躺摊平两种猫的姿势
    private struct CatPainter {
        let coat: CatCoat

        /// 站着时脑袋的中心
        private static let headCenter = CGPoint(x: cx, y: 116)

        private enum Pose {
            case stand   // 后腿站着，和小铜板一样能敲键盘、拖行李箱
            case loaf    // 揣着手团成一团
            case belly   // 侧躺摊平
        }

        private func pose(_ l: Look) -> Pose {
            switch l.scene {
            case .sleeping, .napping: return .loaf
            case .resting: return .belly
            default: return .stand
            }
        }

        // MARK: - 总装

        func draw(_ gc: inout GraphicsContext, _ s: PetRenderState, t: Double) {
            let l = look(s, t: t)
            let dy = bodyOffset(s, t: t)
            let pose = pose(l)

            switch pose {
            case .stand: drawShadow(&gc, lift: max(0, -dy), faint: s.held, width: 54)
            case .loaf: drawShadow(&gc, lift: 0, faint: false, width: 88)
            case .belly: drawShadow(&gc, lift: 0, faint: false, width: 110)
            }

            // 身后的布景
            switch l.scene {
            case .toilet: drawWCSign(&gc)
            case .packing: drawBackpack(&gc, rect: CGRect(x: 160, y: 150, width: 24, height: 28))
            case .eating: drawBowl(&gc, base: CGPoint(x: 172, y: ground))
            default: break
            }
            if let prop = s.outfit.prop, let scene = l.scene, [.packing, .waving, .resting].contains(scene) {
                drawProp(&gc, prop, base: CGPoint(x: scene == .resting ? 196 : 58, y: ground))
            }

            var flip = gc
            if s.facing < 0 {
                flip.translateBy(x: cx * 2, y: 0)
                flip.scaleBy(x: -1, y: 1)
            }
            if l.scene == .vacation { drawSuitcase(&flip) }
            var pet = flip
            pet.translateBy(x: 0, y: dy)
            switch pose {
            case .stand: drawStanding(&pet, s, l, t: t)
            case .loaf: drawLoaf(&pet, l, t: t)
            case .belly: drawBelly(&pet, l, t: t)
            }

            // 身前的布景
            if l.scene == .working || l.scene == .overtime {
                drawDesk(&gc, dim: l.scene == .overtime)
                if let prop = s.outfit.prop { drawProp(&gc, prop, base: CGPoint(x: 80, y: 156)) }
            }

            // 飘在空中的小东西
            switch l.scene {
            case .sleeping, .napping: drawZzz(&gc, t: t, dy: dy + 26, dx: 4)
            case .resting: drawNight(&gc, t: t)
            case .confused: drawQuestion(&gc, t: t, at: CGPoint(x: cx + 44, y: cy - 46))
            case .packing: drawClock(&gc, t: t, at: CGPoint(x: cx + 46, y: cy - 44))
            case .overtime, .toilet: drawSweat(&gc, t: t, dy: dy, dx: 13)
            case .working: drawCoins(&gc, s, dy: dy)
            default: break
            }
            if l.arms == .stretch { drawSparkles(&gc, t: t, dy: dy) }
        }

        // MARK: - 三种姿势

        private func drawStanding(_ gc: inout GraphicsContext, _ s: PetRenderState, _ l: Look, t: Double) {
            let wag = sin(t * 1.7) * 4
            if s.held {
                // 被拎起来，尾巴耷拉着
                drawTail(&gc, from: CGPoint(x: cx - 12, y: 170), control: CGPoint(x: cx - 30, y: 176), to: CGPoint(x: cx - 28 + wag, y: 192))
            } else {
                drawTail(&gc, from: CGPoint(x: cx - 12, y: 170), control: CGPoint(x: cx - 52, y: 168), to: CGPoint(x: cx - 40 + wag, y: 128))
            }
            if l.backpackWorn {
                gc.fill(Path(roundedRect: CGRect(x: cx - 37, y: 136, width: 20, height: 30), cornerRadius: 6), with: .color(bagGreen))
            }
            // 伸懒腰时两只手举在脑袋后面，别挡住脸
            if l.arms == .stretch { drawArms(&gc, l, t: t, shirt: s.outfit.shirt) }
            drawTorso(&gc, shirt: s.outfit.shirt)
            drawFeet(&gc, s, t: t)
            if l.backpackWorn {
                var strap = Path()
                strap.move(to: CGPoint(x: cx - 17, y: 137))
                strap.addQuadCurve(to: CGPoint(x: cx - 19, y: 164), control: CGPoint(x: cx - 12, y: 150))
                gc.stroke(strap, with: .color(bagGreen), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            var head = gc
            head.translateBy(x: Self.headCenter.x, y: Self.headCenter.y)
            if l.scene == .confused { head.rotate(by: .degrees(12)) }
            drawHead(&head, l, t: t, cap: false)
            if l.arms == .bowl { drawFish(&gc, t: t) }
            if l.arms != .stretch { drawArms(&gc, l, t: t, shirt: s.outfit.shirt) }
            switch l.arms {
            case .roll: drawToiletRoll(&gc)
            case .drink: drawGlass(&gc, t: t)
            default: break
            }
        }

        private func drawLoaf(_ gc: inout GraphicsContext, _ l: Look, t: Double) {
            let napping = l.scene == .napping
            var body = Path()
            body.move(to: CGPoint(x: cx - 34, y: 177))
            body.addQuadCurve(to: CGPoint(x: cx - 14, y: 146), control: CGPoint(x: cx - 38, y: 150))
            body.addQuadCurve(to: CGPoint(x: cx + 36, y: 152), control: CGPoint(x: cx + 14, y: 136))
            body.addQuadCurve(to: CGPoint(x: cx + 44, y: 177), control: CGPoint(x: cx + 50, y: 160))
            body.closeSubpath()
            gc.fill(body, with: furGradient(top: 140, bottom: 178))
            gc.stroke(body, with: .color(coat.outline), lineWidth: 1.2)
            // 尾巴从屁股后面绕到身前
            drawTail(&gc, from: CGPoint(x: cx + 40, y: 170), control: CGPoint(x: cx + 34, y: 183), to: CGPoint(x: cx + 2, y: 176), width: 11)

            var head = gc
            head.translateBy(x: cx - 12, y: napping ? 147 : 142)
            if napping { head.rotate(by: .degrees(-7)) }
            drawHead(&head, l, t: t, cap: l.scene == .sleeping)
            // 揣在胸前的两只爪子，午睡时下巴就搁在上面
            for x in [cx - 25, cx - 9] {
                let paw = CGRect(x: x - 6.5, y: 171, width: 13, height: 7)
                gc.fill(Path(ellipseIn: paw), with: .color(coat.paw))
                gc.stroke(Path(ellipseIn: paw), with: .color(coat.outline), lineWidth: 1.1)
            }
        }

        /// 回家躺平：侧躺摊成一长条，前爪往前伸
        private func drawBelly(_ gc: inout GraphicsContext, _ l: Look, t: Double) {
            drawTail(&gc, from: CGPoint(x: cx + 40, y: 164), control: CGPoint(x: cx + 68, y: 160),
                     to: CGPoint(x: cx + 62 + sin(t * 1.2) * 3, y: 136), width: 12)
            // 后腿往后蹬直
            drawLimb(&gc, from: CGPoint(x: cx + 30, y: 168), to: CGPoint(x: cx + 56, y: 173), shirt: false)
            let body = Path(roundedRect: CGRect(x: cx - 30, y: 150, width: 78, height: 27), cornerRadius: 13.5)
            gc.fill(body, with: furGradient(top: 150, bottom: 178))
            if let white = coat.white {
                var belly = gc
                belly.clip(to: body)
                belly.fill(Path(ellipseIn: CGRect(x: cx - 22, y: 163, width: 64, height: 22)), with: .color(white))
            }
            gc.stroke(body, with: .color(coat.outline), lineWidth: 1.2)
            drawLimb(&gc, from: CGPoint(x: cx + 22, y: 170), to: CGPoint(x: cx + 46, y: 175), shirt: false)
            // 脑袋侧着贴在地上
            var head = gc
            head.translateBy(x: cx - 30, y: 149)
            head.rotate(by: .degrees(-16))
            drawHead(&head, l, t: t, cap: false)
            // 两只前爪往前伸
            drawLimb(&gc, from: CGPoint(x: cx - 16, y: 170), to: CGPoint(x: cx - 52, y: 174), shirt: false)
            drawLimb(&gc, from: CGPoint(x: cx - 10, y: 166), to: CGPoint(x: cx - 46, y: 168 + sin(t * 1.5) * 1.2), shirt: false)
        }

        // MARK: - 身体零件

        private func furGradient(top: CGFloat, bottom: CGFloat) -> GraphicsContext.Shading {
            .linearGradient(Gradient(colors: [coat.fur, coat.furShade]),
                            startPoint: CGPoint(x: cx, y: top), endPoint: CGPoint(x: cx, y: bottom))
        }

        /// 蓬松的大尾巴；浩浩的尾巴尖有一撮白，薯条的是黑的
        private func drawTail(_ gc: inout GraphicsContext, from a: CGPoint, control c: CGPoint, to b: CGPoint, width: CGFloat = 13) {
            var tail = Path()
            tail.move(to: a)
            tail.addQuadCurve(to: b, control: c)
            gc.stroke(tail, with: .color(coat.outline), style: StrokeStyle(lineWidth: width + 2.2, lineCap: .round))
            gc.stroke(tail, with: .linearGradient(Gradient(colors: coat.tail), startPoint: a, endPoint: b),
                      style: StrokeStyle(lineWidth: width, lineCap: .round))
            if let tip = coat.tailTip {
                gc.stroke(tail.trimmedPath(from: 0.8, to: 1), with: .color(tip), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }

        private static let torsoShape: Path = {
            var p = Path()
            p.move(to: CGPoint(x: cx - 17, y: 134))
            p.addQuadCurve(to: CGPoint(x: cx - 26, y: 160), control: CGPoint(x: cx - 28, y: 142))
            p.addQuadCurve(to: CGPoint(x: cx - 13, y: 175), control: CGPoint(x: cx - 26, y: 174))
            p.addLine(to: CGPoint(x: cx + 13, y: 175))
            p.addQuadCurve(to: CGPoint(x: cx + 26, y: 160), control: CGPoint(x: cx + 26, y: 174))
            p.addQuadCurve(to: CGPoint(x: cx + 17, y: 134), control: CGPoint(x: cx + 28, y: 142))
            p.closeSubpath()
            return p
        }()

        /// 胸口到肚皮的一大片白毛，两边一撮一撮的
        private static let bibShape: Path = {
            let left: [CGPoint] = [
                CGPoint(x: -15, y: 130), CGPoint(x: -18, y: 146), CGPoint(x: -13, y: 149), CGPoint(x: -17, y: 155),
                CGPoint(x: -11, y: 159), CGPoint(x: -15, y: 165), CGPoint(x: -10, y: 169), CGPoint(x: -13, y: 177),
            ]
            var p = Path()
            p.addLines(left.map { CGPoint(x: cx + $0.x, y: $0.y) } + left.reversed().map { CGPoint(x: cx - $0.x, y: $0.y) })
            p.closeSubpath()
            return p
        }()

        /// 短毛猫的白胸口，边缘是圆滑的
        private static let smoothBibShape: Path = {
            var p = Path()
            p.move(to: CGPoint(x: cx - 13, y: 132))
            p.addQuadCurve(to: CGPoint(x: cx - 15, y: 160), control: CGPoint(x: cx - 18, y: 146))
            p.addQuadCurve(to: CGPoint(x: cx - 10, y: 177), control: CGPoint(x: cx - 14, y: 172))
            p.addLine(to: CGPoint(x: cx + 10, y: 177))
            p.addQuadCurve(to: CGPoint(x: cx + 15, y: 160), control: CGPoint(x: cx + 14, y: 172))
            p.addQuadCurve(to: CGPoint(x: cx + 13, y: 132), control: CGPoint(x: cx + 18, y: 146))
            p.closeSubpath()
            return p
        }()

        private func drawTorso(_ gc: inout GraphicsContext, shirt: Bool) {
            let torso = Self.torsoShape
            gc.fill(torso, with: furGradient(top: 140, bottom: 178))
            var front = gc
            front.clip(to: torso)
            if let white = coat.white {
                front.fill(coat.longFur ? Self.bibShape : Self.smoothBibShape, with: .color(white))
            } else {
                // 纯色猫：胸口一点反光，不然身子是一整块黑
                front.fill(Path(ellipseIn: CGRect(x: cx - 12, y: 138, width: 24, height: 22)),
                           with: .radialGradient(Gradient(colors: [coat.furLight, coat.fur.opacity(0)]),
                                                 center: CGPoint(x: cx, y: 146), startRadius: 0, endRadius: 13))
            }
            if shirt {
                front.fill(Path(CGRect(x: cx - 30, y: 139, width: 60, height: 25)), with: .color(shirtBlue))
                var collar = Path()
                collar.move(to: CGPoint(x: cx - 7, y: 139))
                collar.addLine(to: CGPoint(x: cx, y: 145))
                collar.addLine(to: CGPoint(x: cx + 7, y: 139))
                front.stroke(collar, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
            gc.stroke(torso, with: .color(coat.outline), lineWidth: 1.2)
        }

        private func drawFeet(_ gc: inout GraphicsContext, _ s: PetRenderState, t: Double) {
            for (i, side) in [CGFloat(-1), 1].enumerated() {
                var x = cx + side * 11
                var y = ground - 4.5
                let phase: Double = i == 0 ? 1 : -1
                if s.walking {
                    let w = sin(t * 9) * phase
                    x += w * 3
                    y -= max(0, w) * 3
                } else if s.held {
                    let w = sin(t * 7) * phase
                    x += w * 2
                    y += 3 + w * 2
                }
                if s.outfit.shoes {
                    let shoe = CGRect(x: x - 8.5, y: y - 4.5, width: 17, height: 9)
                    gc.fill(Path(roundedRect: shoe, cornerRadius: 4.5), with: .color(Color(red: 0.92, green: 0.27, blue: 0.25)))
                    var sole = Path()
                    sole.move(to: CGPoint(x: shoe.minX + 2, y: shoe.maxY - 1.4))
                    sole.addLine(to: CGPoint(x: shoe.maxX - 2, y: shoe.maxY - 1.4))
                    gc.stroke(sole, with: .color(.white), lineWidth: 1.8)
                    gc.fill(Path(ellipseIn: CGRect(x: x - 2, y: shoe.minY + 1.6, width: 4, height: 2.8)), with: .color(.white.opacity(0.9)))
                } else {
                    let foot = CGRect(x: x - 8, y: y - 4.5, width: 16, height: 9)
                    gc.fill(Path(ellipseIn: foot), with: .color(coat.paw))
                    gc.stroke(Path(ellipseIn: foot), with: .color(coat.outline), lineWidth: 1.1)
                    var toes = Path()
                    for dx in [-2.6, 2.6] {
                        toes.move(to: CGPoint(x: x + dx, y: foot.maxY - 1.5))
                        toes.addLine(to: CGPoint(x: x + dx, y: foot.maxY - 4))
                    }
                    gc.stroke(toes, with: .color(coat.line.opacity(0.4)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
                }
            }
        }

        /// 一条手臂（或腿）加一只圆爪子
        private func drawLimb(_ gc: inout GraphicsContext, from a: CGPoint, to b: CGPoint, shirt: Bool) {
            var limb = Path()
            limb.move(to: a)
            limb.addLine(to: b)
            gc.stroke(limb, with: .color(coat.outline), style: StrokeStyle(lineWidth: 8.6, lineCap: .round))
            gc.stroke(limb, with: .color(coat.paw), style: StrokeStyle(lineWidth: 6.4, lineCap: .round))
            if shirt {
                let dx = b.x - a.x, dy = b.y - a.y
                let len = max(sqrt(dx * dx + dy * dy), 1)
                var sleeve = Path()
                sleeve.move(to: a)
                sleeve.addLine(to: CGPoint(x: a.x + dx / len * 7, y: a.y + dy / len * 7))
                gc.stroke(sleeve, with: .color(shirtBlue), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            }
            let paw = CGRect(x: b.x - 4.6, y: b.y - 4.6, width: 9.2, height: 9.2)
            gc.fill(Path(ellipseIn: paw), with: .color(coat.paw))
            gc.stroke(Path(ellipseIn: paw), with: .color(coat.outline), lineWidth: 1.1)
        }

        private func drawArms(_ gc: inout GraphicsContext, _ l: Look, t: Double, shirt: Bool) {
            let raised: Set<Arms> = [.stretch, .shrug, .flail, .wave]
            let shoulderY: CGFloat = raised.contains(l.arms) ? 138 : 142
            let left = CGPoint(x: cx - 17, y: shoulderY), right = CGPoint(x: cx + 17, y: shoulderY)
            let sway = sin(t * 2) * 1.2
            let lh: CGPoint, rh: CGPoint
            switch l.arms {
            case .down:
                lh = CGPoint(x: cx - 23, y: 158 + sway); rh = CGPoint(x: cx + 23, y: 158 - sway)
            case .typing:
                // 爪子尖刚好从电脑屏幕上沿露出来
                let tap = sin(t * 6.5) * 1.6
                lh = CGPoint(x: cx - 11, y: 131 + tap); rh = CGPoint(x: cx + 11, y: 131 - tap)
            case .wave:
                lh = CGPoint(x: cx - 23, y: 158); rh = CGPoint(x: cx + 31 + sin(t * 7) * 4, y: 106)
            case .bowl:
                let bob = sin(t * 6) * 1.2
                lh = CGPoint(x: cx - 12, y: 137 + bob); rh = CGPoint(x: cx + 12, y: 137 + bob)
            case .roll:
                lh = CGPoint(x: cx - 23, y: 157); rh = CGPoint(x: cx + 27, y: 140)
            case .suitcase:
                lh = CGPoint(x: cx - 23, y: 158 + sway); rh = CGPoint(x: cx + 43, y: 130)
            case .shrug:
                lh = CGPoint(x: cx - 31, y: 132); rh = CGPoint(x: cx + 31, y: 132)
            case .flail:
                let f = sin(t * 10) * 5
                lh = CGPoint(x: cx - 30, y: 124 + f); rh = CGPoint(x: cx + 30, y: 124 - f)
            case .bag:
                lh = CGPoint(x: cx - 23, y: 158 + sway); rh = CGPoint(x: cx + 38, y: 152)
            case .stretch:
                let s = sin(t * 2.2) * 2
                lh = CGPoint(x: cx - 24, y: 80 + s); rh = CGPoint(x: cx + 24, y: 80 + s)
            case .drink:
                lh = CGPoint(x: cx - 23, y: 157); rh = CGPoint(x: cx + 11, y: 134)
            }
            drawLimb(&gc, from: left, to: lh, shirt: shirt)
            drawLimb(&gc, from: right, to: rh, shirt: shirt)
        }

        // MARK: - 脑袋（坐标以脑袋中心为原点）

        /// 只给右半边（头顶 → 下巴），左半边镜像过去
        private static func symmetric(start: CGPoint, _ right: [(end: CGPoint, control: CGPoint?)]) -> Path {
            var p = Path()
            p.move(to: start)
            for seg in right {
                if let c = seg.control { p.addQuadCurve(to: seg.end, control: c) } else { p.addLine(to: seg.end) }
            }
            let ends = [start] + right.map(\.end)
            for i in stride(from: right.count - 1, through: 0, by: -1) {
                let to = CGPoint(x: -ends[i].x, y: ends[i].y)
                if let c = right[i].control {
                    p.addQuadCurve(to: to, control: CGPoint(x: -c.x, y: c.y))
                } else {
                    p.addLine(to: to)
                }
            }
            p.closeSubpath()
            return p
        }

        /// 长毛猫：腮帮子上几撮长毛
        private static let fluffyHead = symmetric(start: CGPoint(x: 0, y: -27), [
            (CGPoint(x: 27, y: -19), CGPoint(x: 17, y: -28)),
            (CGPoint(x: 35, y: 3), CGPoint(x: 35, y: -11)),
            (CGPoint(x: 40, y: 9), nil),
            (CGPoint(x: 34.5, y: 12.5), nil),
            (CGPoint(x: 38.5, y: 18), nil),
            (CGPoint(x: 30, y: 20.5), nil),
            (CGPoint(x: 0, y: 27), CGPoint(x: 18, y: 28)),
        ])

        /// 短毛圆脸：腮帮子圆鼓鼓的
        private static let roundHead = symmetric(start: CGPoint(x: 0, y: -26), [
            (CGPoint(x: 27, y: -18), CGPoint(x: 17, y: -27)),
            (CGPoint(x: 37, y: 4), CGPoint(x: 37, y: -9)),
            (CGPoint(x: 25, y: 23), CGPoint(x: 37, y: 18)),
            (CGPoint(x: 0, y: 28), CGPoint(x: 14, y: 29)),
        ])

        private func drawEars(_ gc: inout GraphicsContext) {
            for side in [CGFloat(-1), 1] {
                var ear = Path(), inner = Path()
                if coat.longFur {
                    ear.move(to: CGPoint(x: side * 32, y: -8))
                    ear.addQuadCurve(to: CGPoint(x: side * 29, y: -38), control: CGPoint(x: side * 36, y: -28))
                    ear.addQuadCurve(to: CGPoint(x: side * 9, y: -24), control: CGPoint(x: side * 18, y: -34))
                    inner.move(to: CGPoint(x: side * 28, y: -16))
                    inner.addQuadCurve(to: CGPoint(x: side * 27.5, y: -33), control: CGPoint(x: side * 30.5, y: -27))
                    inner.addQuadCurve(to: CGPoint(x: side * 15, y: -23), control: CGPoint(x: side * 20, y: -30))
                } else {
                    // 小耳朵、分得开、耳尖圆
                    ear.move(to: CGPoint(x: side * 34, y: -6))
                    ear.addQuadCurve(to: CGPoint(x: side * 31, y: -33), control: CGPoint(x: side * 37, y: -24))
                    ear.addQuadCurve(to: CGPoint(x: side * 26, y: -32), control: CGPoint(x: side * 29, y: -35.5))
                    ear.addQuadCurve(to: CGPoint(x: side * 13, y: -22), control: CGPoint(x: side * 18, y: -29))
                    inner.move(to: CGPoint(x: side * 30.5, y: -14))
                    inner.addQuadCurve(to: CGPoint(x: side * 29, y: -29), control: CGPoint(x: side * 32.5, y: -23))
                    inner.addQuadCurve(to: CGPoint(x: side * 18, y: -21), control: CGPoint(x: side * 22, y: -27))
                }
                ear.closeSubpath()
                inner.closeSubpath()
                gc.fill(ear, with: .color(coat.ear))
                gc.stroke(ear, with: .color(coat.outline), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
                gc.fill(inner, with: .color(coat.earInner.opacity(0.75)))
            }
        }

        private func drawHead(_ gc: inout GraphicsContext, _ l: Look, t: Double, cap: Bool) {
            let head = coat.longFur ? Self.fluffyHead : Self.roundHead
            drawEars(&gc)
            gc.fill(head, with: .radialGradient(Gradient(colors: [coat.furLight, coat.fur, coat.furShade]),
                                                center: CGPoint(x: 0, y: -14), startRadius: 0, endRadius: 44))
            var face = gc
            face.clip(to: head)
            if let mask = coat.mask {
                // 深色面罩：两只眼睛周围各一块，往外上方连到耳根，边缘是软的
                for side in [CGFloat(-1), 1] {
                    let c = CGPoint(x: side * 16, y: -4)
                    let patch = Path(ellipseIn: CGRect(x: -18, y: -13, width: 36, height: 26))
                        .applying(CGAffineTransform(translationX: c.x, y: c.y).rotated(by: side * -0.35))
                    face.fill(patch, with: .radialGradient(Gradient(stops: [
                        .init(color: mask, location: 0), .init(color: mask, location: 0.62), .init(color: mask.opacity(0), location: 1),
                    ]), center: c, startRadius: 0, endRadius: 18))
                    let earBase = CGPoint(x: side * 25, y: -19)
                    face.fill(Path(ellipseIn: CGRect(x: earBase.x - 12, y: earBase.y - 10, width: 24, height: 20)),
                              with: .radialGradient(Gradient(colors: [coat.ear.opacity(0.9), mask.opacity(0)]),
                                                    center: earBase, startRadius: 0, endRadius: 12))
                }
            }
            switch coat.face {
            case .blaze:
                // 白色倒 V：额头上一道细线，往下越来越宽，盖住鼻子、嘴巴和下巴
                var blaze = Path()
                blaze.move(to: CGPoint(x: -2, y: -28))
                blaze.addLine(to: CGPoint(x: 2, y: -28))
                blaze.addQuadCurve(to: CGPoint(x: 4.5, y: -5), control: CGPoint(x: 2.6, y: -16))
                blaze.addQuadCurve(to: CGPoint(x: 17, y: 8), control: CGPoint(x: 7, y: 3))
                blaze.addQuadCurve(to: CGPoint(x: 42, y: 15), control: CGPoint(x: 30, y: 7))
                blaze.addLine(to: CGPoint(x: 42, y: 40))
                blaze.addLine(to: CGPoint(x: -42, y: 40))
                blaze.addLine(to: CGPoint(x: -42, y: 15))
                blaze.addQuadCurve(to: CGPoint(x: -17, y: 8), control: CGPoint(x: -30, y: 7))
                blaze.addQuadCurve(to: CGPoint(x: -4.5, y: -5), control: CGPoint(x: -7, y: 3))
                blaze.addQuadCurve(to: CGPoint(x: -2, y: -28), control: CGPoint(x: -2.6, y: -16))
                blaze.closeSubpath()
                face.fill(blaze, with: .color(coat.white ?? coat.fur))
                // 下巴底下一点阴影，和胸口的白毛分开
                face.fill(Path(ellipseIn: CGRect(x: -16, y: 22, width: 32, height: 10)), with: .color(coat.whiteShade.opacity(0.6)))
            case .muzzle:
                // 两边胡须垫加下巴是白的
                var muzzle = Path()
                muzzle.addEllipse(in: CGRect(x: -15, y: 7, width: 17, height: 12.5))
                muzzle.addEllipse(in: CGRect(x: -2, y: 7, width: 17, height: 12.5))
                muzzle.addEllipse(in: CGRect(x: -13, y: 13, width: 26, height: 18))
                face.fill(muzzle, with: .color(coat.white ?? coat.fur))
                face.fill(Path(ellipseIn: CGRect(x: -14, y: 23, width: 28, height: 9)), with: .color(coat.whiteShade.opacity(0.5)))
            case .solid:
                // 纯色猫：两边胡须垫鼓起来一点，脸才有立体感
                for side in [CGFloat(-1), 1] {
                    face.fill(Path(ellipseIn: CGRect(x: side * 6 - 7, y: 8, width: 14, height: 11)),
                              with: .radialGradient(Gradient(colors: [coat.whiteShade, coat.whiteShade.opacity(0)]),
                                                    center: CGPoint(x: side * 6, y: 13), startRadius: 0, endRadius: 7.5))
                }
            }
            if let stripes = coat.stripes {
                // 额头上三道淡淡的条纹，中间那道最长
                for (x0, x1, top, bottom, width) in [(0.0, 0.0, -26.0, -14.0, 2.4), (-6.0, -4.8, -24.5, -16.5, 1.8), (6.0, 4.8, -24.5, -16.5, 1.8)] {
                    var stripe = Path()
                    stripe.move(to: CGPoint(x: x0, y: top))
                    stripe.addLine(to: CGPoint(x: x1, y: bottom))
                    face.stroke(stripe, with: .color(stripes.opacity(0.6)), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
                // 两边脸颊各一道
                for side in [CGFloat(-1), 1] {
                    var cheek = Path()
                    cheek.move(to: CGPoint(x: side * 34, y: 1))
                    cheek.addQuadCurve(to: CGPoint(x: side * 25, y: 4), control: CGPoint(x: side * 29, y: 1))
                    face.stroke(cheek, with: .color(stripes.opacity(0.35)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                }
            }
            gc.stroke(head, with: .color(coat.outline), lineWidth: 1.2)

            drawEyes(&gc, l, t: t)

            if coat.blush > 0 {
                for side in [CGFloat(-1), 1] {
                    gc.fill(Path(ellipseIn: CGRect(x: side * 21 - 4, y: 9, width: 8, height: 4.5)),
                            with: .color(blush.opacity(l.eyes == .tired ? coat.blush * 0.4 : coat.blush)))
                }
            }
            var whiskers = Path()
            for side in [CGFloat(-1), 1] {
                for (y0, y1) in [(12.0, 7.0), (13.5, 13.5), (15.0, 20.0)] {
                    whiskers.move(to: CGPoint(x: side * 10, y: y0))
                    whiskers.addLine(to: CGPoint(x: side * 37, y: y1))
                }
            }
            gc.stroke(whiskers, with: .color(coat.whisker), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))

            drawMouth(&gc, l)
            if cap { drawNightcap(&gc) }
        }

        private func drawEyes(_ gc: inout GraphicsContext, _ l: Look, t: Double) {
            let blinking = t.truncatingRemainder(dividingBy: 4.3) < 0.13
            for side in [CGFloat(-1), 1] {
                let c = CGPoint(x: side * 13, y: -1)
                switch l.eyes {
                case .open, .focused, .shifty, .wide, .tired:
                    if blinking && l.eyes != .tired {
                        var lid = Path()
                        lid.move(to: CGPoint(x: c.x - 4.5, y: c.y))
                        lid.addLine(to: CGPoint(x: c.x + 4.5, y: c.y))
                        gc.stroke(lid, with: .color(coat.line), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                        continue
                    }
                    // 平时的眼皮：浩浩的招牌嫌弃脸、球球的盯人眼神、薯条瞪得圆圆的
                    var look = CGPoint.zero
                    var lid = coat.restingLid
                    switch l.eyes {
                    case .focused: look = CGPoint(x: 1, y: 1.6); lid = max(coat.restingLid, 0.12) + 0.12
                    case .shifty: look = CGPoint(x: sin(t * 2.6) * 1.8, y: 0); lid = coat.restingLid + 0.04
                    case .wide: lid = 0
                    case .tired: look = CGPoint(x: 0, y: 1); lid = 0.52
                    default: break
                    }
                    drawEye(&gc, at: c, lid: lid, look: look, wide: l.eyes == .wide)
                case .closed:
                    var arc = Path()
                    arc.move(to: CGPoint(x: c.x - 4.6, y: c.y - 0.5))
                    arc.addQuadCurve(to: CGPoint(x: c.x + 4.6, y: c.y - 0.5), control: CGPoint(x: c.x, y: c.y + 4))
                    gc.stroke(arc, with: .color(coat.line), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                case .happy:
                    var arc = Path()
                    arc.move(to: CGPoint(x: c.x - 4.6, y: c.y + 1.5))
                    arc.addQuadCurve(to: CGPoint(x: c.x + 4.6, y: c.y + 1.5), control: CGPoint(x: c.x, y: c.y - 4.5))
                    gc.stroke(arc, with: .color(coat.line), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                case .cool:
                    break
                }
            }
            if l.eyes == .cool { drawSunglasses(&gc) }
        }

        /// lid 是上眼皮盖住的比例
        private func drawEye(_ gc: inout GraphicsContext, at c: CGPoint, lid: CGFloat, look: CGPoint, wide: Bool) {
            let size = coat.eyeSize
            let rect = CGRect(x: c.x - size.width / 2, y: c.y - size.height / 2, width: size.width, height: size.height)
            let shape = Path(ellipseIn: rect)
            var eye = gc
            eye.clip(to: shape)
            eye.fill(shape, with: .radialGradient(Gradient(colors: [coat.eye, coat.eye, coat.eyeDeep]),
                                                  center: CGPoint(x: c.x, y: c.y + 2), startRadius: 0, endRadius: size.width * 0.65))
            let pw: CGFloat = wide ? max(6.4, coat.pupil.width) : coat.pupil.width
            let ph: CGFloat = wide ? 7 : coat.pupil.height
            let p = CGPoint(x: c.x + look.x, y: c.y + look.y)
            eye.fill(Path(ellipseIn: CGRect(x: p.x - pw / 2, y: p.y - ph / 2, width: pw, height: ph)), with: .color(catInk))
            eye.fill(Path(ellipseIn: CGRect(x: p.x - 3.2, y: p.y - 3.8, width: 3, height: 3)), with: .color(.white))
            eye.fill(Path(ellipseIn: CGRect(x: p.x + 1.3, y: p.y + 1.4, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.85)))
            // 描边画在眼睛里面，被眼皮盖住的那段就跟着看不见
            eye.stroke(shape, with: .color(catInk.opacity(0.85)), lineWidth: 2.2)
            if lid > 0 {
                let lidY = rect.minY + rect.height * lid
                eye.fill(Path(CGRect(x: rect.minX - 1, y: rect.minY - 1, width: rect.width + 2, height: lidY - rect.minY + 1)), with: .color(coat.lid))
                var line = Path()
                line.move(to: CGPoint(x: rect.minX, y: lidY))
                line.addLine(to: CGPoint(x: rect.maxX, y: lidY))
                eye.stroke(line, with: .color(catInk), lineWidth: 1.8)
            }
        }

        private func drawMouth(_ gc: inout GraphicsContext, _ l: Look) {
            var nose = Path()
            nose.move(to: CGPoint(x: -3.6, y: 7.2))
            nose.addQuadCurve(to: CGPoint(x: 3.6, y: 7.2), control: CGPoint(x: 0, y: 6))
            nose.addQuadCurve(to: CGPoint(x: 0, y: 11.2), control: CGPoint(x: 2.6, y: 9.6))
            nose.addQuadCurve(to: CGPoint(x: -3.6, y: 7.2), control: CGPoint(x: -2.6, y: 9.6))
            gc.fill(nose, with: .color(coat.nose))
            gc.stroke(nose, with: .color(coat.noseEdge), lineWidth: 0.7)

            // 小铜板的嘴是方孔，这里把张嘴的程度换算成猫嘴张开多少
            let open = min(max((l.mouth.height - 5.5) / 3.5, 0), 1)
            if open > 0.2 {
                let w = 4 + open * 3, h = 2 + open * 5
                let mouth = CGRect(x: -w / 2, y: 13, width: w, height: h)
                gc.fill(Path(ellipseIn: mouth), with: .color(Color(red: 0.55, green: 0.24, blue: 0.26)))
                gc.fill(Path(ellipseIn: CGRect(x: -w / 2 + 1, y: mouth.midY, width: w - 2, height: h / 2)),
                        with: .color(Color(red: 0.97, green: 0.62, blue: 0.68)))
            }
            var lips = Path()
            lips.move(to: CGPoint(x: 0, y: 11.2))
            lips.addLine(to: CGPoint(x: 0, y: 13))
            lips.addQuadCurve(to: CGPoint(x: -4.6, y: 13.4), control: CGPoint(x: -2.3, y: 16.2))
            lips.move(to: CGPoint(x: 0, y: 13))
            lips.addQuadCurve(to: CGPoint(x: 4.6, y: 13.4), control: CGPoint(x: 2.3, y: 16.2))
            gc.stroke(lips, with: .color(coat.line.opacity(0.85)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }

        private func drawSunglasses(_ gc: inout GraphicsContext) {
            let frame = Color(white: 0.1)
            for side in [CGFloat(-1), 1] {
                let lens = CGRect(x: side * 13 - 8, y: -6.5, width: 16, height: 11)
                gc.fill(Path(roundedRect: lens, cornerRadius: 4), with: .color(frame.opacity(0.95)))
                // 黑猫脸上也要看得出墨镜，镜框描一圈浅边
                gc.stroke(Path(roundedRect: lens, cornerRadius: 4), with: .color(coat.outline), lineWidth: 0.8)
                var shine = Path()
                shine.move(to: CGPoint(x: lens.minX + 3.5, y: lens.minY + 3))
                shine.addLine(to: CGPoint(x: lens.minX + 7.5, y: lens.minY + 3))
                gc.stroke(shine, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
            var rim = Path()
            rim.move(to: CGPoint(x: -5, y: -3))
            rim.addLine(to: CGPoint(x: 5, y: -3))
            rim.move(to: CGPoint(x: -21, y: -4))
            rim.addLine(to: CGPoint(x: -33, y: -8))
            rim.move(to: CGPoint(x: 21, y: -4))
            rim.addLine(to: CGPoint(x: 33, y: -8))
            gc.stroke(rim, with: .color(frame), lineWidth: 1.6)
        }

        private func drawNightcap(_ gc: inout GraphicsContext) {
            var cap = Path()
            cap.move(to: CGPoint(x: -22, y: -20))
            cap.addQuadCurve(to: CGPoint(x: 19, y: -23), control: CGPoint(x: -2, y: -34))
            cap.addQuadCurve(to: CGPoint(x: -33, y: -47), control: CGPoint(x: 6, y: -55))
            cap.addQuadCurve(to: CGPoint(x: -22, y: -20), control: CGPoint(x: -30, y: -33))
            gc.fill(cap, with: .color(capBlue))
            var band = Path()
            band.move(to: CGPoint(x: -22, y: -20))
            band.addQuadCurve(to: CGPoint(x: 19, y: -23), control: CGPoint(x: -2, y: -34))
            gc.stroke(band, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            gc.fill(Path(ellipseIn: CGRect(x: -38, y: -52, width: 9, height: 9)), with: .color(.white))
        }

        // MARK: - 猫的道具

        /// 午饭：两只爪子捧着一条小鱼干
        private func drawFish(_ gc: inout GraphicsContext, t: Double) {
            let c = CGPoint(x: cx, y: 137 + sin(t * 6) * 1.2)
            let gold = Color(red: 0.90, green: 0.68, blue: 0.36)
            let goldDark = Color(red: 0.70, green: 0.47, blue: 0.20)
            var tail = Path()
            tail.move(to: CGPoint(x: c.x + 8, y: c.y))
            tail.addLine(to: CGPoint(x: c.x + 15, y: c.y - 4.5))
            tail.addLine(to: CGPoint(x: c.x + 15, y: c.y + 4.5))
            tail.closeSubpath()
            gc.fill(tail, with: .color(goldDark))
            let body = Path(ellipseIn: CGRect(x: c.x - 11, y: c.y - 4.5, width: 21, height: 9))
            gc.fill(body, with: .color(gold))
            gc.stroke(body, with: .color(goldDark), lineWidth: 1)
            var scales = Path()
            for dx in [-1.0, 3.0] {
                scales.move(to: CGPoint(x: c.x + dx, y: c.y - 3))
                scales.addQuadCurve(to: CGPoint(x: c.x + dx, y: c.y + 3), control: CGPoint(x: c.x + dx + 2.2, y: c.y))
            }
            gc.stroke(scales, with: .color(goldDark.opacity(0.7)), lineWidth: 0.9)
            gc.fill(Path(ellipseIn: CGRect(x: c.x - 7.5, y: c.y - 2, width: 2.2, height: 2.2)), with: .color(catInk))
        }

        /// 地上的猫碗，堆着猫粮
        private func drawBowl(_ gc: inout GraphicsContext, base b: CGPoint) {
            let kibble = Color(red: 0.62, green: 0.40, blue: 0.22)
            for (dx, dy) in [(-7.0, -12.5), (-2.0, -14.5), (3.0, -13.0), (8.0, -12.0), (0.5, -11.0), (-4.5, -10.5), (5.5, -10.5)] {
                gc.fill(Path(ellipseIn: CGRect(x: b.x + dx - 2.4, y: b.y + dy - 2.2, width: 4.8, height: 4.4)), with: .color(kibble))
            }
            var bowl = Path()
            bowl.move(to: CGPoint(x: b.x - 15, y: b.y - 11))
            bowl.addLine(to: CGPoint(x: b.x + 15, y: b.y - 11))
            bowl.addLine(to: CGPoint(x: b.x + 11, y: b.y))
            bowl.addLine(to: CGPoint(x: b.x - 11, y: b.y))
            bowl.closeSubpath()
            gc.fill(bowl, with: .color(Color(red: 0.96, green: 0.58, blue: 0.64)))
            gc.stroke(bowl, with: .color(catInk.opacity(0.4)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            var rim = Path()
            rim.move(to: CGPoint(x: b.x - 14, y: b.y - 9.5))
            rim.addLine(to: CGPoint(x: b.x + 14, y: b.y - 9.5))
            gc.stroke(rim, with: .color(.white.opacity(0.55)), lineWidth: 1.2)
            // 碗上印一条小鱼
            let f = CGPoint(x: b.x - 1, y: b.y - 5)
            gc.fill(Path(ellipseIn: CGRect(x: f.x - 4, y: f.y - 1.8, width: 7, height: 3.6)), with: .color(.white.opacity(0.9)))
            var fin = Path()
            fin.move(to: CGPoint(x: f.x + 2.5, y: f.y))
            fin.addLine(to: CGPoint(x: f.x + 5.5, y: f.y - 2))
            fin.addLine(to: CGPoint(x: f.x + 5.5, y: f.y + 2))
            fin.closeSubpath()
            gc.fill(fin, with: .color(.white.opacity(0.9)))
        }
    }
}
