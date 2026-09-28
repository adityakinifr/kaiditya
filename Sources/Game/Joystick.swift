import SpriteKit

/// Floating virtual joystick. Appears under the player's thumb on the left side,
/// reports a normalized direction vector each frame.
final class Joystick: SKNode {
    private let base: SKSpriteNode
    private let knob: SKSpriteNode
    private let radius: CGFloat = 60

    static let knobColor = SKColor(red: 0.88, green: 0.90, blue: 0.97, alpha: 1)

    private(set) var vector: CGVector = .zero
    private(set) var isActive = false
    private var trackingTouch: UITouch?

    override init() {
        // Toon skin: translucent ring with ink outline + a bevelled "toy" knob.
        base = SKSpriteNode(texture: ToonArt.ring(radius: 60))
        knob = SKSpriteNode(texture: ToonArt.disc(color: Joystick.knobColor, radius: 28, depth: 4))
        knob.anchorPoint = CGPoint(x: 0.5, y: 0.5 + ToonArt.discFaceOffset(depth: 4) / knob.size.height)
        super.init()

        base.zPosition = ZLayer.hud
        knob.alpha = 0.92
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
