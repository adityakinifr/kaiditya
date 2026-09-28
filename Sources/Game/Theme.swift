import SpriteKit
import UIKit

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

// MARK: - UI skin ("toy set" HUD that matches the toon-shaded world)

/// Typography + shared UI metrics. Display = Lilita One (bundled, OFL) for titles,
/// level names, button labels, big numbers and toasts; body = Avenir Next for small text.
enum Theme {
    static let display     = "LilitaOne"
    static let body        = "AvenirNext-DemiBold"
    static let bodyBold    = "AvenirNext-Bold"
    static let bodyMedium  = "AvenirNext-Medium"

    /// Ink outline width on buttons/panels (art direction: 3 px ink on HUD).
    static let outline: CGFloat = 3
    /// Default panel fill: deep indigo, opaque enough to read over any biome.
    static let panelFill   = SKColor(red: 0.15, green: 0.17, blue: 0.29, alpha: 0.96)
    static let panelHUD    = SKColor(red: 0.15, green: 0.17, blue: 0.29, alpha: 0.90)
    static let textDim     = SKColor(red: 0.78, green: 0.81, blue: 0.90, alpha: 1)
}

/// Pre-rendered toon textures for panels, buttons and discs. Everything is drawn once
/// with Core Graphics (ink outline, bevel, drop shadow baked in) and cached, so the UI
/// costs a handful of sprites instead of stacks of SKShapeNodes.
enum ToonArt {
    private static var cache: [String: SKTexture] = [:]
    private static var scale: CGFloat { UIScreen.main.scale }

    static func colorKey(_ c: SKColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%.3f,%.3f,%.3f,%.3f", r, g, b, a)
    }

