import SpriteKit

/// Kaiditya. Holds the visual node + hero stats (energy, shield, costume state).
final class Player: SKNode {
    /// Container for whichever body is showing (Blender sprite or the vector fallback).
    let visual = SKNode()
    /// Vector-drawn hero: used for disguise mode and costumes without rendered sprites yet.
    private let vectorBody: SKNode
    private let sprite = CharacterSprite(.hero)
    private var usingSprite: Bool { !sprite.isHidden }
    private let shieldBubble: SKShapeNode
    private let heroShadow: SKShapeNode
    private(set) var carNode: SKNode?
    private(set) var isDriving = false

    var maxEnergy: CGFloat = 100
    var energy: CGFloat = 100
    var walkSpeed: CGFloat = 200
    var dashSpeed: CGFloat = 560
    var shieldDuration: TimeInterval = 4.0

    private(set) var isShielded = false
    private(set) var isDashing = false
    private var dashTimer: TimeInterval = 0
    private var shieldTimer: TimeInterval = 0

    /// In costume the minions can recognize you; "secret identity" lets you blend in.
    private(set) var inCostume = true
    private var lastFacing = CGVector(dx: 0, dy: -1)

    override init() {
        vectorBody = CharacterFactory.makeHero()
        shieldBubble = SKShapeNode(circleOfRadius: 34)
        heroShadow = Effects.groundShadow(width: 34, height: 12)
        super.init()

        // Ground shadow stays put while the hero bobs.
        heroShadow.position = CGPoint(x: 0, y: -16)
        addChild(heroShadow)

        visual.zPosition = ZLayer.characters
        visual.addChild(vectorBody)
        sprite.position = CGPoint(x: 0, y: -16)   // feet on the ground shadow
        visual.addChild(sprite)
        addChild(visual)

        shieldBubble.fillColor = SKColor(red: 0.3, green: 0.7, blue: 1, alpha: 0.18)
        shieldBubble.strokeColor = SKColor(red: 0.4, green: 0.85, blue: 1, alpha: 0.7)
        shieldBubble.lineWidth = 2.5
        shieldBubble.glowWidth = 4
        shieldBubble.zPosition = ZLayer.fx
        shieldBubble.isHidden = true
        shieldBubble.position = CGPoint(x: 0, y: 14)
        addChild(shieldBubble)

        zPosition = ZLayer.characters
    }

    required init?(coder: NSCoder) { fatalError() }

    var energyPct: CGFloat { energy / maxEnergy }

