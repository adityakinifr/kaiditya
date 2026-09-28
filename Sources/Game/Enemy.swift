import SpriteKit

/// A patrolling Static minion with a vision cone. If it spots the unhidden,
/// unshielded, costumed hero, it raises the alarm. Sneaky Sasquatch's ranger.
final class Minion: SKNode {
    private let body: SKNode
    private let sprite: CharacterSprite?
    private let cone: SKSpriteNode
    private let alertMark = RichLabel(text: "?")
    private let meterBack = SKShapeNode(circleOfRadius: 13)
    private let meterFill = SKShapeNode()
    private var warned = false          // crossed 50% this sighting (chirp once)
    private var investigate: TimeInterval = 0   // pauses patrol and looks toward the hero

    private let waypoints: [CGPoint]
    private var wpIndex = 0
    private let moveSpeed: CGFloat
    let visionRange: CGFloat
    let visionHalfAngle: CGFloat = 0.5   // radians (~28°), total ~57°

    private(set) var facing = CGVector(dx: 1, dy: 0)
    private(set) var alertLevel: CGFloat = 0   // 0..1, fills while seeing hero
    var alertRate: CGFloat = 1.4               // how fast the alert fills (higher = caught sooner)
    var sweepSpeed: CGFloat = 1.1              // searchlight rotation speed
    var isStunned = false
    private var stunTimer: TimeInterval = 0

    private let rotating: Bool      // searchlight: stationary, sweeping cone
    private var sweepAngle: CGFloat = 0