    static func shade(_ c: SKColor, _ d: CGFloat) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        func f(_ v: CGFloat) -> CGFloat { d >= 0 ? v + (1 - v) * d : v * (1 + d) }
        return SKColor(red: f(r), green: f(g), blue: f(b), alpha: a)
    }

    static func desaturate(_ c: SKColor) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let l = r * 0.3 + g * 0.59 + b * 0.11
        let m: (CGFloat) -> CGFloat = { $0 * 0.25 + l * 0.75 * 0.85 }
        return SKColor(red: m(r), green: m(g), blue: m(b), alpha: a)
    }

    private static func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> SKTexture {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = scale
        let img = UIGraphicsImageRenderer(size: size, format: fmt).image { draw($0.cgContext) }
        let t = SKTexture(image: img)
        t.filteringMode = .linear
        return t
    }

    // MARK: Rounded rect (panel / pill button), 9-slice

    struct RectStyle {
        var corner: CGFloat
        var fill: SKColor
        var trim: SKColor? = nil        // thin inner accent ring
        var outline: CGFloat = Theme.outline
        var shadow: CGFloat = 4         // flat toon drop shadow depth (inside the frame)
        var rim: CGFloat = 0            // button bevel: darker "side" depth
        var key: String {
            "rr|\(corner)|\(colorKey(fill))|\(trim.map(colorKey) ?? "-")|\(outline)|\(shadow)|\(rim)"
        }
    }

    /// Source texture for a 9-slice rounded rect. The visible body sits at the top of the
    /// texture; the drop shadow (and button rim) occupy the bottom `shadow + rim` points,
    /// so a sprite's frame is exactly the requested size (hit areas stay unchanged).
    static func roundedTexture(_ s: RectStyle) -> SKTexture {
        if let t = cache[s.key] { return t }
        let o = s.outline, c = s.corner
        let w = 2 * (c + o) + 2
        let h = 2 * (c + o) + 2 + s.shadow + s.rim
        let t = render(CGSize(width: w, height: h)) { ctx in
            let face = CGRect(x: o / 2, y: o / 2, width: w - o, height: h - o - s.shadow - s.rim)
            let r = c + o / 2
            let facePath = UIBezierPath(roundedRect: face, cornerRadius: r)
            let fullPath = UIBezierPath(roundedRect: CGRect(x: face.minX, y: face.minY, width: face.width, height: face.height + s.rim), cornerRadius: r)
            // Drop shadow: flat, cool-ink, clipped outside the body so translucent fills stay clean.
            if s.shadow > 0 {
                ctx.saveGState()
                ctx.addRect(CGRect(x: 0, y: 0, width: w, height: h)); ctx.addPath(fullPath.cgPath)
                ctx.clip(using: .evenOdd)
                Palette.ink.withAlphaComponent(0.30).setFill()
                UIBezierPath(roundedRect: fullPath.bounds.offsetBy(dx: 0, dy: s.shadow), cornerRadius: r).fill()
                Palette.ink.withAlphaComponent(0.18).setFill()
                UIBezierPath(roundedRect: fullPath.bounds.offsetBy(dx: 0, dy: s.shadow * 0.5), cornerRadius: r).fill()
                ctx.restoreGState()
            }
            // Button rim (darker side of the "toy" cylinder).
            if s.rim > 0 {
                shade(s.fill, -0.32).setFill(); fullPath.fill()
            }
            // Face with a lighter top edge and (panels) a slightly darker bottom edge.
            ctx.saveGState()
            facePath.addClip()
            shade(s.fill, s.rim > 0 ? -0.10 : -0.12).setFill(); facePath.fill()
            ctx.saveGState()
            UIBezierPath(roundedRect: face.offsetBy(dx: 0, dy: -2.5), cornerRadius: r).addClip()
            shade(s.fill, s.rim > 0 ? 0.30 : 0.16).setFill(); facePath.fill()
            s.fill.setFill()
            UIBezierPath(roundedRect: face.offsetBy(dx: 0, dy: s.rim > 0 ? 2.5 : 3), cornerRadius: r).fill()
            ctx.restoreGState()
            ctx.restoreGState()
            if let trim = s.trim {
                let inset = face.insetBy(dx: o / 2 + 1.6, dy: o / 2 + 1.6)
                let tp = UIBezierPath(roundedRect: inset, cornerRadius: max(1, r - o / 2 - 1.6))
                tp.lineWidth = 2; trim.withAlphaComponent(0.9).setStroke(); tp.stroke()
            }
            // Ink outline around the whole silhouette (face + rim).
            if o > 0 { fullPath.lineWidth = o; Palette.ink.setStroke(); fullPath.stroke() }
            if s.rim > 0 {
                // thin ink seam where the face meets the rim
                ctx.saveGState(); fullPath.addClip()
                let seam = UIBezierPath(roundedRect: face, cornerRadius: r)
                seam.lineWidth = 1.5; Palette.ink.withAlphaComponent(0.55).setStroke(); seam.stroke()
                ctx.restoreGState()
            }
        }
        cache[s.key] = t
        return t
    }

    /// A 9-slice rounded panel/button sprite whose frame is exactly `size`.
    static func rect(size: CGSize, style: RectStyle) -> SKSpriteNode {
        var s = style
        // Clamp the corner so the fixed-size slices always fit inside the frame.
        let maxCorner = max(2, min((size.height - s.shadow - s.rim - 2 * s.outline - 2) / 2,
                                   (size.width - 2 * s.outline - 2) / 2))
        s.corner = min(s.corner, maxCorner).rounded(.down)
        let tex = roundedTexture(s)
        let ts = tex.size()
        let n = SKSpriteNode(texture: tex)
        let cx = s.corner + s.outline
        let cy = s.shadow + s.rim + s.corner + s.outline   // measured from the bottom
        n.centerRect = CGRect(x: cx / ts.width, y: cy / ts.height, width: 2 / ts.width, height: 2 / ts.height)
        n.size = size
        return n
    }

    /// Standard info panel: ink outline, lighter inner top edge, soft drop shadow.
    /// Returned as a container (background sprite at z -1) so children added by call sites
    /// always draw above it, even with `ignoresSiblingOrder`.
    static func panel(size: CGSize, corner: CGFloat = 18, fill: SKColor = Theme.panelFill, trim: SKColor? = nil) -> SKNode {
        let n = SKNode()
        let bg = rect(size: size, style: RectStyle(corner: corner, fill: fill, trim: trim))
        bg.zPosition = -1; bg.name = "panelBG"
        n.addChild(bg)
        return n
    }

    /// Chunky pill/rounded button: bevel rim + highlight + ink outline, with a display-font label.
    /// The label is centered on the button *face* (above the rim/shadow band). Frame == `size`.
    static func button(size: CGSize, color: SKColor, text: String, fontSize: CGFloat = 20, corner: CGFloat? = nil) -> SKNode {
        let style = RectStyle(corner: corner ?? size.height / 2, fill: color, shadow: 3, rim: 4)
        let n = SKNode()
        let bg = rect(size: size, style: style)
        bg.zPosition = -0.5; bg.name = "panelBG"   // above a parent panel's bg (-1), below labels
        n.addChild(bg)
        let l = RichLabel(text: text)
        l.fontName = Theme.display; l.fontSize = fontSize; l.fontColor = .white
        l.shadowColor = Palette.ink.withAlphaComponent(0.55); l.shadowOffset = CGVector(dx: 0, dy: -1.5)
        l.verticalAlignmentMode = .center; l.horizontalAlignmentMode = .center
        l.position = CGPoint(x: 0, y: (style.shadow + style.rim) / 2)
        l.name = "btnLabel"; l.zPosition = 1
        n.addChild(l)
        return n
    }

    // MARK: Discs (round action buttons, map nodes, joystick knob)

    enum DiscState: String { case up, down, off }

    /// Round "toy" button. Canvas is (2R+4) x (2R+4+depth+shadow); the face center sits
    /// `discFaceOffset(radius)` above the texture center.
    static func disc(color: SKColor, radius: CGFloat, state: DiscState = .up, depth: CGFloat = 4) -> SKTexture {
        let key = "disc|\(colorKey(color))|\(radius)|\(state.rawValue)|\(depth)"
        if let t = cache[key] { return t }
        let o = Theme.outline, R = radius + 1, sh: CGFloat = 3
        let w = 2 * R + 4, h = 2 * R + 4 + depth + sh
        let fill = state == .off ? desaturate(color) : color
        let t = render(CGSize(width: w, height: h)) { ctx in
            let cx = w / 2, top = 2 + R
            let press: CGFloat = state == .down ? depth : 0
            func circ(_ y: CGFloat, _ r: CGFloat) -> CGRect { CGRect(x: cx - r, y: y - r, width: 2 * r, height: 2 * r) }
            // shadow
            Palette.ink.withAlphaComponent(0.28).setFill()
            ctx.fillEllipse(in: circ(top + depth + sh, R))
            // ink silhouette (face + side)
            Palette.ink.setFill()
            ctx.fillEllipse(in: circ(top + depth, R))
            ctx.fill(CGRect(x: cx - R, y: top + press, width: 2 * R, height: depth - press))
            ctx.fillEllipse(in: circ(top + press, R))
            // side / rim
            if press == 0 {
                shade(fill, -0.34).setFill()
                ctx.fillEllipse(in: circ(top + depth, R - o))
                ctx.fill(CGRect(x: cx - (R - o), y: top, width: 2 * (R - o), height: depth))
            }
            // face
            let fr = circ(top + press, R - o)
            ctx.saveGState()
            ctx.addEllipse(in: fr); ctx.clip()
            shade(fill, -0.12).setFill(); ctx.fill(fr)
            ctx.saveGState()
            ctx.addEllipse(in: fr.offsetBy(dx: 0, dy: -2.5)); ctx.clip()
            shade(fill, 0.32).setFill(); ctx.fill(fr)
            fill.setFill(); ctx.fillEllipse(in: fr.offsetBy(dx: 0, dy: 2.2))
            ctx.restoreGState()
            // glossy top highlight
            UIColor(white: 1, alpha: 0.22).setFill()
            ctx.fillEllipse(in: CGRect(x: cx - (R - o) * 0.62, y: fr.minY + (R - o) * 0.14, width: (R - o) * 1.24, height: (R - o) * 0.62))
            ctx.restoreGState()
            if press == 0 {
                Palette.ink.withAlphaComponent(0.5).setStroke(); ctx.setLineWidth(1.2)
                ctx.strokeEllipse(in: fr.insetBy(dx: -0.6, dy: -0.6))
            }
        }
        cache[key] = t
        return t
    }

    /// Offset from a disc texture's center to its face center (positive = up).
    static func discFaceOffset(depth: CGFloat = 4) -> CGFloat { (depth + 3) / 2 }

    /// Translucent joystick base: soft fill, white inner ring and ink outline.
    static func ring(radius: CGFloat) -> SKTexture {
        let key = "ring|\(radius)"
        if let t = cache[key] { return t }
        let w = 2 * radius + 6
        let t = render(CGSize(width: w, height: w)) { ctx in
            let c = w / 2
            func circ(_ r: CGFloat) -> CGRect { CGRect(x: c - r, y: c - r, width: 2 * r, height: 2 * r) }
            UIColor(white: 1, alpha: 0.16).setFill(); ctx.fillEllipse(in: circ(radius))
            ctx.setLineWidth(Theme.outline); Palette.ink.withAlphaComponent(0.55).setStroke()
            ctx.strokeEllipse(in: circ(radius))
            ctx.setLineWidth(2); UIColor(white: 1, alpha: 0.55).setStroke()
            ctx.strokeEllipse(in: circ(radius - 3))
            // direction ticks
            UIColor(white: 1, alpha: 0.5).setFill()
            for i in 0..<4 {
                let a = CGFloat(i) * .pi / 2
                ctx.saveGState(); ctx.translateBy(x: c, y: c); ctx.rotate(by: a)
                let p = CGMutablePath()
                p.move(to: CGPoint(x: radius - 10, y: 0))
                p.addLine(to: CGPoint(x: radius - 17, y: -6)); p.addLine(to: CGPoint(x: radius - 17, y: 6)); p.closeSubpath()
                ctx.addPath(p); ctx.fillPath(); ctx.restoreGState()
            }
        }
        cache[key] = t
        return t
    }
}

