import SpriteKit

/// Crisp, code-drawn control icons (no emoji) for a consistent look.
enum ControlIcons {
    static func make(_ key: String) -> SKNode {
        switch key {
        case "dash":     return dash()
        case "shield":   return shield()
        case "disguise": return mask()
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

/// A round touch button with a vector icon and a title label.
final class GameButton: SKNode {
    let key: String
    private let bg: SKShapeNode
    private let ring: SKShapeNode
    private let label: SKLabelNode
    private let icon: SKNode
    private(set) var enabled = true

    init(key: String, glyph: String = "", title: String, color: SKColor, radius: CGFloat = 40) {
        self.key = key
        bg = SKShapeNode(circleOfRadius: radius)
        ring = SKShapeNode(circleOfRadius: radius)
        label = SKLabelNode(text: title)
        icon = ControlIcons.make(key)
        super.init()

        bg.fillColor = color.withAlphaComponent(0.92)
        bg.strokeColor = .clear
        bg.zPosition = ZLayer.hud
        addChild(bg)

        ring.fillColor = .clear
        ring.strokeColor = SKColor(white: 1, alpha: 0.9)
        ring.lineWidth = 2.5
        ring.zPosition = ZLayer.hud + 0.5
        addChild(ring)

        icon.zPosition = ZLayer.hud + 1
        icon.setScale(1.0)
        addChild(icon)

        label.fontName = "AvenirNext-Bold"
        label.fontSize = 11
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -radius - 11)
        label.zPosition = ZLayer.hud + 1
        addChild(label)

        zPosition = ZLayer.hud
    }

    required init?(coder: NSCoder) { fatalError() }

    func setEnabled(_ on: Bool) {
        enabled = on
        alpha = on ? 1.0 : 0.34
    }

    func setTitle(_ t: String) { label.text = t }

    func press() {
        guard enabled else { return }
        bg.run(.sequence([.scale(to: 0.86, duration: 0.05), .scale(to: 1.0, duration: 0.08)]))
        // quick ring flash for feedback
        let flash = SKShapeNode(circleOfRadius: bg.frame.width/2)
        flash.strokeColor = .white; flash.lineWidth = 3; flash.fillColor = .clear
        flash.zPosition = ZLayer.hud + 2; addChild(flash)
        flash.run(.sequence([.group([.scale(to: 1.5, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
    }

    func contains(scenePoint: CGPoint, in scene: SKScene) -> Bool {
        let local = scene.convert(scenePoint, to: self)
        return bg.contains(local)
    }
}