    init(waypoints: [CGPoint], speed: CGFloat = 70, range: CGFloat = 150,
         drone: Bool = false, rotating: Bool = false) {
        self.waypoints = waypoints.isEmpty ? [.zero] : waypoints
        self.moveSpeed = speed
        self.visionRange = range
        self.rotating = rotating
        body = rotating ? CharacterFactory.makeSearchlightBase()
            : CharacterFactory.makeSpriteCharacter(drone ? .drone : .minion, shadowWidth: 36, footY: -20)
        sprite = body.childNode(withName: "sprite") as? CharacterSprite
        cone = SKSpriteNode(texture: Effects.coneTex(halfAngle: 0.5))
        super.init()

        // Soft light wedge: apex at the sprite's left-centre, pointing +x; rotated to `facing`.
        cone.zPosition = ZLayer.visionCone
        cone.anchorPoint = CGPoint(x: 0, y: 0.5)
        cone.size = CGSize(width: visionRange, height: visionRange * Effects.coneAspect(halfAngle: 0.5))
        cone.color = Self.calmTint; cone.colorBlendFactor = 1
        cone.blendMode = .add
        addChild(cone)

        body.zPosition = 0.5
        addChild(body)

        alertMark.fontName = "AvenirNext-Heavy"
        alertMark.fontSize = 19
        alertMark.fontColor = Palette.energy
        alertMark.position = CGPoint(x: 0, y: 48)
        alertMark.zPosition = 8
        alertMark.alpha = 0
        addChild(alertMark)

        // Suspicion ring: fills clockwise around the "?" so the player can read how close they are to being caught.
        meterBack.position = CGPoint(x: 0, y: 55)
        meterBack.fillColor = SKColor(white: 0, alpha: 0.35); meterBack.strokeColor = .clear
        meterBack.zPosition = 7.9; meterBack.alpha = 0
        addChild(meterBack)
        meterFill.lineWidth = 4; meterFill.lineCap = .round; meterFill.fillColor = .clear
        meterBack.addChild(meterFill)

        position = self.waypoints[0]
        zPosition = ZLayer.characters
        redrawCone()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Y-sort this enemy; keeps its vision cone pinned to the cone layer (below every body).
    func applyDepth(worldHeight h: CGFloat) {
        zPosition = ZLayer.depth(position.y, worldHeight: h)
        // At night the cone is light: draw it above the multiply layer so it glows instead of dimming.
        cone.zPosition = (Minion.conesAboveNight ? ZLayer.fx + 1.5 : ZLayer.visionCone) - zPosition
    }
    static var conesAboveNight = false

    private func redrawCone() {
        cone.zRotation = atan2(facing.dy, facing.dx)
    }

    private static let calmTint = SKColor(red: 1, green: 0.82, blue: 0.35, alpha: 1)
    private static let alertTint = SKColor(red: 1, green: 0.28, blue: 0.2, alpha: 1)

    /// Returns true if `point` (in this node's parent space) is within the vision cone.
    func canSee(point: CGPoint) -> Bool {
        guard !isStunned else { return false }
        let dx = point.x - position.x
        let dy = point.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist <= visionRange else { return false }
        let angTo = atan2(dy, dx)
        let face = atan2(facing.dy, facing.dx)
        var diff = angTo - face
        while diff > .pi { diff -= 2 * .pi }
        while diff < -(.pi) { diff += 2 * .pi }
        return abs(diff) <= visionHalfAngle
    }

    func stun(_ duration: TimeInterval) {
        isStunned = true
        stunTimer = duration
        cone.isHidden = true
        body.run(.sequence([
            .group([.rotate(byAngle: .pi * 2, duration: 0.4), .scale(to: 0.8, duration: 0.2)]),
            .scale(to: 1.0, duration: 0.2)
        ]))
        let zzz = RichLabel(text: "💫")
        zzz.fontSize = 22
        zzz.position = CGPoint(x: 0, y: 48)
        zzz.zPosition = ZLayer.fx
        addChild(zzz)
        zzz.run(.sequence([.wait(forDuration: duration), .removeFromParent()]))
    }

    /// Updates suspicion. Closer = faster (inner cone ×1.5, outer edge ×0.7).
    /// Returns true on the frame suspicion first crosses 50% (for the warning chirp).
    @discardableResult
    func setSeeing(_ seeing: Bool, target: CGPoint? = nil, dt: TimeInterval) -> Bool {
        var justWarned = false
        if seeing {
            var closeness: CGFloat = 1
            if let t = target {
                let d = hypot(t.x - position.x, t.y - position.y) / max(visionRange, 1)
                closeness = d < 0.6 ? 1.5 : 0.7
                if !rotating, alertLevel >= 0.5 {
                    let fx = t.x - position.x, fy = t.y - position.y, fl = max(hypot(fx, fy), 1)
                    facing = CGVector(dx: fx / fl, dy: fy / fl)
                    redrawCone()
                }
            }
            alertLevel = min(1, alertLevel + CGFloat(dt) * alertRate * closeness)
            if alertLevel >= 0.5 && !warned { warned = true; justWarned = true; investigate = 1.2 }
            cone.color = Self.alertTint
        } else {
            alertLevel = max(0, alertLevel - CGFloat(dt) * 0.6)
            if alertLevel < 0.25 { warned = false }
            cone.color = Self.calmTint
        }
        alertMark.text = alertLevel >= 1 ? "!" : "?"
        alertMark.fontColor = alertLevel >= 1 ? Palette.heroRed : (alertLevel >= 0.5 ? SKColor.orange : Palette.energy)
        alertMark.alpha = min(1, alertLevel * 2)
        alertMark.position = CGPoint(x: 0, y: 48)
        meterBack.alpha = alertLevel > 0.01 ? 1 : 0
        if alertLevel > 0.01 {
            let p = CGMutablePath()
            p.addArc(center: .zero, radius: 13, startAngle: .pi / 2, endAngle: .pi / 2 - alertLevel * 2 * .pi, clockwise: true)
            meterFill.path = p
            meterFill.strokeColor = alertLevel >= 0.5 ? Palette.heroRed : Palette.energy
        }
        return justWarned
    }

    func update(dt: TimeInterval) {
        if isStunned {
            stunTimer -= dt
            if stunTimer <= 0 {
                isStunned = false
                cone.isHidden = false
            }
            return
        }
        if rotating {
            // Searchlight: stay put, sweep the cone back and forth.
            sweepAngle += CGFloat(dt) * sweepSpeed
            let a = sin(sweepAngle) * 1.2 + .pi   // sweep around facing left/down-ish
            facing = CGVector(dx: cos(a), dy: sin(a))
            redrawCone()
            return
        }
        if investigate > 0 { investigate -= dt; sprite?.update(velocity: .zero); return }
        // Patrol toward current waypoint.
        let target = waypoints[wpIndex]
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < 6 {
            wpIndex = (wpIndex + 1) % waypoints.count
            if waypoints.count < 2 { sprite?.update(velocity: .zero) }
        } else {
            let vx = dx / dist
            let vy = dy / dist
            facing = CGVector(dx: vx, dy: vy)
            sprite?.update(velocity: facing)
            position.x += vx * moveSpeed * CGFloat(dt)
            position.y += vy * moveSpeed * CGFloat(dt)
            redrawCone()
        }
    }
}
