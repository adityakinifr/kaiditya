import SpriteKit

/// Builds little top-down characters out of vector shapes (no art assets needed).
enum CharacterFactory {

    /// Kaiditya — a 7-8 year old superhero. Cape, mask, little "K" emblem.
    static func makeHero() -> SKNode {
        let node = SKNode()

        // Cape (behind body)
        let cape = SKShapeNode(path: capePath())
        cape.fillColor = Palette.heroRed
        cape.strokeColor = Palette.heroRed.darker
        cape.lineWidth = 1.5
        cape.position = CGPoint(x: 0, y: -2)
        cape.zPosition = -1
        cape.name = "cape"
        node.addChild(cape)

        // Body (suit)
        let body = roundedRect(size: CGSize(width: 26, height: 30), corner: 9,
                               color: Palette.heroBlue, stroke: Palette.heroBlue.darker, lineWidth: 1.5)
        body.position = CGPoint(x: 0, y: 0)
        body.name = "suit"
        node.addChild(body)

        // Chest emblem (diamond + K)
        let emblem = SKShapeNode(path: diamondPath(w: 13, h: 16))
        emblem.fillColor = Palette.energy
        emblem.strokeColor = Palette.energy.darker
        emblem.lineWidth = 1
        emblem.position = CGPoint(x: 0, y: 3)
        emblem.name = "emblem"
        node.addChild(emblem)

        let k = SKLabelNode(text: "K")
        k.fontName = "AvenirNext-Heavy"
        k.fontSize = 11
        k.fontColor = Palette.heroBlue
        k.verticalAlignmentMode = .center
        k.horizontalAlignmentMode = .center
        k.position = CGPoint(x: 0, y: 3)
        k.name = "emblem"
        node.addChild(k)

        // Head
        let head = SKShapeNode(circleOfRadius: 12)
        head.fillColor = Palette.heroSkin
        head.strokeColor = Palette.heroSkin.darker
        head.lineWidth = 1.5
        head.position = CGPoint(x: 0, y: 24)
        node.addChild(head)

        // Hair
        let hair = SKShapeNode(path: hairPath())
        hair.fillColor = Palette.heroHair
        hair.strokeColor = .clear
        hair.position = CGPoint(x: 0, y: 24)
        node.addChild(hair)

        // Mask
        let mask = roundedRect(size: CGSize(width: 22, height: 7), corner: 3.5, color: Palette.heroBlue)
        mask.position = CGPoint(x: 0, y: 25)
        mask.name = "mask"
        node.addChild(mask)

        // Eyes
        for dx in [-5.0, 5.0] {
            let eye = SKShapeNode(circleOfRadius: 2.0)
            eye.fillColor = .white
            eye.strokeColor = .clear
            eye.position = CGPoint(x: dx, y: 25)
            node.addChild(eye)
        }

        node.name = "hero"
        return node
    }

    /// Generic townsperson NPC with a tint.
    static func makeNPC(tint: SKColor) -> SKNode {
        let node = SKNode()
        let shadow = Effects.groundShadow(width: 30, height: 11)
        shadow.position = CGPoint(x: 0, y: -16)
        node.addChild(shadow)
        let body = roundedRect(size: CGSize(width: 24, height: 28), corner: 8,
                               color: tint, stroke: tint.darker, lineWidth: 1.5)
        node.addChild(body)

        let head = SKShapeNode(circleOfRadius: 11)
        head.fillColor = Palette.heroSkin
        head.strokeColor = Palette.heroSkin.darker
        head.lineWidth = 1.5
        head.position = CGPoint(x: 0, y: 22)
        node.addChild(head)

        for dx in [-4.0, 4.0] {
            let eye = SKShapeNode(circleOfRadius: 1.6)
            eye.fillColor = Palette.ink
            eye.strokeColor = .clear
            eye.position = CGPoint(x: dx, y: 23)
            node.addChild(eye)
        }
        node.name = "npc"
        return node
    }

