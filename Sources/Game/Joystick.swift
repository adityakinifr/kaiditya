import SpriteKit

/// Floating virtual joystick. Appears under the player's thumb on the left side,
/// reports a normalized direction vector each frame.
final class Joystick: SKNode {
    private let base: SKShapeNode
    private let knob: SKShapeNode
    private let radius: CGFloat = 60

    private(set) var vector: CGVector = .zero
    private(set) var isActive = false
    private var trackingTouch: UITouch?

    override init() {
        base = SKShapeNode(circleOfRadius: 60)
        knob = SKShapeNode(circleOfRadius: 28)
        super.init()

        base.fillColor = SKColor(white: 1, alpha: 0.12)
        base.strokeColor = SKColor(white: 1, alpha: 0.35)
        base.lineWidth = 3
        base.zPosition = ZLayer.hud

        knob.fillColor = SKColor(white: 1, alpha: 0.45)
        knob.strokeColor = SKColor(white: 1, alpha: 0.7)
        knob.lineWidth = 2
        knob.zPosition = ZLayer.hud + 1

        addChild(base)
        addChild(knob)
        isHidden = true
        zPosition = ZLayer.hud
    }

    required init?(coder: NSCoder) { fatalError() }

    func begin(at point: CGPoint, touch: UITouch) {
        trackingTouch = touch
        position = point
        knob.position = .zero
        vector = .zero
        isActive = true
        isHidden = false
    }

    func owns(_ touch: UITouch) -> Bool { trackingTouch === touch }

    func update(to point: CGPoint) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let dist = max(sqrt(dx * dx + dy * dy), 0.0001)
        let clamped = min(dist, radius)
        let nx = dx / dist
        let ny = dy / dist
        knob.position = CGPoint(x: nx * clamped, y: ny * clamped)
        // Dead zone so a resting thumb doesn't drift the hero.
        let mag = clamped / radius
        vector = mag < 0.18 ? .zero : CGVector(dx: nx * mag, dy: ny * mag)
    }

    func end() {
        trackingTouch = nil
        vector = .zero
        isActive = false
        isHidden = true
    }
}