    func setCostume(_ on: Bool) {
        inCostume = on
        let costume = Economy.equippedCostume
        // Rendered sprite covers the classic suit; other looks fall back to vector art.
        let useSprite = on && costume == .classic
        sprite.isHidden = !useSprite
        vectorBody.isHidden = useSprite
        // Hero-only parts: cape, mask, chest emblem.
        for name in ["cape", "mask", "emblem"] {
            vectorBody.enumerateChildNodes(withName: name) { node, _ in node.isHidden = !on }
        }
        // Cape uses the equipped costume color.
        if let cape = vectorBody.childNode(withName: "cape") as? SKShapeNode {
            cape.fillColor = costume.cape; cape.strokeColor = costume.cape.darker
        }
        // The suit uses the costume color in hero mode, plain clothes when undercover.
        if let suit = vectorBody.childNode(withName: "suit") as? SKShapeNode {
            let civil = SKColor(red: 0.55, green: 0.6, blue: 0.5, alpha: 1)
            suit.fillColor = on ? costume.suit : civil
            suit.strokeColor = (on ? costume.suit : civil).darker
        }
        // A little puff when switching.
        let puff = SKShapeNode(circleOfRadius: 26)
        puff.fillColor = SKColor(white: 1, alpha: 0.5)
        puff.strokeColor = .clear
        puff.zPosition = ZLayer.fx
        puff.position = CGPoint(x: 0, y: 12)
        addChild(puff)
        puff.run(.sequence([.group([.scale(to: 1.6, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
    }

    /// Try to start a dash. Returns false if not enough energy.
    @discardableResult
    func tryDash() -> Bool {
        guard energy >= 25, !isDashing else { return false }
        energy -= 25
        isDashing = true
        dashTimer = 0.28
        let trail = SKShapeNode(circleOfRadius: 20)
        trail.fillColor = SKColor(red: 1, green: 0.82, blue: 0.25, alpha: 0.4)
        trail.strokeColor = .clear
        trail.zPosition = ZLayer.fx - 1
        addChild(trail)
        trail.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        return true
    }

    @discardableResult
    func tryShield() -> Bool {
        guard energy >= 35, !isShielded else { return false }
        energy -= 35
        isShielded = true
        shieldTimer = shieldDuration
        shieldBubble.isHidden = false
        shieldBubble.setScale(0.3)
        shieldBubble.run(.scale(to: 1.0, duration: 0.2))
        return true
    }

    func currentSpeed() -> CGFloat { isDashing ? dashSpeed : walkSpeed }

    func faceMovement(_ v: CGVector) {
        guard v.dx != 0 || v.dy != 0 else { return }
        lastFacing = v
        sprite.update(velocity: v, frameTime: isDashing ? 0.07 : 0.12)
        // Flip the vector hero to face left/right of travel.
        if abs(v.dx) > 0.05 {
            vectorBody.xScale = v.dx < 0 ? -1 : 1
        }
        // Little bob while walking (vector body; the sprite has a real walk cycle).
        if vectorBody.action(forKey: "bob") == nil {
            vectorBody.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 2.5, duration: 0.16),
                .moveBy(x: 0, y: -2.5, duration: 0.16)
            ])), withKey: "bob")
        }
    }

    func stopWalk() {
        vectorBody.removeAction(forKey: "bob")
        vectorBody.position = .zero
        sprite.update(velocity: .zero)
    }

    func update(dt: TimeInterval) {
        if isDashing {
            dashTimer -= dt
            if dashTimer <= 0 { isDashing = false }
        }
        if isShielded {
            shieldTimer -= dt
            shieldBubble.zRotation += CGFloat(dt) * 2
            if shieldTimer <= 0 {
                isShielded = false
                shieldBubble.run(.sequence([.fadeOut(withDuration: 0.2), .run { [weak self] in
                    self?.shieldBubble.isHidden = true
                    self?.shieldBubble.alpha = 1
                }]))
            }
        }
        // Regenerate energy over time.
        if energy < maxEnergy {
            energy = min(maxEnergy, energy + CGFloat(dt) * 12)
        }
    }

    func addEnergy(_ n: CGFloat) { energy = min(maxEnergy, energy + n) }

    private var starGlow: SKShapeNode?
    func setStar(_ on: Bool) {
        if on {
            if starGlow == nil {
                let g = SKShapeNode(circleOfRadius: 30)
                g.fillColor = SKColor(red: 1, green: 0.85, blue: 0.25, alpha: 0.25)
                g.strokeColor = Palette.energy; g.lineWidth = 2.5; g.glowWidth = 6
                g.position = CGPoint(x: 0, y: 14); g.zPosition = ZLayer.fx - 1
                starGlow = g; addChild(g)
            }
            starGlow?.isHidden = false
            starGlow?.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.3), .scale(to: 1.0, duration: 0.3)])), withKey: "starPulse")
        } else {
            starGlow?.removeAction(forKey: "starPulse")
            starGlow?.isHidden = true
        }
    }

    /// Switch between on-foot hero and driving a car (or boat).
    func setDriving(_ on: Bool, boat: Bool = false) {
        isDriving = on
        if on {
            carNode?.removeFromParent(); carNode = nil
            let c = boat ? CharacterFactory.makeBoat(body: Palette.heroBlue, hero: true)
                         : CharacterFactory.makeCar(body: Palette.heroBlue, hero: true)
            c.zPosition = ZLayer.characters
            carNode = c
            addChild(c)
            carNode?.isHidden = false
            carNode?.zRotation = 0
            visual.isHidden = true
            heroShadow.isHidden = true
            shieldBubble.isHidden = true
        } else {
            carNode?.isHidden = true
            visual.isHidden = false
            heroShadow.isHidden = false
        }
    }

    /// Apply purchased shop upgrades to the hero's stats.
    func applyUpgrades() {
        walkSpeed = Economy.owned(.boots) ? 250 : 200
        dashSpeed = Economy.owned(.dash) ? 700 : 560
        maxEnergy = Economy.owned(.energy) ? 135 : 100
        shieldDuration = Economy.owned(.shield) ? 6.5 : 4.0
    }

    /// Reset hero state at the start of a level.
    func resetForLevel() {
        applyUpgrades()
        energy = maxEnergy
        isShielded = false
        isDashing = false
        shieldBubble.isHidden = true
        shieldBubble.alpha = 1
        removeAllActions()
        visual.removeAllActions()
        vectorBody.removeAllActions()
        visual.position = .zero
        vectorBody.position = .zero
        vectorBody.xScale = 1
        sprite.update(velocity: CGVector(dx: 0, dy: -1)); sprite.update(velocity: .zero)
        zRotation = 0
        setDriving(false)
        setStar(false)
        setCostume(true)
    }
}
