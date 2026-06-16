import SpriteKit

/// A patrolling Static minion with a vision cone. If it spots the unhidden,
/// unshielded, costumed hero, it raises the alarm. Sneaky Sasquatch's ranger.
final class Minion: SKNode {
    private let body: SKNode
    private let cone: SKShapeNode
    private let innerCone = SKShapeNode()
    private let alertMark = SKLabelNode(text: "?")

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
        body = drone ? CharacterFactory.makeDrone() : (rotating ? CharacterFactory.makeSearchlightBase() : CharacterFactory.makeMinion())
        cone = SKShapeNode()
        super.init()

        cone.zPosition = ZLayer.visionCone
        cone.fillColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.16)
        cone.strokeColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.35)
        cone.lineWidth = 1
        addChild(cone)

        innerCone.zPosition = 0.1
        innerCone.fillColor = SKColor(red: 1, green: 0.92, blue: 0.4, alpha: 0.22)
        innerCone.strokeColor = .clear
        cone.addChild(innerCone)   // hides/shows with the outer cone

        body.zPosition = ZLayer.characters
        addChild(body)

        alertMark.fontName = "AvenirNext-Heavy"
        alertMark.fontSize = 26
        alertMark.fontColor = Palette.energy
        alertMark.position = CGPoint(x: 0, y: 46)
        alertMark.zPosition = ZLayer.fx
        alertMark.alpha = 0
        addChild(alertMark)

        position = self.waypoints[0]
        zPosition = ZLayer.characters
        redrawCone()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func redrawCone() {
        cone.path = conePath(length: visionRange)
        innerCone.path = conePath(length: visionRange * 0.6, halfAngleScale: 0.72)
    }

    private func conePath(length: CGFloat, halfAngleScale: CGFloat = 1) -> CGPath {
        let p = CGMutablePath()
        p.move(to: .zero)
        let baseAngle = atan2(facing.dy, facing.dx)
        let steps = 12
        let ha = visionHalfAngle * halfAngleScale
        let start = baseAngle - ha
        let end = baseAngle + ha
        for i in 0...steps {
            let a = start + (end - start) * CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: cos(a) * length, y: sin(a) * length))
        }
        p.closeSubpath()
        return p
    }

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
        let zzz = SKLabelNode(text: "💫")
        zzz.fontSize = 22
        zzz.position = CGPoint(x: 0, y: 48)
        zzz.zPosition = ZLayer.fx
        addChild(zzz)
        zzz.run(.sequence([.wait(forDuration: duration), .removeFromParent()]))
    }

    func setSeeing(_ seeing: Bool, dt: TimeInterval) {
        if seeing {
            alertLevel = min(1, alertLevel + CGFloat(dt) * alertRate)
            cone.fillColor = SKColor(red: 1, green: 0.3, blue: 0.2, alpha: 0.20)
            innerCone.fillColor = SKColor(red: 1, green: 0.4, blue: 0.25, alpha: 0.30)
        } else {
            alertLevel = max(0, alertLevel - CGFloat(dt) * 0.8)
            cone.fillColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.16)
            innerCone.fillColor = SKColor(red: 1, green: 0.92, blue: 0.4, alpha: 0.22)
        }
        alertMark.text = alertLevel >= 1 ? "!" : "?"
        alertMark.fontColor = alertLevel >= 1 ? Palette.heroRed : Palette.energy
        alertMark.alpha = alertLevel
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
        // Patrol toward current waypoint.
        let target = waypoints[wpIndex]
        let dx = target.x - position.x
        let dy = target.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        if dist < 6 {
            wpIndex = (wpIndex + 1) % waypoints.count
        } else {
            let vx = dx / dist
            let vy = dy / dist
            facing = CGVector(dx: vx, dy: vy)
            position.x += vx * moveSpeed * CGFloat(dt)
            position.y += vy * moveSpeed * CGFloat(dt)
            redrawCone()
        }
    }
}
