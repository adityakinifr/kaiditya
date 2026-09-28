import SpriteKit

/// Crisp, code-drawn control icons (no emoji) for a consistent look.
enum ControlIcons {
    static func make(_ key: String) -> SKNode {
        switch key {
        case "dash":     return dash()
        case "shield":   return shield()
        case "disguise": return mask()
        case "grapple":  return hook()
        default:         return speech()   // interact / talk / charge / fight
        }
    }

    private static func stroke(_ path: CGPath, width: CGFloat = 3.5) -> SKShapeNode {
        let n = SKShapeNode(path: path)
        n.strokeColor = .white
        n.lineWidth = width
        n.lineCap = .round
        n.lineJoin = .round
        n.fillColor = .clear
        return n
    }

    /// Double chevron + speed lines pointing right.
    static func dash() -> SKNode {
        let node = SKNode()
        for dx in [-7.0, 3.0] {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: dx - 4, y: 9))
            p.addLine(to: CGPoint(x: dx + 7, y: 0))
            p.addLine(to: CGPoint(x: dx - 4, y: -9))
            node.addChild(stroke(p))
        }
        for (i, y) in [7.0, 0.0, -7.0].enumerated() {
            let line = SKShapeNode(rectOf: CGSize(width: 8 - CGFloat(i % 2) * 3, height: 3), cornerRadius: 1.5)
            line.fillColor = .white; line.strokeColor = .clear
            line.position = CGPoint(x: -15, y: y)
            node.addChild(line)
        }
        return node
    }

    /// Classic shield silhouette with a vertical highlight.
    static func shield() -> SKNode {
        let node = SKNode()
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 12))
        p.addLine(to: CGPoint(x: 11, y: 6))
        p.addLine(to: CGPoint(x: 11, y: -3))
        p.addQuadCurve(to: CGPoint(x: 0, y: -13), control: CGPoint(x: 11, y: -10))
        p.addQuadCurve(to: CGPoint(x: -11, y: -3), control: CGPoint(x: -11, y: -10))
        p.addLine(to: CGPoint(x: -11, y: 6))
        p.closeSubpath()
        let s = SKShapeNode(path: p)
        s.strokeColor = .white; s.lineWidth = 3; s.fillColor = SKColor(white: 1, alpha: 0.18)
        s.lineJoin = .round
        node.addChild(s)
        let bar = SKShapeNode(rectOf: CGSize(width: 3, height: 14), cornerRadius: 1.5)
        bar.fillColor = .white; bar.strokeColor = .clear; bar.position = CGPoint(x: 0, y: -1)
        node.addChild(bar)
        return node
    }

    /// Superhero domino mask (disguise / secret identity).
    static func mask() -> SKNode {
        let node = SKNode()
        let p = CGMutablePath()
        p.addRoundedRect(in: CGRect(x: -13, y: -7, width: 26, height: 14), cornerWidth: 7, cornerHeight: 7)
        let m = SKShapeNode(path: p)
        m.fillColor = .white; m.strokeColor = .clear
        node.addChild(m)
        for dx in [-5.5, 5.5] {
            let eye = SKShapeNode(ellipseOf: CGSize(width: 5.5, height: 7))
            eye.fillColor = Palette.bush; eye.strokeColor = .clear
            eye.position = CGPoint(x: dx, y: 0)
            node.addChild(eye)
        }
        return node
    }

    /// Grappling hook + rope.
    static func hook() -> SKNode {
        let node = SKNode()
        let rope = CGMutablePath()
        rope.move(to: CGPoint(x: -10, y: -11)); rope.addLine(to: CGPoint(x: 2, y: 4))
        node.addChild(stroke(rope, width: 2.5))
        // hook curve
        let h = CGMutablePath()
        h.addArc(center: CGPoint(x: 2, y: 8), radius: 6, startAngle: .pi * 1.1, endAngle: .pi * 0.1, clockwise: false)
        node.addChild(stroke(h, width: 3))
        let barb = CGMutablePath()
        barb.move(to: CGPoint(x: 8, y: 8)); barb.addLine(to: CGPoint(x: 11, y: 12))
        node.addChild(stroke(barb, width: 2.5))
        return node
    }

    /// Rounded speech bubble (talk / interact).
    static func speech() -> SKNode {
        let node = SKNode()
        let p = CGMutablePath()
        p.addRoundedRect(in: CGRect(x: -12, y: -6, width: 24, height: 18), cornerWidth: 6, cornerHeight: 6)
        let bubble = SKShapeNode(path: p)
        bubble.fillColor = .white; bubble.strokeColor = .clear
        node.addChild(bubble)
        let tail = SKShapeNode(path: {
            let t = CGMutablePath()
            t.move(to: CGPoint(x: -6, y: -5)); t.addLine(to: CGPoint(x: -10, y: -12)); t.addLine(to: CGPoint(x: -1, y: -5))
            t.closeSubpath(); return t
        }())
        tail.fillColor = .white; tail.strokeColor = .clear
        node.addChild(tail)
        for dx in [-5.0, 0.0, 5.0] {
            let dot = SKShapeNode(circleOfRadius: 1.6)
            dot.fillColor = Palette.heroBlue; dot.strokeColor = .clear
            dot.position = CGPoint(x: dx, y: 3)
            node.addChild(dot)
        }
        return node
    }
}

