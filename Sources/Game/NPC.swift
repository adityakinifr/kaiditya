import SpriteKit

/// A talkable townsperson. Holds an id, name, and dialogue that can change
/// depending on mission state (resolved by the scene at talk-time).
final class NPC: SKNode {
    let id: String
    let displayName: String
    private let nameTag = RichLabel()
    private let bang = RichLabel(text: "!")

    init(id: String, name: String, tint: SKColor) {
        self.id = id
        self.displayName = name
        super.init()

        let body = SpriteSet.npcs[id].map { CharacterFactory.makeSpriteCharacter($0, shadowWidth: 30, footY: -16) }
            ?? CharacterFactory.makeNPC(tint: tint)
        body.zPosition = 0.5
        addChild(body)

        nameTag.text = name
        nameTag.fontName = "AvenirNext-Bold"
        nameTag.fontSize = 11
        nameTag.fontColor = .white
        nameTag.verticalAlignmentMode = .center
        let plate = roundedRect(size: CGSize(width: nameTag.frame.width + 14, height: 18),
                                corner: 6, color: SKColor(white: 0, alpha: 0.5))
        plate.position = CGPoint(x: 0, y: 44)
        plate.zPosition = 8
        plate.addChild(nameTag)
        addChild(plate)

        bang.fontName = "AvenirNext-Heavy"
        bang.fontSize = 28
        bang.fontColor = Palette.energy
        bang.position = CGPoint(x: 0, y: 64)
        bang.zPosition = 8
        bang.alpha = 0
        addChild(bang)

        zPosition = ZLayer.characters
    }

    required init?(coder: NSCoder) { fatalError() }

    func setQuestMarker(_ on: Bool) {
        if on && bang.alpha == 0 {
            bang.removeAllActions()
            bang.alpha = 1
            bang.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 6, duration: 0.4),
                .moveBy(x: 0, y: -6, duration: 0.4)
            ])))
        } else if !on {
            bang.removeAllActions()
            bang.alpha = 0
        }
    }
}
