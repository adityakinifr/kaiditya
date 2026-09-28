import SpriteKit

/// Blender-rendered buildings (art/blender/buildings.py -> Resources/Sprites/buildings.atlas).
/// Generated from art/buildings_manifest.json. Offsets are points at world scale 0.3; the anchor puts the
/// centre of the ground footprint on the node position.
enum Buildings {
    struct Spec { let anchor: CGPoint; let footprint: CGSize; let sign: CGPoint; let signSize: CGSize; let door: CGPoint }

    static let spec: [String: Spec] = [
        "bld_arcade": Spec(anchor: CGPoint(x: 0.4103, y: 0.4037), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 8.6), signSize: CGSize(width: 115.2, height: 20.6),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_bunker": Spec(anchor: CGPoint(x: 0.4328, y: 0.4342), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: -7.4), signSize: CGSize(width: 87.3, height: 14.9),
                    door: CGPoint(x: 0.0, y: -81.0)),
        "bld_fortress": Spec(anchor: CGPoint(x: 0.415, y: 0.3457), footprint: CGSize(width: 400, height: 220),
                    sign: CGPoint(x: 0.0, y: -26.8), signSize: CGSize(width: 90.8, height: 15.7),
                    door: CGPoint(x: 0.0, y: -118.0)),
        "bld_house_blue": Spec(anchor: CGPoint(x: 0.4315, y: 0.359), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 1.8), signSize: CGSize(width: 73.3, height: 16.6),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_house_green": Spec(anchor: CGPoint(x: 0.4315, y: 0.359), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 1.8), signSize: CGSize(width: 73.3, height: 16.6),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_house_orange": Spec(anchor: CGPoint(x: 0.4315, y: 0.359), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 1.8), signSize: CGSize(width: 73.3, height: 16.6),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_house_purple": Spec(anchor: CGPoint(x: 0.4315, y: 0.359), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 1.8), signSize: CGSize(width: 73.3, height: 16.6),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_house_red": Spec(anchor: CGPoint(x: 0.4315, y: 0.359), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 1.8), signSize: CGSize(width: 73.3, height: 16.6),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_hq": Spec(anchor: CGPoint(x: 0.4097, y: 0.3659), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: -5.0), signSize: CGSize(width: 61.1, height: 14.3),
                    door: CGPoint(x: 0.0, y: -80.0)),
        "bld_lab": Spec(anchor: CGPoint(x: 0.4131, y: 0.4224), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 1.1), signSize: CGSize(width: 59.3, height: 14.3),
                    door: CGPoint(x: 0.0, y: -81.0)),
        "bld_lair": Spec(anchor: CGPoint(x: 0.397, y: 0.2983), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: -16.5), signSize: CGSize(width: 73.3, height: 14.3),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_pumphouse": Spec(anchor: CGPoint(x: 0.3687, y: 0.3646), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: -8.5), signSize: CGSize(width: 69.8, height: 12.6),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_rooftop": Spec(anchor: CGPoint(x: 0.418, y: 0.4002), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: -14.8), signSize: CGSize(width: 62.8, height: 11.4),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_shop": Spec(anchor: CGPoint(x: 0.4129, y: 0.4282), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 4.8), signSize: CGSize(width: 104.7, height: 17.7),
                    door: CGPoint(x: 0.0, y: -75.0)),
        "bld_warehouse": Spec(anchor: CGPoint(x: 0.4209, y: 0.3734), footprint: CGSize(width: 200, height: 150),
                    sign: CGPoint(x: 0.0, y: 2.7), signSize: CGSize(width: 90.8, height: 15.7),
                    door: CGPoint(x: 0.0, y: -75.0)),
    ]

    static let atlas = SKTextureAtlas(named: "buildings")
    private static let names = SpriteSet.names(in: atlas)
    static func available(_ name: String) -> Bool { spec[name] != nil && names.contains(name) }

    /// Building node sized so its footprint is `width` points wide. Children: "shadow", "sprite", optional "sign".
    static func make(_ name: String, width: CGFloat, label: String?) -> SKNode? {
        guard let s = spec[name], available(name) else { return nil }
        let k = width / s.footprint.width
        let n = SKNode()
        if names.contains(name + "_shadow") {
            let sh = SKSpriteNode(texture: atlas.textureNamed(name + "_shadow"))
            sh.anchorPoint = s.anchor; sh.setScale(SpriteSet.worldScale * k)
            sh.color = Palette.shadowTint; sh.colorBlendFactor = 1; sh.alpha = 0.4
            sh.zPosition = -1; sh.name = "shadow"
            n.addChild(sh)
        }
        let sp = SKSpriteNode(texture: atlas.textureNamed(name))
        sp.anchorPoint = s.anchor; sp.setScale(SpriteSet.worldScale * k); sp.name = "sprite"
        n.addChild(sp)
        if let label {
            let l = SKLabelNode(text: label)
            l.fontName = Theme.display; l.fontColor = Palette.ink
            l.verticalAlignmentMode = .center; l.horizontalAlignmentMode = .center
            let box = CGSize(width: s.signSize.width * k * 0.9, height: s.signSize.height * k * 0.85)
            l.fontSize = 40
            let f = min(box.width / max(1, l.frame.width), box.height / max(1, l.frame.height))
            l.fontSize = max(7, 40 * f)
            l.position = CGPoint(x: s.sign.x * k, y: s.sign.y * k); l.zPosition = 0.1; l.name = "sign"
            n.addChild(l)
        }
        return n
    }

    /// Door threshold offset for a building of footprint `width`.
    static func door(_ name: String, width: CGFloat) -> CGPoint? {
        guard let s = spec[name] else { return nil }
        let k = width / s.footprint.width
        return CGPoint(x: s.door.x * k, y: s.door.y * k)
    }
}
