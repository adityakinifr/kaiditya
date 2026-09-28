import SpriteKit
import UIKit

/// Code-drawn icons that stand in for emoji/symbols. SpriteKit labels render any
/// glyph missing from their font (every emoji, ★, ♥, ⚡, ▶ …) as a "?" box, so
/// these are drawn with Core Graphics instead and never depend on fonts.
enum GlyphIcon: String, CaseIterable {
    case heart, bolt, star, sparkle, burst, play, back, check, cross, coin, magnet, lock
    case speaker, muted, boot, wind, shield, battery, target, flame, cart, home, map
    case stats, pie, car, mask

    static let lookup: [Character: GlyphIcon] = [
        "♥": .heart, "❤": .heart, "❤️": .heart, "💔": .heart, "🐶": .heart,
        "⚡": .bolt, "★": .star, "⭐": .star, "⭐️": .star, "🦸": .star, "🎉": .star,
        "✦": .sparkle, "✨": .sparkle, "💫": .sparkle, "💥": .burst,
        "▶": .play, "▸": .play, "◂": .back, "✓": .check, "✕": .cross,
        "🪙": .coin, "💰": .coin, "🧲": .magnet, "🔒": .lock,
        "🔊": .speaker, "🔇": .muted, "👟": .boot, "💨": .wind, "🛡": .shield, "🛡️": .shield,
        "🔋": .battery, "🎯": .target, "🔥": .flame, "🛒": .cart, "🏠": .home,
        "🗺": .map, "🗺️": .map, "📊": .stats, "🥧": .pie,
        "🏎": .car, "🏎️": .car, "🚓": .car, "🥸": .mask,
    ]

    /// Icons with a fixed color regardless of the surrounding text color.
    var intrinsicColor: UIColor? {
        switch self {
        case .star, .coin: return UIColor(red: 1.0, green: 0.80, blue: 0.20, alpha: 1)
        case .flame: return UIColor(red: 1.0, green: 0.50, blue: 0.15, alpha: 1)
        case .pie: return UIColor(red: 0.93, green: 0.68, blue: 0.35, alpha: 1)
        default: return nil
        }
    }

    private static var cache: [String: SKTexture] = [:]