/// Small drawn HUD icons with an ink outline (heart, coin, star, crystal), replacing emoji
/// and flat shape nodes in the HUD. Drawn in a 24-unit box, cached per size.
enum ToonIcon: String {
    case heart, heartEmpty, coin, star, starEmpty, crystal

    private static var cache: [String: SKTexture] = [:]

    func sprite(_ size: CGFloat) -> SKSpriteNode {
        let s = SKSpriteNode(texture: texture(size))
        s.size = CGSize(width: size, height: size)
        return s
    }

    func texture(_ size: CGFloat) -> SKTexture {
        let key = "\(rawValue)|\(size)"
        if let t = Self.cache[key] { return t }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = UIScreen.main.scale
        let img = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt).image { r in
            let c = r.cgContext
            c.translateBy(x: size / 2, y: size / 2)
            c.scaleBy(x: size / 24, y: -size / 24)
            c.setLineJoin(.round); c.setLineCap(.round)
            draw(c)
        }
        let t = SKTexture(image: img)
        Self.cache[key] = t
        return t
    }

    private func fillStroke(_ c: CGContext, _ p: CGPath, _ fill: UIColor, lw: CGFloat = 2.4) {
        c.addPath(p); c.setFillColor(fill.cgColor); c.fillPath()
        c.addPath(p); c.setStrokeColor(Palette.ink.cgColor); c.setLineWidth(lw); c.strokePath()
    }

    private func starPath(outer: CGFloat, inner: CGFloat, dy: CGFloat = 0) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let a = CGFloat(i) * .pi / 5 + .pi / 2
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r + dy)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath(); return p
    }

    private func draw(_ c: CGContext) {
        let hi = UIColor(white: 1, alpha: 0.55)
        switch self {
        case .heart, .heartEmpty:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: -9))
            p.addCurve(to: CGPoint(x: -9.6, y: 2.5), control1: CGPoint(x: -4, y: -5.5), control2: CGPoint(x: -9.6, y: -2))
            p.addArc(center: CGPoint(x: -4.8, y: 3.6), radius: 4.9, startAngle: .pi, endAngle: 0.1, clockwise: true)
            p.addArc(center: CGPoint(x: 4.8, y: 3.6), radius: 4.9, startAngle: .pi - 0.1, endAngle: 0, clockwise: true)
            p.addCurve(to: CGPoint(x: 0, y: -9), control1: CGPoint(x: 9.6, y: -2), control2: CGPoint(x: 4, y: -5.5))
            let fill = self == .heart ? Palette.heroRed : UIColor(red: 0.30, green: 0.30, blue: 0.40, alpha: 0.9)
            fillStroke(c, p, fill)
            if self == .heart {
                c.setFillColor(hi.cgColor); c.fillEllipse(in: CGRect(x: -7.2, y: 2.6, width: 3.6, height: 4))
            }
        case .coin:
            let r = CGRect(x: -9.5, y: -9.5, width: 19, height: 19)
            c.setFillColor(UIColor(red: 0.85, green: 0.58, blue: 0.10, alpha: 1).cgColor); c.fillEllipse(in: r)
            c.setFillColor(Palette.energy.cgColor); c.fillEllipse(in: r.insetBy(dx: 1.2, dy: 1.2).offsetBy(dx: 0, dy: 1))
            c.setStrokeColor(UIColor(red: 0.80, green: 0.52, blue: 0.08, alpha: 1).cgColor); c.setLineWidth(1.6)
            c.strokeEllipse(in: r.insetBy(dx: 4.2, dy: 4.2).offsetBy(dx: 0, dy: 0.6))
            c.setFillColor(hi.cgColor); c.fillEllipse(in: CGRect(x: -6, y: 2.5, width: 4, height: 4))
            c.setStrokeColor(Palette.ink.cgColor); c.setLineWidth(2.4); c.strokeEllipse(in: r)
        case .star, .starEmpty:
            let p = starPath(outer: 10.6, inner: 4.9, dy: -0.4)
            let fill = self == .star ? UIColor(red: 1.0, green: 0.80, blue: 0.20, alpha: 1)
                                     : UIColor(red: 0.30, green: 0.31, blue: 0.42, alpha: 1)
            fillStroke(c, p, fill, lw: 2.2)
            if self == .star {
                c.setFillColor(hi.cgColor); c.fillEllipse(in: CGRect(x: -3.2, y: 1.8, width: 3, height: 3.6))
            }
        case .crystal:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: 0, y: 10.5), CGPoint(x: 7.5, y: 3), CGPoint(x: 0, y: -10.5), CGPoint(x: -7.5, y: 3)])
            p.closeSubpath()
            fillStroke(c, p, Palette.crystal)
            let f = CGMutablePath()
            f.addLines(between: [CGPoint(x: 0, y: 10.5), CGPoint(x: -7.5, y: 3), CGPoint(x: 0, y: 1.5)]); f.closeSubpath()
            c.addPath(f); c.setFillColor(hi.cgColor); c.fillPath()
            let d = CGMutablePath()
            d.addLines(between: [CGPoint(x: 0, y: -10.5), CGPoint(x: 7.5, y: 3), CGPoint(x: 0, y: 1.5)]); d.closeSubpath()
            c.addPath(d); c.setFillColor(UIColor(red: 0.12, green: 0.55, blue: 0.60, alpha: 0.55).cgColor); c.fillPath()
            c.addPath(p); c.setStrokeColor(Palette.ink.cgColor); c.setLineWidth(2.4); c.strokePath()
        }
    }
}
