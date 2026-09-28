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

        let k = RichLabel(text: "K")
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

    /// Villain minion — a static-bot guard with a glowing scanner visor.
    /// A boxy, snarling little monster — inspired by a kid's sketchbook enemy:
    /// square body, big round eyes, a V-nose and a jagged-toothed grin.
    static func makeMinion() -> SKNode {
        let node = SKNode()
        let bodyC = Palette.minion
        let shadow = Effects.groundShadow(width: 36, height: 12)
        shadow.position = CGPoint(x: 0, y: -20); node.addChild(shadow)

        // Stubby legs.
        for sx in [-1.0, 1.0] {
            let leg = roundedRect(size: CGSize(width: 9, height: 11), corner: 3, color: bodyC.darker)
            leg.position = CGPoint(x: CGFloat(sx) * 8, y: -15); node.addChild(leg)
        }
        // Square body/head.
        let body = roundedRect(size: CGSize(width: 34, height: 34), corner: 7,
                               color: bodyC, stroke: bodyC.darker, lineWidth: 2)
        body.position = CGPoint(x: 0, y: 6); node.addChild(body)
        // Stubby side arms.
        for sx in [-1.0, 1.0] {
            let arm = roundedRect(size: CGSize(width: 10, height: 7), corner: 3, color: bodyC, stroke: bodyC.darker, lineWidth: 1.5)
            arm.position = CGPoint(x: CGFloat(sx) * 22, y: 5); node.addChild(arm)
        }

        // Big round eyes with a glowing red iris (doubles as the alert "scanner").
        for ex in [-7.5, 7.5] {
            let white = SKShapeNode(circleOfRadius: 6.2)
            white.fillColor = .white; white.strokeColor = bodyC.darker; white.lineWidth = 1.5
            white.position = CGPoint(x: ex, y: 13); node.addChild(white)
            let iris = SKShapeNode(circleOfRadius: 2.8)
            iris.fillColor = Palette.heroRed; iris.strokeColor = .clear; iris.glowWidth = 2
            iris.position = CGPoint(x: ex, y: 13); node.addChild(iris)
            iris.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])))
        }
        // V nose.
        let nose = SKShapeNode(path: { let p = CGMutablePath()
            p.move(to: CGPoint(x: -3, y: 7)); p.addLine(to: CGPoint(x: 0, y: 2.5)); p.addLine(to: CGPoint(x: 3, y: 7)); return p }())
        nose.strokeColor = bodyC.darker; nose.lineWidth = 1.5; nose.fillColor = .clear
        nose.lineJoin = .round; node.addChild(nose)
        // Snarling mouth with jagged teeth.
        let mouth = roundedRect(size: CGSize(width: 22, height: 10), corner: 2.5, color: Palette.ink)
        mouth.position = CGPoint(x: 0, y: -3); node.addChild(mouth)
        let teeth = SKShapeNode(path: teethPath(width: 20, count: 5, height: 5))
        teeth.fillColor = .white; teeth.strokeColor = .clear
        teeth.position = CGPoint(x: 0, y: 1.5); mouth.addChild(teeth)        // top teeth pointing down
        let teethB = SKShapeNode(path: teethPath(width: 20, count: 5, height: -5))
        teethB.fillColor = .white; teethB.strokeColor = .clear
        teethB.position = CGPoint(x: 2, y: -1.5); mouth.addChild(teethB)     // bottom teeth pointing up (offset)
        // Belly button dots.
        for bx in [-6.0, 0.0, 6.0] {
            let dot = SKShapeNode(circleOfRadius: 1.6); dot.fillColor = bodyC.darker; dot.strokeColor = .clear
            dot.position = CGPoint(x: bx, y: -11); node.addChild(dot)
        }
        node.name = "minion"
        return node
    }

    /// A row of triangular teeth across `width`; positive `height` points down.
    private static func teethPath(width: CGFloat, count: Int, height: CGFloat) -> CGPath {
        let p = CGMutablePath(); let tw = width / CGFloat(count)
        for i in 0..<count {
            let x0 = -width/2 + CGFloat(i) * tw
            p.move(to: CGPoint(x: x0, y: 0))
            p.addLine(to: CGPoint(x: x0 + tw/2, y: -height))
            p.addLine(to: CGPoint(x: x0 + tw, y: 0))
            p.closeSubpath()
        }
        return p
    }

    /// The big bad: Lord Chow-Chow — a fluffy-but-fearsome super-villain dog.
    static func makeVillain() -> SKNode {
        let node = SKNode()
        let fur = SKColor(red: 0.40, green: 0.26, blue: 0.50, alpha: 1)
        let furDark = fur.darker
        let shadow = Effects.groundShadow(width: 58, height: 18)
        shadow.position = CGPoint(x: 0, y: -26)
        node.addChild(shadow)

        let cape = SKShapeNode(path: capePath(scale: 1.7))
        cape.fillColor = Palette.villain.darker; cape.strokeColor = .clear
        cape.position = CGPoint(x: 0, y: -6); cape.zPosition = -2
        node.addChild(cape)

        // --- Legs with clawed feet ---
        for sx in [-1.0, 1.0] {
            let thigh = roundedRect(size: CGSize(width: 16, height: 22), corner: 6,
                                    color: fur, stroke: furDark, lineWidth: 2)
            thigh.position = CGPoint(x: CGFloat(sx) * 11, y: -26); node.addChild(thigh)
            let foot = SKShapeNode(path: clawPath()); foot.setScale(1.1)
            foot.fillColor = fur.lighter; foot.strokeColor = furDark; foot.lineWidth = 1.5
            foot.position = CGPoint(x: CGFloat(sx) * 11, y: -38); node.addChild(foot)
        }

        // --- Huge lumpy muscular arms (cloud-puff) with clawed fists ---
        for sx in [-1.0, 1.0] {
            let arm = SKNode(); arm.position = CGPoint(x: CGFloat(sx) * 29, y: 4); arm.zPosition = -1
            for (dx, dy, r) in [(0.0, 13.0, 11.0), (4.0, 0.0, 12.5), (1.0, -13.0, 10.0)] {
                let puff = SKShapeNode(circleOfRadius: r)
                puff.fillColor = fur; puff.strokeColor = furDark; puff.lineWidth = 2
                puff.position = CGPoint(x: CGFloat(sx) * dx, y: dy); arm.addChild(puff)
            }
            node.addChild(arm)
            let fist = SKShapeNode(path: clawPath()); fist.setScale(1.25)
            fist.fillColor = fur.lighter; fist.strokeColor = furDark; fist.lineWidth = 1.5
            fist.position = CGPoint(x: CGFloat(sx) * 30, y: -16); node.addChild(fist)
        }

        // --- Torso ---
        let body = roundedRect(size: CGSize(width: 44, height: 48), corner: 11,
                               color: Palette.villain, stroke: Palette.villain.darker, lineWidth: 2)
        body.position = CGPoint(x: 0, y: 2); node.addChild(body)
        // X-bandolier across the chest.
        let strap = SKShapeNode(path: { let p = CGMutablePath()
            p.move(to: CGPoint(x: -18, y: 18)); p.addLine(to: CGPoint(x: 18, y: -12))
            p.move(to: CGPoint(x: 18, y: 18)); p.addLine(to: CGPoint(x: -18, y: -12)); return p }())
        strap.strokeColor = Palette.ink; strap.lineWidth = 5; strap.lineCap = .round
        strap.position = CGPoint(x: 0, y: 2); node.addChild(strap)
        // Belt with a bolt buckle.
        let belt = roundedRect(size: CGSize(width: 46, height: 8), corner: 2, color: Palette.ink)
        belt.position = CGPoint(x: 0, y: -19); node.addChild(belt)
        let buckle = SKShapeNode(path: boltPath()); buckle.setScale(0.6)
        buckle.fillColor = Palette.energy; buckle.strokeColor = .clear
        buckle.position = CGPoint(x: 0, y: -19); node.addChild(buckle)

        // --- Head ---
        let head = SKShapeNode(circleOfRadius: 15)
        head.fillColor = fur.lighter; head.strokeColor = furDark; head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 37); node.addChild(head)
        // Angry glowing eyes (angled inward).
        for sx in [-1.0, 1.0] {
            let eye = SKShapeNode(ellipseOf: CGSize(width: 7, height: 6))
            eye.fillColor = Palette.heroRed; eye.strokeColor = .white; eye.lineWidth = 0.8; eye.glowWidth = 3
            eye.position = CGPoint(x: CGFloat(sx) * 6, y: 39); eye.zRotation = CGFloat(sx) * 0.4
            node.addChild(eye)
        }
        // Gritted-teeth snarl.
        let snarl = roundedRect(size: CGSize(width: 15, height: 5), corner: 1.5, color: Palette.ink)
        snarl.position = CGPoint(x: 0, y: 30); node.addChild(snarl)
        let teeth = SKShapeNode(path: teethPath(width: 13, count: 4, height: 3))
        teeth.fillColor = .white; teeth.strokeColor = .clear
        teeth.position = CGPoint(x: 0, y: 32); node.addChild(teeth)
        // Flat slab helmet on top.
        let helmet = roundedRect(size: CGSize(width: 42, height: 12), corner: 3,
                                 color: Palette.ink, stroke: furDark, lineWidth: 1.5)
        helmet.position = CGPoint(x: 0, y: 51); node.addChild(helmet)
        let shine = roundedRect(size: CGSize(width: 30, height: 3), corner: 1.5,
                                color: SKColor(white: 1, alpha: 0.22))
        shine.position = CGPoint(x: -2, y: 54); node.addChild(shine)
        node.name = "villain"
        return node
    }

    /// A chunky three-toed claw (feet & fists).
    private static func clawPath() -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -8, y: 5))
        p.addLine(to: CGPoint(x: -8, y: 0))
        p.addLine(to: CGPoint(x: -5, y: -8))
        p.addLine(to: CGPoint(x: -2.5, y: -1))
        p.addLine(to: CGPoint(x: 0, y: -8))
        p.addLine(to: CGPoint(x: 2.5, y: -1))
        p.addLine(to: CGPoint(x: 5, y: -8))
        p.addLine(to: CGPoint(x: 8, y: 0))
        p.addLine(to: CGPoint(x: 8, y: 5))
        p.closeSubpath()
        return p
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
            let k = RichLabel(text: "K"); k.fontName = "AvenirNext-Heavy"; k.fontSize = 16; k.fontColor = color
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
            let k = RichLabel(text: "K"); k.fontName = "AvenirNext-Heavy"; k.fontSize = 14; k.fontColor = .white
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

    /// A rotating sentry turret that casts the searchlight cone — matches the
    /// kid's-sketchbook cannon-bots: boxed metal housing, corner bolts and a
    /// big glowing red scanning eye.
    static func makeSearchlightBase() -> SKNode {
        let node = SKNode()
        let metal = SKColor(white: 0.30, alpha: 1)
        // Boxed housing.
        let housing = roundedRect(size: CGSize(width: 30, height: 26), corner: 7,
                                  color: metal, stroke: Palette.heroRed, lineWidth: 2)
        node.addChild(housing)
        // Corner bolts.
        for c in [CGPoint(x: -10, y: 8), CGPoint(x: 10, y: 8), CGPoint(x: -10, y: -8), CGPoint(x: 10, y: -8)] {
            let b = SKShapeNode(circleOfRadius: 1.8); b.fillColor = metal.darker; b.strokeColor = .clear
            b.position = c; housing.addChild(b)
        }
        // Scanning eye socket + glowing red lens (the cone's source).
        let socket = SKShapeNode(circleOfRadius: 9)
        socket.fillColor = Palette.ink; socket.strokeColor = SKColor(white: 0.5, alpha: 1); socket.lineWidth = 1.5
        node.addChild(socket)
        let lens = SKShapeNode(circleOfRadius: 5)
        lens.fillColor = Palette.heroRed; lens.strokeColor = .white; lens.lineWidth = 1; lens.glowWidth = 4
        node.addChild(lens)
        lens.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        // Bright pupil for a watchful look.
        let pupil = SKShapeNode(circleOfRadius: 1.6); pupil.fillColor = .white; pupil.strokeColor = .clear
        node.addChild(pupil)
        return node
    }

    /// A little legged cannon-bot that anchors a laser beam — inspired by a kid's
    /// sketchbook "shooter": boxy body, stubby legs, a barrel + glowing muzzle.
    static func makeLaserTurret(facingRight: Bool) -> SKNode {
        let node = SKNode()
        let metal = SKColor(white: 0.30, alpha: 1)
        let dir: CGFloat = facingRight ? 1 : -1
        // Legs.
        for lx in [-6.0, 6.0] {
            let leg = SKSpriteNode(color: metal.darker, size: CGSize(width: 3.5, height: 9))
            leg.position = CGPoint(x: lx, y: -13); node.addChild(leg)
        }
        // Body.
        let body = roundedRect(size: CGSize(width: 18, height: 17), corner: 4,
                               color: metal, stroke: Palette.heroRed, lineWidth: 2)
        body.position = CGPoint(x: -dir * 2, y: -3); node.addChild(body)
        // A little rivet eye.
        let eye = SKShapeNode(circleOfRadius: 2.2); eye.fillColor = Palette.heroRed
        eye.strokeColor = .white; eye.lineWidth = 0.6
        eye.position = CGPoint(x: -dir * 2, y: 0); node.addChild(eye)
        // Barrel pointing toward the beam.
        let barrel = roundedRect(size: CGSize(width: 15, height: 9), corner: 3,
                                 color: metal.darker, stroke: Palette.heroRed, lineWidth: 1.5)
        barrel.position = CGPoint(x: dir * 10, y: -1); node.addChild(barrel)
        // Pulsing muzzle glow.
        let muzzle = SKShapeNode(circleOfRadius: 4)
        muzzle.fillColor = Palette.heroRed; muzzle.strokeColor = .white; muzzle.lineWidth = 0.8; muzzle.glowWidth = 4
        muzzle.position = CGPoint(x: dir * 17, y: -1)
        muzzle.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
        node.addChild(muzzle)
        return node
    }

    /// A stationary electric trap — telegraphed warning ring + crackling core.
    /// Touching it costs the hero a life.
    static func makeStaticTrap() -> SKNode {
        let node = SKNode()
        let base = SKShapeNode(circleOfRadius: 16)
        base.fillColor = SKColor(white: 0.22, alpha: 1); base.strokeColor = Palette.heroRed; base.lineWidth = 2
        node.addChild(base)
        // Pulsing warning ring.
        let ring = SKShapeNode(circleOfRadius: 22)
        ring.strokeColor = Palette.heroRed; ring.lineWidth = 2; ring.fillColor = Palette.heroRed.withAlphaComponent(0.08)
        ring.run(.repeatForever(.sequence([.group([.scale(to: 1.18, duration: 0.6), .fadeAlpha(to: 0.25, duration: 0.6)]),
                                           .group([.scale(to: 1.0, duration: 0.01), .fadeAlpha(to: 0.9, duration: 0.01)])])))
        node.addChild(ring)
        // Crackling bolt core.
        let core = SKShapeNode(path: boltPath()); core.setScale(0.95)
        core.fillColor = Palette.energy; core.strokeColor = .white; core.lineWidth = 0.6; core.glowWidth = 4
        core.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.32), .fadeAlpha(to: 1, duration: 0.32)])))
        node.addChild(core)
        if let sp = Effects.ambient(.sparks, screen: CGSize(width: 36, height: 36)) {
            sp.particleColor = Palette.energy; sp.particleBirthRate = 12; sp.particleLifetime = 0.5
            sp.particlePositionRange = CGVector(dx: 18, dy: 18); sp.particleSpeed = 30
            node.addChild(sp)
        }
        node.name = "trap"
        return node
    }

    /// A grapple anchor: a post with a glowing ring you can zip to.
    static func makeGrappleAnchor(accent: SKColor) -> SKNode {
        let node = SKNode()
        let post = SKSpriteNode(color: SKColor(white: 0.35, alpha: 1), size: CGSize(width: 8, height: 30))
        post.position = CGPoint(x: 0, y: -15); node.addChild(post)
        let ring = SKShapeNode(circleOfRadius: 13)
        ring.strokeColor = accent; ring.lineWidth = 4; ring.fillColor = accent.withAlphaComponent(0.18); ring.glowWidth = 3
        node.addChild(ring)
        let hook = SKShapeNode(circleOfRadius: 5)
        hook.strokeColor = .white; hook.lineWidth = 2; hook.fillColor = .clear
        node.addChild(hook)
        let tag = RichLabel(text: "ZIP")
        tag.fontName = "AvenirNext-Heavy"; tag.fontSize = 9; tag.fontColor = accent
        tag.verticalAlignmentMode = .center; tag.position = CGPoint(x: 0, y: 22)
        tag.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        node.addChild(tag)
        node.name = "anchor"
        return node
    }

    /// A treasure chest. `glowing` when the daily bonus is available.
    static func makeChest(glowing: Bool) -> SKNode {
        let node = SKNode()
        let shadow = Effects.groundShadow(width: 60, height: 18); shadow.position = CGPoint(x: 0, y: -22); node.addChild(shadow)
        let brown = SKColor(red: 0.52, green: 0.34, blue: 0.18, alpha: 1)
        let box = roundedRect(size: CGSize(width: 56, height: 36), corner: 6, color: brown, stroke: brown.darker, lineWidth: 2)
        box.position = CGPoint(x: 0, y: -6); node.addChild(box)
        let lid = roundedRect(size: CGSize(width: 60, height: 22), corner: 8, color: brown.lighter, stroke: brown.darker, lineWidth: 2)
        lid.position = CGPoint(x: 0, y: 14); node.addChild(lid)
        let band = roundedRect(size: CGSize(width: 60, height: 6), corner: 2, color: Palette.energy)
        band.position = CGPoint(x: 0, y: 6); node.addChild(band)
        let lock = SKShapeNode(circleOfRadius: 5); lock.fillColor = Palette.energy; lock.strokeColor = brown.darker; lock.lineWidth = 1
        lock.position = CGPoint(x: 0, y: 6); node.addChild(lock)
        if glowing {
            let glow = SKShapeNode(circleOfRadius: 38); glow.fillColor = Palette.energy.withAlphaComponent(0.22)
            glow.strokeColor = .clear; glow.glowWidth = 6; glow.zPosition = -1; node.addChild(glow)
            node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.5), .moveBy(x: 0, y: -4, duration: 0.5)])))
            let spark = RichLabel(text: "✨"); spark.fontSize = 18; spark.position = CGPoint(x: 0, y: 38); node.addChild(spark)
        } else {
            node.alpha = 0.6
        }
        node.name = "chest"
        return node
    }

    static func makeCoin() -> SKNode {
        let node = SKNode()
        let c = SKShapeNode(circleOfRadius: 11)
        c.fillColor = Palette.energy; c.strokeColor = Palette.energy.darker; c.lineWidth = 2
        node.addChild(c)
        let star = RichLabel(text: "★"); star.fontSize = 12; star.fontColor = Palette.energy.darker
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
        let glyph = RichLabel(text: kind == "star" ? "⭐️" : "🧲")
        glyph.fontSize = 18; glyph.verticalAlignmentMode = .center; node.addChild(glyph)
        node.name = "pu_\(kind)"
        node.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.5), .scale(to: 1.0, duration: 0.5)])))
        return node
    }

    /// Flying drone enemy (minion variant).
    /// A floating ghost-bot — inspired by a kid's sketchbook spook: domed head,
    /// hypnotic spiral eyes, a startled "O" mouth and a wavy tattered hem.
    static func makeDrone() -> SKNode {
        let node = SKNode()
        let shadow = Effects.groundShadow(width: 26, height: 9)
        shadow.position = CGPoint(x: 0, y: -22); node.addChild(shadow)
        // Faint aura so it reads as floating/spectral.
        let aura = SKShapeNode(path: ghostPath(w: 36, h: 40))
        aura.fillColor = Palette.heroRed.withAlphaComponent(0.12); aura.strokeColor = .clear
        aura.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.8), .scale(to: 1.0, duration: 0.8)])))
        node.addChild(aura)
        // Ghost body.
        let body = SKShapeNode(path: ghostPath(w: 30, h: 34))
        body.fillColor = SKColor(white: 0.95, alpha: 0.95)
        body.strokeColor = SKColor(white: 0.42, alpha: 1); body.lineWidth = 1.5
        node.addChild(body)
        // Spiral hypnotic eyes.
        for ex in [-6.5, 6.5] {
            let spiral = SKShapeNode(path: spiralPath(radius: 4.2, turns: 2.4))
            spiral.strokeColor = Palette.ink; spiral.lineWidth = 1.3; spiral.fillColor = .clear
            spiral.lineCap = .round; spiral.position = CGPoint(x: ex, y: 6); node.addChild(spiral)
        }
        // Startled "O" mouth.
        let mouth = SKShapeNode(ellipseOf: CGSize(width: 6, height: 8))
        mouth.fillColor = Palette.ink; mouth.strokeColor = .clear
        mouth.position = CGPoint(x: 0, y: -5); node.addChild(mouth)
        // Gentle floating bob.
        node.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.7), .moveBy(x: 0, y: -3, duration: 0.7)])))
        node.name = "drone"
        return node
    }

    /// A classic ghost outline: domed top, vertical sides, wavy hem.
    private static func ghostPath(w: CGFloat, h: CGFloat) -> CGPath {
        let p = CGMutablePath(); let hw = w / 2, topY = h / 2, botY = -h / 2
        p.move(to: CGPoint(x: -hw, y: botY))
        p.addLine(to: CGPoint(x: -hw, y: topY - hw))
        p.addArc(center: CGPoint(x: 0, y: topY - hw), radius: hw, startAngle: .pi, endAngle: 0, clockwise: false)
        p.addLine(to: CGPoint(x: hw, y: botY))
        let waves = 4, ww = w / CGFloat(waves)
        for i in 0..<waves {                                  // wavy hem, points hanging down
            let x1 = hw - CGFloat(i) * ww
            p.addQuadCurve(to: CGPoint(x: x1 - ww, y: botY), control: CGPoint(x: x1 - ww / 2, y: botY + 7))
        }
        p.closeSubpath()
        return p
    }

    /// An Archimedean spiral for hypnotic eyes.
    private static func spiralPath(radius: CGFloat, turns: Double) -> CGPath {
        let p = CGMutablePath(); let steps = 48
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let ang = t * turns * 2 * .pi, r = radius * CGFloat(t)
            let pt = CGPoint(x: cos(ang) * r, y: sin(ang) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
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