    func texture(size: CGFloat, color: UIColor) -> SKTexture {
        let tint = intrinsicColor ?? color
        let key = "\(rawValue)|\(Int(size * 10))|\(tint.description)"
        if let t = Self.cache[key] { return t }
        let img = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: size / 2, y: size / 2)
            c.scaleBy(x: size / 24, y: -size / 24)   // 24-unit box, y up
            c.setFillColor(tint.cgColor); c.setStrokeColor(tint.cgColor)
            c.setLineCap(.round); c.setLineJoin(.round); c.setLineWidth(2.6)
            draw(in: c, tint: tint)
        }
        let t = SKTexture(image: img)
        Self.cache[key] = t
        return t
    }

    private func star(points: Int, outer: CGFloat, inner: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0..<(points * 2) {
            let r = i % 2 == 0 ? outer : inner
            let a = CGFloat(i) * .pi / CGFloat(points) + .pi / 2
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath(); return p
    }

    private func draw(in c: CGContext, tint: UIColor) {
        let dark = UIColor(white: 0, alpha: 0.28).cgColor
        switch self {
        case .heart:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: -9))
            p.addCurve(to: CGPoint(x: -10, y: 3), control1: CGPoint(x: -4, y: -5), control2: CGPoint(x: -10, y: -2))
            p.addArc(center: CGPoint(x: -5, y: 4), radius: 5.1, startAngle: .pi, endAngle: 0.15, clockwise: true)
            p.addArc(center: CGPoint(x: 5, y: 4), radius: 5.1, startAngle: .pi - 0.15, endAngle: 0, clockwise: true)
            p.addCurve(to: CGPoint(x: 0, y: -9), control1: CGPoint(x: 10, y: -2), control2: CGPoint(x: 4, y: -5))
            c.addPath(p); c.fillPath()
        case .bolt:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: 3, y: 11), CGPoint(x: -7, y: -1), CGPoint(x: -1, y: -1),
                                 CGPoint(x: -3, y: -11), CGPoint(x: 7, y: 2), CGPoint(x: 1, y: 2)])
            p.closeSubpath(); c.addPath(p); c.fillPath()
        case .star:
            c.addPath(star(points: 5, outer: 11, inner: 4.8)); c.fillPath()
        case .sparkle:
            c.addPath(star(points: 4, outer: 11, inner: 3)); c.fillPath()
        case .burst:
            c.addPath(star(points: 8, outer: 11, inner: 5.5)); c.fillPath()
        case .play:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: -6, y: 9), CGPoint(x: 9, y: 0), CGPoint(x: -6, y: -9)])
            p.closeSubpath(); c.addPath(p); c.fillPath()
        case .back:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: 6, y: 9), CGPoint(x: -9, y: 0), CGPoint(x: 6, y: -9)])
            p.closeSubpath(); c.addPath(p); c.fillPath()
        case .check:
            c.setLineWidth(3.4)
            c.addLines(between: [CGPoint(x: -8, y: 0), CGPoint(x: -2, y: -6), CGPoint(x: 9, y: 7)]); c.strokePath()
        case .cross:
            c.setLineWidth(3.4)
            c.move(to: CGPoint(x: -7, y: 7)); c.addLine(to: CGPoint(x: 7, y: -7))
            c.move(to: CGPoint(x: 7, y: 7)); c.addLine(to: CGPoint(x: -7, y: -7)); c.strokePath()
        case .coin:
            c.fillEllipse(in: CGRect(x: -10, y: -10, width: 20, height: 20))
            c.setStrokeColor(dark); c.setLineWidth(2)
            c.strokeEllipse(in: CGRect(x: -6.5, y: -6.5, width: 13, height: 13))
        case .magnet:
            c.setLineWidth(5); c.setLineCap(.butt)
            c.addArc(center: CGPoint(x: 0, y: -1), radius: 6.5, startAngle: .pi, endAngle: 0, clockwise: false)
            c.move(to: CGPoint(x: -6.5, y: -1)); c.addLine(to: CGPoint(x: -6.5, y: 8))
            c.move(to: CGPoint(x: 6.5, y: -1)); c.addLine(to: CGPoint(x: 6.5, y: 8)); c.strokePath()
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(x: -9, y: 6, width: 5, height: 4)); c.fill(CGRect(x: 4, y: 6, width: 5, height: 4))
        case .lock:
            c.setLineWidth(2.8)
            c.addArc(center: CGPoint(x: 0, y: 2), radius: 5, startAngle: 0, endAngle: .pi, clockwise: false); c.strokePath()
            c.addPath(CGPath(roundedRect: CGRect(x: -8, y: -10, width: 16, height: 12), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)); c.fillPath()
        case .speaker, .muted:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: -10, y: -4), CGPoint(x: -5, y: -4), CGPoint(x: 1, y: -9),
                                 CGPoint(x: 1, y: 9), CGPoint(x: -5, y: 4), CGPoint(x: -10, y: 4)])
            p.closeSubpath(); c.addPath(p); c.fillPath()
            c.setLineWidth(2.2)
            if self == .speaker {
                c.addArc(center: CGPoint(x: 2, y: 0), radius: 5, startAngle: -0.8, endAngle: 0.8, clockwise: false); c.strokePath()
                c.addArc(center: CGPoint(x: 2, y: 0), radius: 9, startAngle: -0.8, endAngle: 0.8, clockwise: false); c.strokePath()
            } else {
                c.move(to: CGPoint(x: 5, y: 4)); c.addLine(to: CGPoint(x: 11, y: -4))
                c.move(to: CGPoint(x: 11, y: 4)); c.addLine(to: CGPoint(x: 5, y: -4)); c.strokePath()
            }
        case .boot:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: -7, y: 10), CGPoint(x: 0, y: 10), CGPoint(x: 1, y: -1),
                                 CGPoint(x: 10, y: -3), CGPoint(x: 10, y: -9), CGPoint(x: -8, y: -9)])
            p.closeSubpath(); c.addPath(p); c.fillPath()
        case .wind:
            c.setLineWidth(2.6)
            for (y, w) in [(6.0, 16.0), (0.0, 20.0), (-6.0, 13.0)] {
                c.move(to: CGPoint(x: -10, y: y)); c.addLine(to: CGPoint(x: -10 + w, y: y))
            }
            c.strokePath()
        case .shield:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 11)); p.addLine(to: CGPoint(x: 10, y: 6)); p.addLine(to: CGPoint(x: 10, y: -2))
            p.addQuadCurve(to: CGPoint(x: 0, y: -11), control: CGPoint(x: 10, y: -8))
            p.addQuadCurve(to: CGPoint(x: -10, y: -2), control: CGPoint(x: -10, y: -8))
            p.addLine(to: CGPoint(x: -10, y: 6)); p.closeSubpath(); c.addPath(p); c.fillPath()
        case .battery:
            c.setLineWidth(2.4)
            c.addPath(CGPath(roundedRect: CGRect(x: -6, y: -10, width: 12, height: 18), cornerWidth: 2, cornerHeight: 2, transform: nil)); c.strokePath()
            c.fill(CGRect(x: -2.5, y: 8, width: 5, height: 3)); c.fill(CGRect(x: -3, y: -7, width: 6, height: 9))
        case .target:
            c.setLineWidth(2.4)
            c.strokeEllipse(in: CGRect(x: -10, y: -10, width: 20, height: 20))
            c.strokeEllipse(in: CGRect(x: -5.5, y: -5.5, width: 11, height: 11))
            c.fillEllipse(in: CGRect(x: -2, y: -2, width: 4, height: 4))
        case .flame:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 11))
            p.addCurve(to: CGPoint(x: 0, y: -10), control1: CGPoint(x: 14, y: 0), control2: CGPoint(x: 10, y: -10))
            p.addCurve(to: CGPoint(x: 0, y: 11), control1: CGPoint(x: -10, y: -10), control2: CGPoint(x: -12, y: 2))
            c.addPath(p); c.fillPath()
            c.setFillColor(UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: -3.5, y: -8, width: 7, height: 9))
        case .cart:
            c.setLineWidth(2.4)
            c.addLines(between: [CGPoint(x: -11, y: 8), CGPoint(x: -7, y: 8), CGPoint(x: -4, y: -4), CGPoint(x: 8, y: -4), CGPoint(x: 10, y: 4), CGPoint(x: -6, y: 4)])
            c.strokePath()
            c.fillEllipse(in: CGRect(x: -5, y: -10, width: 4, height: 4)); c.fillEllipse(in: CGRect(x: 5, y: -10, width: 4, height: 4))
        case .home:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: 0, y: 11), CGPoint(x: 11, y: 1), CGPoint(x: 7, y: 1), CGPoint(x: 7, y: -10),
                                 CGPoint(x: -7, y: -10), CGPoint(x: -7, y: 1), CGPoint(x: -11, y: 1)])
            p.closeSubpath(); c.addPath(p); c.fillPath()
            c.setFillColor(dark); c.fill(CGRect(x: -2.5, y: -10, width: 5, height: 7))
        case .map:
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: -11, y: 8), CGPoint(x: -4, y: 10), CGPoint(x: 4, y: 7), CGPoint(x: 11, y: 9),
                                 CGPoint(x: 11, y: -8), CGPoint(x: 4, y: -10), CGPoint(x: -4, y: -7), CGPoint(x: -11, y: -9)])
            p.closeSubpath(); c.addPath(p); c.fillPath()
            c.setStrokeColor(dark); c.setLineWidth(1.5)
            c.move(to: CGPoint(x: -4, y: 10)); c.addLine(to: CGPoint(x: -4, y: -7))
            c.move(to: CGPoint(x: 4, y: 7)); c.addLine(to: CGPoint(x: 4, y: -10)); c.strokePath()
        case .stats:
            for (x, h) in [(-9.0, 9.0), (-2.5, 16.0), (4.0, 12.0)] { c.fill(CGRect(x: x, y: -10, width: 5, height: h)) }
        case .pie:
            c.fillEllipse(in: CGRect(x: -11, y: -8, width: 22, height: 14))
            c.setStrokeColor(UIColor(red: 0.62, green: 0.38, blue: 0.16, alpha: 1).cgColor); c.setLineWidth(1.6)
            for x in [-5.0, 0.0, 5.0] { c.move(to: CGPoint(x: x - 2, y: 2)); c.addLine(to: CGPoint(x: x + 2, y: -3)) }
            c.strokePath()
        case .car:
            c.addPath(CGPath(roundedRect: CGRect(x: -11, y: -4, width: 22, height: 8), cornerWidth: 3, cornerHeight: 3, transform: nil)); c.fillPath()
            c.addPath(CGPath(roundedRect: CGRect(x: -6, y: 2, width: 12, height: 7), cornerWidth: 3, cornerHeight: 3, transform: nil)); c.fillPath()
            c.setFillColor(dark)
            c.fillEllipse(in: CGRect(x: -9, y: -8, width: 6, height: 6)); c.fillEllipse(in: CGRect(x: 3, y: -8, width: 6, height: 6))
        case .mask:
            c.addPath(CGPath(roundedRect: CGRect(x: -11, y: -5, width: 22, height: 11), cornerWidth: 5.5, cornerHeight: 5.5, transform: nil)); c.fillPath()
            c.setFillColor(dark)
            c.fillEllipse(in: CGRect(x: -7.5, y: -2.5, width: 5, height: 6)); c.fillEllipse(in: CGRect(x: 2.5, y: -2.5, width: 5, height: 6))
        }
    }
}

