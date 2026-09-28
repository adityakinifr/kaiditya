import SpriteKit

/// Blender-rendered props (art/blender/props.py -> Resources/Sprites/props.atlas).
/// Anchors come from art/props_manifest.json: the anchor sits on the centre of the ground footprint,
/// so a prop's node position is where it stands. Shadows are alpha-only and tinted violet here.
enum Props {
    /// texture -> (anchorX, anchorY, shadow texture)
    static let spec: [String: (CGFloat, CGFloat, String)] = [
        "barrel": (0.422, 0.466, "barrel_shadow"),
        "bush_a": (0.438, 0.456, "bush_a_shadow"),
        "bush_b": (0.440, 0.458, "bush_b_shadow"),
        "cage_closed": (0.464, 0.357, "cage_closed_shadow"),
        "cage_open": (0.462, 0.357, "cage_open_shadow"),
        "chest_closed": (0.374, 0.506, "chest_closed_shadow"),
        "chest_open": (0.364, 0.373, "chest_open_shadow"),
        "coin_0": (0.346, 0.474, "coin_shadow"),
        "coin_1": (0.346, 0.474, "coin_shadow"),
        "coin_2": (0.346, 0.474, "coin_shadow"),
        "coin_3": (0.346, 0.474, "coin_shadow"),
        "coin_4": (0.346, 0.474, "coin_shadow"),
        "coin_5": (0.346, 0.474, "coin_shadow"),
        "crate_a": (0.452, 0.403, "crate_a_shadow"),
        "crate_b": (0.456, 0.440, "crate_b_shadow"),
        "crate_stack": (0.401, 0.376, "crate_stack_shadow"),
        "crystal_0": (0.293, 0.240, "crystal_shadow"),
        "crystal_1": (0.293, 0.240, "crystal_shadow"),
        "crystal_2": (0.293, 0.240, "crystal_shadow"),
        "crystal_3": (0.293, 0.240, "crystal_shadow"),
        "crystal_4": (0.293, 0.240, "crystal_shadow"),
        "crystal_5": (0.293, 0.240, "crystal_shadow"),
        "crystal_6": (0.293, 0.240, "crystal_shadow"),
        "crystal_7": (0.293, 0.240, "crystal_shadow"),
        "generator_off": (0.351, 0.410, "generator_off_shadow"),
        "generator_on": (0.351, 0.410, "generator_on_shadow"),
        "grapple_anchor": (0.309, 0.288, "grapple_anchor_shadow"),
        "keycard": (0.400, 0.225, "keycard_shadow"),
        "lamp_post": (0.135, 0.170, "lamp_post_shadow"),
        "laser_emitter": (0.300, 0.342, "laser_emitter_shadow"),
        "pillar": (0.396, 0.248, "pillar_shadow"),
        "powerup_magnet": (0.354, 0.300, "powerup_magnet_shadow"),
        "powerup_star": (0.324, 0.316, "powerup_star_shadow"),
        "searchlight_base": (0.344, 0.394, "searchlight_base_shadow"),
        "trap": (0.463, 0.500, "trap_shadow"),
        "tree": (0.489, 0.256, "tree_shadow"),
    ]

    static func available(_ name: String) -> Bool { spec[name] != nil && SpriteSet.hasProp(name) }

    /// A prop node: violet contact shadow + sprite, at world scale × `scale`. The sprite is named "sprite".
    static func make(_ name: String, scale: CGFloat = 1) -> SKNode {
        let n = SKNode()
        let (ax, ay, shadow) = spec[name] ?? (0.5, 0.3, "")
        let anchor = CGPoint(x: ax, y: ay)
        if !shadow.isEmpty, SpriteSet.hasProp(shadow) {
            let sh = SKSpriteNode(texture: SpriteSet.props.textureNamed(shadow))
            sh.anchorPoint = anchor; sh.color = Palette.shadowTint; sh.colorBlendFactor = 1; sh.alpha = 0.45
            sh.zPosition = -1; sh.name = "shadow"
            n.addChild(sh)
        }
        let s = SKSpriteNode(texture: SpriteSet.props.textureNamed(name))
        s.anchorPoint = anchor; s.name = "sprite"
        n.addChild(s)
        n.setScale(SpriteSet.worldScale * scale)
        return n
    }

    /// Looping frame animation (coin spin / crystal twinkle) on a prop made with `make`.
    static func animate(_ node: SKNode, frames prefix: String, count: Int, fps: Double) {
        guard let s = node.childNode(withName: "sprite") as? SKSpriteNode else { return }
        let tex = (0..<count).map { SpriteSet.props.textureNamed("\(prefix)_\($0)") }
        s.run(.repeatForever(.animate(with: tex, timePerFrame: 1 / fps)))
    }

    /// Gentle hover for floating pickups: bobs the sprite, leaves the ground shadow put.
    static func hover(_ node: SKNode, amount: CGFloat = 12, period: Double = 1.2) {
        guard let s = node.childNode(withName: "sprite") else { return }
        let up = SKAction.moveBy(x: 0, y: amount, duration: period / 2); up.timingMode = .easeInEaseOut
        s.run(.repeatForever(.sequence([up, up.reversed()])))
    }
}