    /// Villain minion (the things you sneak past).
    static func makeMinion() -> SKNode {
        let node = SKNode()
        let shadow = Effects.groundShadow(width: 32, height: 12)
        shadow.position = CGPoint(x: 0, y: -17)
        node.addChild(shadow)
        let body = roundedRect(size: CGSize(width: 26, height: 30), corner: 7,
                               color: Palette.minion, stroke: Palette.minion.darker, lineWidth: 1.5)
        node.addChild(body)

        let head = SKShapeNode(circleOfRadius: 11)
        head.fillColor = Palette.minion.lighter
        head.strokeColor = Palette.minion.darker
        head.lineWidth = 1.5
        head.position = CGPoint(x: 0, y: 22)
        node.addChild(head)

        // Angry visor
        let visor = roundedRect(size: CGSize(width: 18, height: 6), corner: 2, color: Palette.heroRed)
        visor.position = CGPoint(x: 0, y: 22)
        visor.zRotation = -0.12
        node.addChild(visor)
        node.name = "minion"
        return node
    }

    /// The big bad: Lord Chow-Chow — a fluffy-but-fearsome super-villain dog.
    static func makeVillain() -> SKNode {
        let node = SKNode()
        let fur = SKColor(red: 0.40, green: 0.26, blue: 0.50, alpha: 1)
        let furDark = fur.darker
        let shadow = Effects.groundShadow(width: 58, height: 18)
        shadow.position = CGPoint(x: 0, y: -26)
        node.addChild(shadow)

        let cape = SKShapeNode(path: capePath(scale: 1.6))
        cape.fillColor = Palette.villain.darker; cape.strokeColor = .clear
        cape.position = CGPoint(x: 0, y: -4); cape.zPosition = -1
        node.addChild(cape)

        let body = roundedRect(size: CGSize(width: 40, height: 46), corner: 12,
                               color: Palette.villain, stroke: Palette.villain.darker, lineWidth: 2)
        node.addChild(body)
        // Lightning bolt emblem on chest
        let bolt = SKShapeNode(path: boltPath()); bolt.setScale(1.3)
        bolt.fillColor = Palette.energy; bolt.strokeColor = .clear
        bolt.position = CGPoint(x: 0, y: 2); node.addChild(bolt)

        // Fluffy Chow-Chow mane (spiky ruff behind the head)
        let mane = SKShapeNode(path: starBurstPath(points: 12, outer: 26, inner: 19))
        mane.fillColor = fur; mane.strokeColor = furDark; mane.lineWidth = 1.5
        mane.position = CGPoint(x: 0, y: 34); node.addChild(mane)
        mane.run(.repeatForever(.sequence([.rotate(byAngle: 0.06, duration: 0.8), .rotate(byAngle: -0.06, duration: 0.8)])))

        // Ears (triangles)
        for sx in [-1.0, 1.0] {
            let ear = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: CGFloat(sx) * 12, y: 48))
                p.addLine(to: CGPoint(x: CGFloat(sx) * 22, y: 56))
                p.addLine(to: CGPoint(x: CGFloat(sx) * 20, y: 42))
                p.closeSubpath(); return p
            }())
            ear.fillColor = fur; ear.strokeColor = furDark; ear.lineWidth = 1.5
            node.addChild(ear)
        }

        // Face
        let head = SKShapeNode(circleOfRadius: 16)
        head.fillColor = fur.lighter; head.strokeColor = furDark; head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 34); node.addChild(head)
        // Snout
        let snout = SKShapeNode(ellipseOf: CGSize(width: 16, height: 12))
        snout.fillColor = fur.lighter.lighter; snout.strokeColor = furDark; snout.lineWidth = 1
        snout.position = CGPoint(x: 0, y: 28); node.addChild(snout)
        let nose = SKShapeNode(circleOfRadius: 3)
        nose.fillColor = Palette.ink; nose.strokeColor = .clear
        nose.position = CGPoint(x: 0, y: 30); node.addChild(nose)
        // Angry glowing eyes (angled)
        for sx in [-1.0, 1.0] {
            let eye = SKShapeNode(ellipseOf: CGSize(width: 6, height: 7))
            eye.fillColor = Palette.heroRed; eye.strokeColor = .white; eye.lineWidth = 0.8
            eye.glowWidth = 3
            eye.position = CGPoint(x: CGFloat(sx) * 7, y: 38)
            eye.zRotation = CGFloat(sx) * 0.4
            node.addChild(eye)
        }
        node.name = "villain"
        return node
    }

    /// Spiky star/burst path (for manes, bursts).
    private static func starBurstPath(points: Int, outer: CGFloat, inner: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let total = points * 2
        for i in 0...total {
            let r = i % 2 == 0 ? outer : inner
            let a = CGFloat(i) / CGFloat(total) * .pi * 2
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// Cover object you can hide inside/behind. Returns the node AND its
    /// hide-rect (in node-local space, centered on origin).
    static func makeCover(shape: CoverShape, fill: SKColor, detail: SKColor) -> (node: SKNode, rect: CGRect) {
        let node = SKNode()
        let shadow = Effects.groundShadow(width: 96, height: 26)
        shadow.position = CGPoint(x: 0, y: -24)
        node.addChild(shadow)

        switch shape {
        case .bush:
            let base = SKShapeNode(ellipseOf: CGSize(width: 92, height: 64))
            base.fillColor = fill; base.strokeColor = fill.darker; base.lineWidth = 2
            node.addChild(base)
            for dx in [-24.0, 0.0, 24.0] {
                let bump = SKShapeNode(circleOfRadius: 23)
                bump.fillColor = detail; bump.strokeColor = .clear
                bump.position = CGPoint(x: dx, y: 9)
                node.addChild(bump)
            }
            return (node, CGRect(x: -46, y: -32, width: 92, height: 64))
        case .crate:
            let box = roundedRect(size: CGSize(width: 78, height: 70), corner: 6,
                                  color: fill, stroke: fill.darker, lineWidth: 3)
            node.addChild(box)
            // plank lines
            for p in [CGPoint(x: 0, y: 18), CGPoint(x: 0, y: -18)] {
                let plank = roundedRect(size: CGSize(width: 70, height: 10), corner: 2, color: detail)
                plank.position = p; node.addChild(plank)
            }
            let cross = SKShapeNode(path: {
                let pp = CGMutablePath()
                pp.move(to: CGPoint(x: -35, y: -33)); pp.addLine(to: CGPoint(x: 35, y: 33))
                pp.move(to: CGPoint(x: 35, y: -33)); pp.addLine(to: CGPoint(x: -35, y: 33))
                return pp
            }())
            cross.strokeColor = fill.darker; cross.lineWidth = 4
            node.addChild(cross)
            return (node, CGRect(x: -39, y: -35, width: 78, height: 70))
        case .pillar:
            let glow = SKShapeNode(circleOfRadius: 40)
            glow.fillColor = detail.withAlphaComponent(0.18); glow.strokeColor = .clear
            glow.glowWidth = 6; node.addChild(glow)
            let base = roundedRect(size: CGSize(width: 64, height: 64), corner: 14,
                                   color: fill, stroke: detail, lineWidth: 3)
            node.addChild(base)
            let energyLine = roundedRect(size: CGSize(width: 8, height: 44), corner: 4, color: detail)
            energyLine.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.6),
                                                     .fadeAlpha(to: 1.0, duration: 0.6)])))
            node.addChild(energyLine)
            return (node, CGRect(x: -34, y: -34, width: 68, height: 68))
        }
    }

    /// Top-down car (points "up"). `hero` adds a little K roof + cape-red accents.
    static func makeCar(body color: SKColor, hero: Bool = false) -> SKNode {
        let node = SKNode()
        let shadow = Effects.groundShadow(width: 56, height: 80)
        shadow.alpha = 0.18; shadow.position = CGPoint(x: 0, y: -6); node.addChild(shadow)

        let chassis = roundedRect(size: CGSize(width: 48, height: 84), corner: 14, color: color, stroke: color.darker, lineWidth: 2)
        node.addChild(chassis)
        // windshield + rear window
        let front = roundedRect(size: CGSize(width: 38, height: 22), corner: 7, color: SKColor(red: 0.6, green: 0.85, blue: 0.95, alpha: 0.95))
        front.position = CGPoint(x: 0, y: 20); node.addChild(front)
        let rear = roundedRect(size: CGSize(width: 36, height: 16), corner: 6, color: SKColor(red: 0.45, green: 0.7, blue: 0.85, alpha: 0.9))
        rear.position = CGPoint(x: 0, y: -22); node.addChild(rear)
        // wheels
        for p in [CGPoint(x: -26, y: 24), CGPoint(x: 26, y: 24), CGPoint(x: -26, y: -24), CGPoint(x: 26, y: -24)] {
            let w = roundedRect(size: CGSize(width: 8, height: 18), corner: 3, color: SKColor(white: 0.12, alpha: 1))
            w.position = p; node.addChild(w)
        }
        // headlights
        for dx in [-13.0, 13.0] {
            let h = SKShapeNode(circleOfRadius: 4); h.fillColor = Palette.energy; h.strokeColor = .clear
            h.position = CGPoint(x: dx, y: 40); node.addChild(h)
        }
        if hero {
            let stripe = roundedRect(size: CGSize(width: 10, height: 60), corner: 3, color: Palette.energy.withAlphaComponent(0.85))
            node.addChild(stripe)
            let k = SKLabelNode(text: "K"); k.fontName = "AvenirNext-Heavy"; k.fontSize = 16; k.fontColor = color
            k.verticalAlignmentMode = .center; k.position = CGPoint(x: 0, y: 0); node.addChild(k)
        }
        return node
    }

    /// Top-down boat (points up). `big`/`villain` for the chased speedboat.
    static func makeBoat(body color: SKColor, hero: Bool = false, big: Bool = false) -> SKNode {
        let node = SKNode()
        let scale: CGFloat = big ? 1.3 : 1.0
        let hull = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 52 * scale))
            p.addQuadCurve(to: CGPoint(x: 26 * scale, y: -10 * scale), control: CGPoint(x: 30 * scale, y: 30 * scale))
            p.addLine(to: CGPoint(x: 22 * scale, y: -44 * scale))
            p.addLine(to: CGPoint(x: -22 * scale, y: -44 * scale))
            p.addLine(to: CGPoint(x: -26 * scale, y: -10 * scale))
            p.addQuadCurve(to: CGPoint(x: 0, y: 52 * scale), control: CGPoint(x: -30 * scale, y: 30 * scale))
            p.closeSubpath(); return p
        }())
        hull.fillColor = color; hull.strokeColor = color.darker; hull.lineWidth = 2; hull.lineJoin = .round
        node.addChild(hull)
        let deck = roundedRect(size: CGSize(width: 28 * scale, height: 34 * scale), corner: 8,
                               color: color.darker)
        deck.position = CGPoint(x: 0, y: -6 * scale); node.addChild(deck)
        let windshield = roundedRect(size: CGSize(width: 24 * scale, height: 14 * scale), corner: 5,
                                     color: SKColor(red: 0.6, green: 0.85, blue: 0.95, alpha: 0.95))
        windshield.position = CGPoint(x: 0, y: 8 * scale); node.addChild(windshield)
        if hero {
            let k = SKLabelNode(text: "K"); k.fontName = "AvenirNext-Heavy"; k.fontSize = 14; k.fontColor = .white
            k.verticalAlignmentMode = .center; k.position = CGPoint(x: 0, y: -8); node.addChild(k)
        }
        if big {
            let bolt = SKShapeNode(path: boltPath()); bolt.fillColor = Palette.energy; bolt.strokeColor = .clear
            bolt.position = CGPoint(x: 0, y: -8); node.addChild(bolt)
        }
        return node
    }

    /// Lord Chow-Chow's getaway truck (bigger, menacing).
    static func makeTruck() -> SKNode {
        let node = SKNode()
        let shadow = Effects.groundShadow(width: 72, height: 110)
        shadow.alpha = 0.2; node.addChild(shadow)
        let cab = roundedRect(size: CGSize(width: 64, height: 50), corner: 10, color: Palette.villain, stroke: Palette.villain.darker, lineWidth: 2)
        cab.position = CGPoint(x: 0, y: 36); node.addChild(cab)
        let bed = roundedRect(size: CGSize(width: 60, height: 70), corner: 8, color: Palette.villain.darker, stroke: Palette.villain.darker, lineWidth: 2)
        bed.position = CGPoint(x: 0, y: -26); node.addChild(bed)
        let bolt = SKShapeNode(path: boltPath()); bolt.fillColor = Palette.energy; bolt.strokeColor = .clear
        bolt.setScale(1.6); bolt.position = CGPoint(x: 0, y: -26); node.addChild(bolt)
        for p in [CGPoint(x: -34, y: 30), CGPoint(x: 34, y: 30), CGPoint(x: -34, y: -40), CGPoint(x: 34, y: -40)] {
            let w = roundedRect(size: CGSize(width: 10, height: 22), corner: 3, color: SKColor(white: 0.1, alpha: 1)); w.position = p; node.addChild(w)
        }
        for dx in [-18.0, 18.0] {
            let h = SKShapeNode(circleOfRadius: 5); h.fillColor = Palette.heroRed; h.strokeColor = .clear
            h.position = CGPoint(x: dx, y: 60); node.addChild(h)
        }
        node.name = "truck"
        return node
    }

    /// A wall-mounted searchlight base (for the rotating searchlight hazard).
    static func makeSearchlightBase() -> SKNode {
        let node = SKNode()
        let base = SKShapeNode(circleOfRadius: 16)
        base.fillColor = SKColor(white: 0.28, alpha: 1); base.strokeColor = SKColor(white: 0.5, alpha: 1); base.lineWidth = 2
        node.addChild(base)
        let lens = SKShapeNode(circleOfRadius: 8)
        lens.fillColor = Palette.energy; lens.strokeColor = .white; lens.lineWidth = 1; lens.glowWidth = 3
        node.addChild(lens)
        return node
    }

    static func makeCoin() -> SKNode {
        let node = SKNode()
        let c = SKShapeNode(circleOfRadius: 11)
        c.fillColor = Palette.energy; c.strokeColor = Palette.energy.darker; c.lineWidth = 2
        node.addChild(c)
        let star = SKLabelNode(text: "★"); star.fontSize = 12; star.fontColor = Palette.energy.darker
        star.verticalAlignmentMode = .center; node.addChild(star)
        node.name = "coin"
        return node
    }

    static func makeKeycard() -> SKNode {
        let node = SKNode()
        let card = roundedRect(size: CGSize(width: 26, height: 18), corner: 4,
                               color: SKColor(red: 0.95, green: 0.8, blue: 0.2, alpha: 1), stroke: .white, lineWidth: 1.5)
        node.addChild(card)
        let chip = roundedRect(size: CGSize(width: 8, height: 6), corner: 1, color: SKColor(white: 0.3, alpha: 1))
        chip.position = CGPoint(x: -7, y: 0); node.addChild(chip)
        node.name = "keycard"
        node.run(.repeatForever(.sequence([.moveBy(x:0,y:6,duration:0.6), .moveBy(x:0,y:-6,duration:0.6)])))
        return node
    }

    /// Power-up bubble: "magnet" or "star".
    static func makePowerup(_ kind: String) -> SKNode {
        let node = SKNode()
        let ring = SKShapeNode(circleOfRadius: 16)
        ring.fillColor = (kind == "star" ? Palette.energy : Palette.crystal).withAlphaComponent(0.25)
        ring.strokeColor = (kind == "star" ? Palette.energy : Palette.crystal)
        ring.lineWidth = 2.5; ring.glowWidth = 4
        node.addChild(ring)
        let glyph = SKLabelNode(text: kind == "star" ? "⭐️" : "🧲")
        glyph.fontSize = 18; glyph.verticalAlignmentMode = .center; node.addChild(glyph)
        node.name = "pu_\(kind)"
        node.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.5), .scale(to: 1.0, duration: 0.5)])))
        return node
    }

    /// Flying drone enemy (minion variant).
    static func makeDrone() -> SKNode {
        let node = SKNode()
        let shadow = Effects.groundShadow(width: 30, height: 10)
        shadow.position = CGPoint(x: 0, y: -20); node.addChild(shadow)
        let body = roundedRect(size: CGSize(width: 30, height: 18), corner: 8,
                               color: SKColor(red: 0.35, green: 0.38, blue: 0.46, alpha: 1), stroke: SKColor(white: 0.2, alpha: 1), lineWidth: 1.5)
        node.addChild(body)
        let eye = SKShapeNode(circleOfRadius: 5); eye.fillColor = Palette.heroRed; eye.strokeColor = .white; eye.lineWidth = 1
        eye.glowWidth = 3; node.addChild(eye)
        for dx in [-18.0, 18.0] {
            let rotor = SKShapeNode(ellipseOf: CGSize(width: 16, height: 5))
            rotor.fillColor = SKColor(white: 0.7, alpha: 0.6); rotor.strokeColor = .clear
            rotor.position = CGPoint(x: dx, y: 8)
            rotor.run(.repeatForever(.rotate(byAngle: .pi*2, duration: 0.2)))
            node.addChild(rotor)
        }
        node.name = "drone"
        return node
    }

    static func makeCrystal() -> SKShapeNode {
        let c = SKShapeNode(path: diamondPath(w: 18, h: 26))
        c.fillColor = Palette.crystal
        c.strokeColor = Palette.crystal.lighter
        c.lineWidth = 2
        c.glowWidth = 3
        c.name = "crystal"
        // facet lines for a gem look
        let facets = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 0, y: 13)); p.addLine(to: CGPoint(x: 0, y: -13))
            p.move(to: CGPoint(x: -9, y: 0)); p.addLine(to: CGPoint(x: 9, y: 0))
            p.move(to: CGPoint(x: -4.5, y: 6.5)); p.addLine(to: CGPoint(x: 4.5, y: 6.5))
            return p
        }())
        facets.strokeColor = Palette.crystal.lighter.withAlphaComponent(0.7); facets.lineWidth = 1
        c.addChild(facets)
        // shine highlight
        let shine = SKShapeNode(path: {
            let p = CGMutablePath(); p.move(to: CGPoint(x: -3, y: 7)); p.addLine(to: CGPoint(x: -6, y: 0)); p.addLine(to: CGPoint(x: -3, y: -2))
            return p
        }())
        shine.strokeColor = .white; shine.lineWidth = 1.5; shine.alpha = 0.8; c.addChild(shine)
        return c
    }

    // MARK: - Paths

    private static func capePath(scale: CGFloat = 1) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -16 * scale, y: 14 * scale))
        p.addLine(to: CGPoint(x: 16 * scale, y: 14 * scale))
        p.addLine(to: CGPoint(x: 12 * scale, y: -22 * scale))
        p.addQuadCurve(to: CGPoint(x: 0, y: -16 * scale), control: CGPoint(x: 6 * scale, y: -24 * scale))
        p.addQuadCurve(to: CGPoint(x: -12 * scale, y: -22 * scale), control: CGPoint(x: -6 * scale, y: -24 * scale))
        p.closeSubpath()
        return p
    }

    private static func hairPath() -> CGPath {
        let p = CGMutablePath()
        p.addArc(center: .zero, radius: 12, startAngle: 0, endAngle: .pi, clockwise: false)
        p.addLine(to: CGPoint(x: -12, y: 2))
        p.addQuadCurve(to: CGPoint(x: 12, y: 2), control: CGPoint(x: 0, y: 9))
        p.closeSubpath()
        return p
    }

    private static func diamondPath(w: CGFloat, h: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: h / 2))
        p.addLine(to: CGPoint(x: w / 2, y: 0))
        p.addLine(to: CGPoint(x: 0, y: -h / 2))
        p.addLine(to: CGPoint(x: -w / 2, y: 0))
        p.closeSubpath()
        return p
    }

    private static func boltPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 2, y: 12))
        p.addLine(to: CGPoint(x: -6, y: 2))
        p.addLine(to: CGPoint(x: 0, y: 2))
        p.addLine(to: CGPoint(x: -2, y: -12))
        p.addLine(to: CGPoint(x: 7, y: 0))
        p.addLine(to: CGPoint(x: 1, y: 0))
        p.closeSubpath()
        return p
    }
}