/// Drop-in replacement for SKLabelNode that renders emoji/symbols as GlyphIcons.
/// Every property setter re-lays out, so call sites can set text/font in any order.
final class RichLabel: SKNode {
    var text: String? { didSet { relayout() } }
    var fontName: String? = "AvenirNext-Bold" { didSet { relayout() } }
    var fontSize: CGFloat = 32 { didSet { relayout() } }
    var fontColor: SKColor? = .white { didSet { relayout() } }
    var horizontalAlignmentMode: SKLabelHorizontalAlignmentMode = .center { didSet { relayout() } }
    var verticalAlignmentMode: SKLabelVerticalAlignmentMode = .baseline { didSet { relayout() } }

    private let content = SKNode()

    init(text: String? = nil) {
        super.init()
        addChild(content)
        self.text = text
        relayout()
    }

    convenience init(fontNamed name: String?) {
        self.init(text: nil)
        fontName = name
    }

    required init?(coder: NSCoder) { fatalError() }

    override var frame: CGRect { calculateAccumulatedFrame() }

    private enum Run { case text(String), icon(GlyphIcon) }

    private static let safe: Set<Character> = ["—", "·", "…", "»", "«", "’", "‘", "“", "”", "–"]

    private func runs(_ s: String) -> [Run] {
        var out: [Run] = []
        var buf = ""
        for ch in s {
            if let icon = GlyphIcon.lookup[ch] ?? GlyphIcon.lookup[Character(String(ch.unicodeScalars.filter { $0.value != 0xFE0F }))] {
                if !buf.isEmpty { out.append(.text(buf)); buf = "" }
                out.append(.icon(icon))
            } else if ch.isASCII || Self.safe.contains(ch) {
                buf.append(ch)
            }
        }
        if !buf.isEmpty { out.append(.text(buf)) }
        return out
    }