/// A round touch button with a vector icon and a title label, skinned as a toon "toy"
/// disc: 3 pt ink outline, darker bevel rim, flat drop shadow and a glossy top highlight.
/// The disc is a pre-rendered texture (up / pressed / disabled); the hit area is an
/// invisible circle of the original radius, so tap targets are unchanged.
final class GameButton: SKNode {
    let key: String
    private let bg: SKShapeNode          // invisible hit area (same geometry as before)
    private let disc: SKSpriteNode
    private let face = SKNode()          // icon + cooldown sweep; shifts down when pressed
    private let sweep = SKShapeNode()
    private let label: RichLabel
    private var icon: SKNode
    private var iconKey: String
    private let color: SKColor
    private let radius: CGFloat
    private let depth: CGFloat = 3
    private var sweepStep = -1
    private(set) var enabled = true

    init(key: String, glyph: String = "", title: String, color: SKColor, radius: CGFloat = 40) {
        self.key = key
        self.color = color
        self.radius = radius
        bg = SKShapeNode(circleOfRadius: radius)
        disc = SKSpriteNode(texture: ToonArt.disc(color: color, radius: radius, depth: 3))
        label = RichLabel(text: title)
        icon = ControlIcons.make(key)
        iconKey = key
        super.init()

        bg.fillColor = .clear
        bg.strokeColor = .clear
        bg.zPosition = ZLayer.hud
        addChild(bg)

        let lift = ToonArt.discFaceOffset(depth: depth)
        disc.position = CGPoint(x: 0, y: -lift)       // face center lands on the node origin
        disc.zPosition = ZLayer.hud
        addChild(disc)

        face.zPosition = ZLayer.hud + 1
        addChild(face)

        sweep.fillColor = Palette.ink.withAlphaComponent(0.5)
        sweep.strokeColor = .clear
        sweep.zPosition = 0.5
        sweep.isHidden = true
        face.addChild(sweep)

        icon.zPosition = 1
        icon.setScale(radius / 38)
        face.addChild(icon)

        label.fontName = Theme.display
        label.fontSize = 13
        label.fontColor = .white
        label.shadowColor = Palette.ink.withAlphaComponent(0.85)
        label.shadowOffset = CGVector(dx: 0, dy: -1.5)
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -radius - depth - 11)
        label.zPosition = ZLayer.hud + 1
        addChild(label)

        zPosition = ZLayer.hud
    }

    required init?(coder: NSCoder) { fatalError() }

    func setEnabled(_ on: Bool) {
        guard on != enabled else { return }
        enabled = on
        disc.texture = ToonArt.disc(color: color, radius: radius, state: on ? .up : .off, depth: depth)
        icon.alpha = on ? 1 : 0.55
        disc.alpha = on ? 1 : 0.8
        label.alpha = on ? 1 : 0.6
        if on { setCooldown(0) }
    }

    /// Radial cooldown sweep over the face: 1 = fully locked, 0 = ready (hidden).
    func setCooldown(_ frac: CGFloat) {
        let f = max(0, min(1, frac))
        let step = Int((f * 48).rounded(.up))
        guard step != sweepStep else { return }
        sweepStep = step
        guard step > 0 else { sweep.isHidden = true; return }
        let r = radius - 2
        let p = CGMutablePath()
        p.move(to: .zero)
        let start = CGFloat.pi / 2
        p.addArc(center: .zero, radius: r, startAngle: start, endAngle: start + 2 * .pi * CGFloat(step) / 48, clockwise: false)
        p.closeSubpath()
        sweep.path = p
        sweep.isHidden = false
    }

    func setTitle(_ t: String) { if label.text != t { label.text = t } }

    /// Swap the vector icon (the context ACTION button switches between talk/grapple).
    func setIcon(_ key: String) {
        guard key != iconKey else { return }
        iconKey = key
        let scale = icon.xScale, a = icon.alpha
        icon.removeFromParent()
        icon = ControlIcons.make(key); icon.zPosition = 1; icon.setScale(scale); icon.alpha = a
        face.addChild(icon)
    }

    func press() {
        guard enabled else { return }
        Haptics.tap()
        // Pressed: the face drops onto the rim (rim hidden), then springs back.
        let up = ToonArt.disc(color: color, radius: radius, state: .up, depth: depth)
        let down = ToonArt.disc(color: color, radius: radius, state: .down, depth: depth)
        disc.removeAction(forKey: "press"); face.removeAction(forKey: "press")
        disc.texture = down; face.position.y = -depth
        disc.run(.sequence([.wait(forDuration: 0.11), .setTexture(up)]), withKey: "press")
        face.run(.sequence([.wait(forDuration: 0.11), .moveTo(y: 0, duration: 0.05)]), withKey: "press")
        // quick ring flash for feedback
        let flash = SKShapeNode(circleOfRadius: radius + 1)
        flash.strokeColor = .white; flash.lineWidth = 3; flash.fillColor = .clear
        flash.position.y = -depth
        flash.zPosition = ZLayer.hud + 2; addChild(flash)
        flash.run(.sequence([.group([.scale(to: 1.4, duration: 0.22), .fadeOut(withDuration: 0.22)]), .removeFromParent()]))
    }

    func contains(scenePoint: CGPoint, in scene: SKScene) -> Bool {
        let local = scene.convert(scenePoint, to: self)
        return bg.contains(local)
    }
}

/// Light haptic vocabulary: tap for buttons, success for objectives, hit when caught.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let note = UINotificationFeedbackGenerator()
    static func tap() { light.impactOccurred() }
    static func hit() { heavy.impactOccurred() }
    static func success() { note.notificationOccurred(.success) }
}
