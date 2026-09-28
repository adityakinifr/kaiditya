import SpriteKit

/// Eight facing directions used by the Blender-rendered character sprites (art/blender).
enum SpriteDir: String, CaseIterable {
    case n, ne, e, se, s, sw, w, nw
    /// Nearest of 8 directions for a movement vector (SpriteKit: +y is up).
    static func from(_ v: CGVector) -> SpriteDir {
        let octant = Int((atan2(v.dy, v.dx) / (.pi / 4)).rounded()) & 7   // 0 = east, CCW
        return [.e, .ne, .n, .nw, .w, .sw, .s, .se][octant]
    }
}

/// One character's compiled texture atlas (Resources/Sprites/<name>.atlas).
final class SpriteSet {
    let name: String
    private let atlas: SKTextureAtlas
    private var walkCache: [SpriteDir: [SKTexture]] = [:]
    init(_ name: String) { self.name = name; atlas = SKTextureAtlas(named: name) }

    func idle(_ d: SpriteDir) -> SKTexture { atlas.textureNamed("\(name)_idle_\(d.rawValue)") }
    func walk(_ d: SpriteDir) -> [SKTexture] {
        if let w = walkCache[d] { return w }
        let w = (0..<4).map { atlas.textureNamed("\(name)_walk_\(d.rawValue)_\($0)") }
        walkCache[d] = w; return w
    }

    static let hero = SpriteSet("hero"), minion = SpriteSet("minion"), drone = SpriteSet("drone")
    static let boss = SpriteSet("chowchow")
    static let npcs: [String: SpriteSet] = ["mayor": SpriteSet("npc_mayor"), "gran": SpriteSet("npc_gran"),
                                            "kid": SpriteSet("npc_tommy"), "tommy": SpriteSet("npc_tommy")]
    static let vehicles = SKTextureAtlas(named: "vehicles")

    /// All sprite art renders at the same pixels-per-unit; this scale matches the old vector sizes.
    static let worldScale: CGFloat = 0.3

    static func preload() {
        SKTextureAtlas.preloadTextureAtlasesNamed(["hero", "minion", "drone", "chowchow", "npc_mayor",
                                                   "npc_gran", "npc_tommy", "vehicles"]) { _, _ in }
    }
}

/// An animated character sprite: picks the facing and plays the walk cycle while moving.
final class CharacterSprite: SKSpriteNode {
    private let set: SpriteSet
    private(set) var dir: SpriteDir
    private var walking = false

    init(_ set: SpriteSet, facing: SpriteDir = .s, scale: CGFloat = SpriteSet.worldScale) {
        self.set = set; self.dir = facing
        let tex = set.idle(facing)
        super.init(texture: tex, color: .clear, size: tex.size())
        anchorPoint = CGPoint(x: 0.5, y: 0.18)
        setScale(scale)
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Call every frame (or whenever movement changes). Zero vector = idle.
    func update(velocity v: CGVector, frameTime: TimeInterval = 0.12) {
        let moving = hypot(v.dx, v.dy) > 0.01
        let d = moving ? SpriteDir.from(v) : dir
        guard d != dir || moving != walking else { return }
        dir = d; walking = moving
        removeAction(forKey: "walk")
        if moving {
            run(.repeatForever(.animate(with: set.walk(d), timePerFrame: frameTime)), withKey: "walk")
        } else {
            texture = set.idle(d)
        }
    }
}

extension SKSpriteNode {
    /// A top-down vehicle sprite from the vehicles atlas (points up; rotate with zRotation).
    static func vehicle(_ name: String) -> SKSpriteNode {
        let s = SKSpriteNode(texture: SpriteSet.vehicles.textureNamed(name))
        s.setScale(SpriteSet.worldScale)
        return s
    }
}