    var numberOfLines: Int = 1 { didSet { relayout() } }
    var preferredMaxLayoutWidth: CGFloat = 0 { didSet { relayout() } }

    private func plainLabel(_ s: String) -> SKLabelNode {
        let l = SKLabelNode(text: s)
        l.fontName = fontName; l.fontSize = fontSize; l.fontColor = fontColor ?? .white
        return l
    }

    /// Lays out one line of runs left-to-right from x = 0; returns its width.
    private func buildLine(_ parts: [Run], into node: SKNode, vmode: SKLabelVerticalAlignmentMode) -> CGFloat {
        let color = fontColor ?? .white
        let gap = fontSize * 0.12
        var x: CGFloat = 0
        for (i, run) in parts.enumerated() {
            switch run {
            case .text(let s):
                let l = plainLabel(s)
                l.horizontalAlignmentMode = .left; l.verticalAlignmentMode = vmode
                l.position.x = x; node.addChild(l)
                x += l.frame.width
                if s.hasSuffix(" ") && i < parts.count - 1 { x += fontSize * 0.26 }
            case .icon(let icon):
                let prevSpace: Bool = { if i > 0, case .text(let t) = parts[i - 1] { return t.hasSuffix(" ") }; return true }()
                if !prevSpace { x += gap }
                let sp = SKSpriteNode(texture: icon.texture(size: fontSize * UIScreen.main.scale, color: color))
                sp.size = CGSize(width: fontSize, height: fontSize)
                sp.anchorPoint = CGPoint(x: 0, y: 0.5)
                switch vmode {
                case .center: sp.position.y = 0
                case .top: sp.position.y = -fontSize * 0.5
                case .bottom: sp.position.y = fontSize * 0.5
                default: sp.position.y = fontSize * 0.36
                }
                sp.position.x = x; node.addChild(sp)
                x += fontSize
                if i < parts.count - 1 { x += gap }
            }
        }
        return x
    }

