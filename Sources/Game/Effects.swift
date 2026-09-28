import SpriteKit

/// Reusable visual flourishes: shadows, atmosphere overlays, vignette,
/// ambient particle systems, and the level exit portal.
enum Effects {

    /// Soft elliptical ground shadow placed beneath a character.
    static func groundShadow(width: CGFloat = 34, height: CGFloat = 12) -> SKShapeNode {
        let s = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        s.fillColor = SKColor(white: 0, alpha: 0.22)
        s.strokeColor = .clear
        s.zPosition = -2
        return s
    }

    /// Full-screen tint overlay for time-of-day (parented to the camera).
    static func ambientOverlay(color: SKColor, alpha: CGFloat) -> SKSpriteNode {
        let n = SKSpriteNode(color: color, size: CGSize(width: 4000, height: 4000))
        n.alpha = alpha
        n.colorBlendFactor = 1
        n.blendMode = .alpha
        n.zPosition = ZLayer.fx + 1
        return n
    }

    /// A radial vignette (transparent center → dark edge) sized to the screen.
    static func vignette(screen: CGSize, strength: CGFloat) -> SKSpriteNode {
        let w = max(screen.width, 1), h = max(screen.height, 1)
        let size = CGSize(width: w, height: h)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            let colors = [SKColor(white: 0, alpha: 0).cgColor,
                          SKColor(white: 0, alpha: 0).cgColor,
                          SKColor(white: 0, alpha: strength).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.55, 1])!
            let center = CGPoint(x: w/2, y: h/2)
            c.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                                 endCenter: center, endRadius: max(w, h) * 0.72,
                                 options: [])
        }
        let n = SKSpriteNode(texture: SKTexture(image: img))
        n.zPosition = ZLayer.fx + 2
        return n
    }

    /// Ambient particle field (parented to the camera, fills the screen).
    static func ambient(_ kind: AmbientFX, screen: CGSize) -> SKEmitterNode? {
        guard kind != .none else { return nil }
        let e = SKEmitterNode()
        e.particleTexture = softDot()
        e.zPosition = ZLayer.fx + 3
        e.particlePositionRange = CGVector(dx: screen.width + 200, dy: screen.height + 200)
        switch kind {
        case .fireflies:
            e.particleBirthRate = 8
            e.particleLifetime = 6
            e.particleColor = SKColor(red: 1, green: 0.95, blue: 0.5, alpha: 1)
            e.particleColorBlendFactor = 1
            e.particleSize = CGSize(width: 6, height: 6)
            e.particleAlpha = 0.0; e.particleAlphaSpeed = 0
            e.particleAlphaRange = 0.8
            e.particleSpeed = 14; e.particleSpeedRange = 10
            e.emissionAngleRange = .pi * 2
            e.particleScaleRange = 0.6
            e.particleAlphaSequence = nil
        case .embers:
            e.particleBirthRate = 14
            e.particleLifetime = 4
            e.particleColor = SKColor(red: 1, green: 0.5, blue: 0.15, alpha: 1)
            e.particleColorBlendFactor = 1
            e.particleSize = CGSize(width: 5, height: 5)
            e.particleAlpha = 0.9; e.particleAlphaSpeed = -0.25
            e.particleSpeed = 26; e.particleSpeedRange = 12
            e.emissionAngle = .pi / 2; e.emissionAngleRange = 0.5
            e.yAcceleration = 16
            e.particleScaleRange = 0.5
        case .sparks:
            e.particleBirthRate = 20
            e.particleLifetime = 1.4
            e.particleColor = SKColor(red: 0.4, green: 0.95, blue: 1, alpha: 1)
            e.particleColorBlendFactor = 1
            e.particleSize = CGSize(width: 4, height: 4)
            e.particleAlpha = 1; e.particleAlphaSpeed = -0.7
            e.particleSpeed = 60; e.particleSpeedRange = 40
            e.emissionAngleRange = .pi * 2
            e.particleScaleRange = 0.5
        case .none: break
        }
        return e
    }

    /// A glowing exit portal (rings that spin + pulse). Dim until activated.
    static func portal(accent: SKColor, label: String) -> SKNode {
        let node = SKNode()
        node.name = "exitPortal"

        let glow = SKShapeNode(circleOfRadius: 44)
        glow.fillColor = accent.withAlphaComponent(0.16)
        glow.strokeColor = .clear
        glow.glowWidth = 10
        node.addChild(glow)

        for (i, r) in [40.0, 30.0, 20.0].enumerated() {
            let ring = SKShapeNode(circleOfRadius: r)
            ring.strokeColor = accent.withAlphaComponent(0.9)
            ring.lineWidth = 3
            ring.fillColor = .clear
            ring.glowWidth = 2
            let dur = 3.0 + Double(i)
            ring.run(.repeatForever(.rotate(byAngle: (i % 2 == 0 ? 1 : -1) * .pi * 2, duration: dur)))
            node.addChild(ring)
        }
        let core = SKShapeNode(circleOfRadius: 12)
        core.fillColor = accent
        core.strokeColor = .white
        core.lineWidth = 1.5
        core.glowWidth = 4
        node.addChild(core)

        let tag = RichLabel(text: label)
        tag.fontName = "AvenirNext-Heavy"; tag.fontSize = 13; tag.fontColor = accent
        tag.verticalAlignmentMode = .center
        tag.position = CGPoint(x: 0, y: -60)
        node.addChild(tag)

        node.alpha = 0.35   // inactive until objective met
        node.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 1.0), .scale(to: 1.0, duration: 1.0)])))
        return node
    }

    /// A small soft circular texture used for particles/glows.
    private static func softDot() -> SKTexture {
        let size = CGSize(width: 16, height: 16)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            let c = ctx.cgContext
            let colors = [SKColor(white: 1, alpha: 1).cgColor, SKColor(white: 1, alpha: 0).cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            c.drawRadialGradient(grad, startCenter: CGPoint(x: 8, y: 8), startRadius: 0,
                                 endCenter: CGPoint(x: 8, y: 8), endRadius: 8, options: [])
        }
        return SKTexture(image: img)
    }
}
