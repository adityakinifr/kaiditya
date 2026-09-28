import SpriteKit

/// Central color palette + z-ordering so the world reads cleanly.
enum Palette {
    static let grass      = SKColor(red: 0.45, green: 0.74, blue: 0.42, alpha: 1)
    static let grassDark  = SKColor(red: 0.38, green: 0.66, blue: 0.36, alpha: 1)
    static let path       = SKColor(red: 0.86, green: 0.78, blue: 0.58, alpha: 1)
    static let water      = SKColor(red: 0.40, green: 0.66, blue: 0.86, alpha: 1)
    static let shadowTint = SKColor(red: 0.20, green: 0.16, blue: 0.36, alpha: 1)   // cool violet, never black

    static let heroBlue   = SKColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1)
    static let heroRed    = SKColor(red: 0.94, green: 0.28, blue: 0.30, alpha: 1)
    static let heroSkin   = SKColor(red: 0.98, green: 0.80, blue: 0.66, alpha: 1)
    static let heroHair   = SKColor(red: 0.25, green: 0.17, blue: 0.12, alpha: 1)

    static let villain    = SKColor(red: 0.32, green: 0.22, blue: 0.45, alpha: 1)
    static let minion     = SKColor(red: 0.55, green: 0.30, blue: 0.62, alpha: 1)
    static let crystal    = SKColor(red: 0.30, green: 0.92, blue: 0.85, alpha: 1)

    static let building   = SKColor(red: 0.92, green: 0.88, blue: 0.82, alpha: 1)
    static let roof       = SKColor(red: 0.80, green: 0.45, blue: 0.40, alpha: 1)
    static let bush       = SKColor(red: 0.27, green: 0.55, blue: 0.30, alpha: 1)
    static let tree       = SKColor(red: 0.22, green: 0.48, blue: 0.27, alpha: 1)

    static let hudPanel   = SKColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 0.85)
    static let hudAccent  = SKColor(red: 0.30, green: 0.92, blue: 0.85, alpha: 1)
    static let energy     = SKColor(red: 1.00, green: 0.82, blue: 0.25, alpha: 1)
    static let ink        = SKColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1)
}

enum ZLayer {
    static let ground: CGFloat   = 0
    static let pathDeco: CGFloat = 1
    static let decals: CGFloat   = 2
    static let visionCone: CGFloat = 4
    static let items: CGFloat    = 5
    static let buildings: CGFloat = 8
    static let characters: CGFloat = 10
    static let coverTops: CGFloat  = 14   // bush/tree canopy drawn above characters

    /// Y-sorted depth band (10…13.9) for characters and solid props: lower on screen = drawn in front.
    /// Children of a sorted node use small relative offsets (0…1); cones/marks compensate explicitly.
    static func depth(_ y: CGFloat, worldHeight h: CGFloat) -> CGFloat {
        characters + 3.9 * (1 - min(max(y / max(h, 1), 0), 1))
    }
    static let fx: CGFloat       = 18
    static let hud: CGFloat      = 100
    static let overlay: CGFloat  = 200
}

extension SKColor {
    var lighter: SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: min(r + 0.12, 1), green: min(g + 0.12, 1), blue: min(b + 0.12, 1), alpha: a)
    }
    var darker: SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: max(r - 0.14, 0), green: max(g - 0.14, 0), blue: max(b - 0.14, 0), alpha: a)
    }
}

extension Array {
    /// Deterministic pseudo-random pick seeded by a value (avoids Math.random).
    func randomishPick(_ seed: CGFloat) -> Element {
        let i = Int(abs(seed / 37).rounded()) % Swift.max(count, 1)
        return self[i]
    }
}

func roundedRect(size: CGSize, corner: CGFloat, color: SKColor, stroke: SKColor? = nil, lineWidth: CGFloat = 0) -> SKShapeNode {
    let n = SKShapeNode(rectOf: size, cornerRadius: corner)
    n.fillColor = color
    n.lineWidth = lineWidth
    n.strokeColor = stroke ?? .clear
    return n
}