    private func width(of parts: [Run]) -> CGFloat {
        let n = SKNode()
        return buildLine(parts, into: n, vmode: .baseline)
    }

    private func relayout() {
        content.removeAllChildren()
        guard let text, !text.isEmpty else { return }
        let parts = runs(text)
        let hasIcon = parts.contains { if case .icon = $0 { return true }; return false }
        if !hasIcon {
            // Fast path: a single native label, including native wrapping.
            let l = plainLabel(parts.map { if case .text(let t) = $0 { return t }; return "" }.joined())
            l.horizontalAlignmentMode = horizontalAlignmentMode
            l.verticalAlignmentMode = verticalAlignmentMode
            l.numberOfLines = numberOfLines
            if preferredMaxLayoutWidth > 0 { l.preferredMaxLayoutWidth = preferredMaxLayoutWidth }
            content.addChild(l)
            return
        }
        // Greedy word wrap (icons count as words) when a width limit is set.
        var lines: [[Run]] = []
        if preferredMaxLayoutWidth > 0 && numberOfLines != 1 {
            var cur = ""
            for word in text.split(separator: " ", omittingEmptySubsequences: true) {
                let trial = cur.isEmpty ? String(word) : cur + " " + word
                if !cur.isEmpty && width(of: runs(trial)) > preferredMaxLayoutWidth {
                    lines.append(runs(cur)); cur = String(word)
                } else { cur = trial }
            }
            if !cur.isEmpty { lines.append(runs(cur)) }
            if numberOfLines > 0 && lines.count > numberOfLines { lines = Array(lines.prefix(numberOfLines)) }
        } else {
            lines = [parts]
        }
        let lineH = fontSize * 1.2
        let single = lines.count == 1
        let vmode: SKLabelVerticalAlignmentMode = single ? verticalAlignmentMode : .center
        let blockH = lineH * CGFloat(lines.count - 1)
        let topY: CGFloat
        switch verticalAlignmentMode {
        case .top: topY = -lineH / 2
        case .bottom: topY = blockH + lineH / 2
        case .center: topY = blockH / 2
        default: topY = blockH + fontSize * 0.36
        }
        for (i, line) in lines.enumerated() {
            let row = SKNode()
            let w = buildLine(line, into: row, vmode: vmode)
            switch horizontalAlignmentMode {
            case .left: row.position.x = 0
            case .right: row.position.x = -w
            default: row.position.x = -w / 2
            }
            row.position.y = single ? 0 : topY - CGFloat(i) * lineH
            content.addChild(row)
        }
    }
}
