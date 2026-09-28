import SpriteKit

/// Heads-up display parented to the camera so it stays fixed on screen.
/// Shows mission objective, crystal count, energy meter, plus a transient toast.
/// Fully responsive: the mission panel and corner cluster reflow to the screen.
/// Skinned as part of the toon "toy set": ink-outlined panels, Lilita One display type.
final class HUD: SKNode {
    // Mission panel (container + 9-slice background)
    private let missionContainer = SKNode()
    private var missionBG = ToonArt.rect(size: CGSize(width: 200, height: 70), style: ToonArt.RectStyle(corner: 14, fill: Theme.panelHUD))
    private let levelLabel = RichLabel()
    private let missionTitle = RichLabel()
    private let missionHint = RichLabel()
    private let missionProgress = RichLabel()
    private var panelW: CGFloat = 300
    private let panelInset: CGFloat = 10

    // Top-right cluster
    private let crystalIcon = ToonIcon.crystal.sprite(24)
    private let crystalLabel = RichLabel()
    private let coinIcon = ToonIcon.coin.sprite(20)
    private let coinLabel = RichLabel()
    private var energyBarBG = SKSpriteNode()
    private let energyBarFill = SKSpriteNode()
    private let energyIcon = SKSpriteNode()
    private var energyBarWidth: CGFloat = 108
    private let barH: CGFloat = 17

    private let toastBanner = SKNode()
    private var toastBG = SKSpriteNode()
    private let toast = RichLabel()

    // Boss health bar (shown during a boss fight)
    private let bossBar = SKNode()
    private var bossBarBG = SKSpriteNode()
    private let bossBarFill = SKSpriteNode()
    private let bossName = RichLabel()
    private var bossBarWidth: CGFloat = 220
    private let bossHint = RichLabel()

    // Lives (hearts)
    private let livesNode = SKNode()

    private var size: CGSize = .zero
    private var lastEnergy: CGFloat = 1
    private var topInsetStored: CGFloat = 20
    private var toastRestY: CGFloat = 0

    /// Inner fill textures for bars (tinted pill with a lighter top edge, no outline).
    private static func barTexture(_ c: SKColor) -> ToonArt.RectStyle {
        ToonArt.RectStyle(corner: 4, fill: c, outline: 0, shadow: 0)
    }

    override init() {
        super.init()
        zPosition = ZLayer.hud
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func styleDisplay(_ l: RichLabel, size: CGFloat, color: SKColor = .white) {
        l.fontName = Theme.display; l.fontSize = size; l.fontColor = color
        l.shadowColor = Palette.ink.withAlphaComponent(0.85); l.shadowOffset = CGVector(dx: 0, dy: -1.5)
    }

    private func build() {
        // Mission panel
        missionContainer.zPosition = ZLayer.hud
        addChild(missionContainer)
        missionBG.zPosition = 0
        missionContainer.addChild(missionBG)

        levelLabel.fontName = Theme.display
        levelLabel.fontSize = 13
        levelLabel.fontColor = Palette.hudAccent
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .center
        levelLabel.zPosition = 1
        missionContainer.addChild(levelLabel)

        missionTitle.fontName = Theme.bodyBold
        missionTitle.fontSize = 14
        missionTitle.fontColor = .white
        missionTitle.horizontalAlignmentMode = .left
        missionTitle.verticalAlignmentMode = .center
        missionTitle.numberOfLines = 2
        missionTitle.zPosition = 1
        missionContainer.addChild(missionTitle)

        missionHint.fontName = Theme.body
        missionHint.fontSize = 11.5
        missionHint.fontColor = Theme.textDim
        missionHint.horizontalAlignmentMode = .left
        missionHint.verticalAlignmentMode = .center
        missionHint.numberOfLines = 1
        missionHint.zPosition = 1
        missionContainer.addChild(missionHint)

        missionProgress.fontName = Theme.display
        missionProgress.fontSize = 17
        missionProgress.fontColor = Palette.crystal
        missionProgress.horizontalAlignmentMode = .right
        missionProgress.verticalAlignmentMode = .center
        missionProgress.zPosition = 1
        missionContainer.addChild(missionProgress)

        // Crystal counter
        addChild(crystalIcon)
        styleDisplay(crystalLabel, size: 22)
        crystalLabel.horizontalAlignmentMode = .left
        crystalLabel.verticalAlignmentMode = .center
        crystalLabel.text = "0"
        addChild(crystalLabel)

        // Coin counter (hidden until a coin is collected)
        coinIcon.isHidden = true; addChild(coinIcon)
        styleDisplay(coinLabel, size: 19)
        coinLabel.horizontalAlignmentMode = .left; coinLabel.verticalAlignmentMode = .center
        coinLabel.text = "0"; coinLabel.isHidden = true; addChild(coinLabel)

        // Energy bar (toon trough + gold fill + bolt badge)
        energyBarFill.zPosition = 1
        energyBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        addChild(energyBarFill)
        energyIcon.texture = GlyphIcon.bolt.texture(size: 18 * UIScreen.main.scale, color: Palette.energy)
        energyIcon.size = CGSize(width: 18, height: 18)
        energyIcon.zPosition = 2
        let boltShadow = SKSpriteNode(texture: energyIcon.texture, size: energyIcon.size)
        boltShadow.color = Palette.ink; boltShadow.colorBlendFactor = 1; boltShadow.zPosition = -0.1
        boltShadow.position = CGPoint(x: 1, y: -1.5)
        energyIcon.addChild(boltShadow)
        addChild(energyIcon)

        // Toast banner (pill that drops from the top-center)
        toastBanner.zPosition = ZLayer.hud + 6
        toastBanner.alpha = 0
        addChild(toastBanner)
        toast.fontName = Theme.display
        toast.fontSize = 17
        toast.fontColor = .white
        toast.verticalAlignmentMode = .center
        toast.horizontalAlignmentMode = .center
        toast.zPosition = 1
        toastBanner.addChild(toast)

        // Boss bar (hidden until a boss fight)
        bossBar.zPosition = ZLayer.hud
        bossBar.isHidden = true
        addChild(bossBar)
        styleDisplay(bossName, size: 16, color: Palette.heroRed)
        bossName.verticalAlignmentMode = .center; bossName.horizontalAlignmentMode = .center
        bossBar.addChild(bossName)
        bossBarFill.anchorPoint = CGPoint(x: 0, y: 0.5); bossBarFill.zPosition = 1
        // Persistent how-to-fight hint shown under the boss bar.
        bossHint.fontName = Theme.bodyBold; bossHint.fontSize = 11.5; bossHint.fontColor = .white
        bossHint.shadowColor = Palette.ink.withAlphaComponent(0.85); bossHint.shadowOffset = CGVector(dx: 0, dy: -1.2)
        bossHint.verticalAlignmentMode = .center; bossHint.horizontalAlignmentMode = .center
        bossBar.addChild(bossHint)

        // Lives hearts (top-right cluster).
        livesNode.zPosition = ZLayer.hud
        addChild(livesNode)
    }

    /// A dark ink trough with a 2.5 pt outline; bars fill it from the left.
    private func trough(width: CGFloat, height: CGFloat) -> SKSpriteNode {
        ToonArt.rect(size: CGSize(width: width, height: height + 2),
                     style: ToonArt.RectStyle(corner: height / 2, fill: SKColor(red: 0.08, green: 0.09, blue: 0.16, alpha: 0.72),
                                              outline: 2.5, shadow: 2))
    }

    /// Set the heart row: `remaining` filled, the rest dimmed.
    func setLives(_ remaining: Int, max maxLives: Int) {
        livesNode.removeAllChildren()
        for i in 0..<maxLives {
            let h = (i < remaining ? ToonIcon.heart : ToonIcon.heartEmpty).sprite(20)
            h.position = CGPoint(x: 10 + CGFloat(i) * 21, y: 0)
            livesNode.addChild(h)
        }
    }

    func showBossBar(name: String, total: Int) {
        let halfW = size.width / 2, halfH = size.height / 2
        let pad: CGFloat = 12, clusterW: CGFloat = 132
        let top = halfH - topInsetStored - pad
        bossBarWidth = size.width - clusterW - 28
        let centerX = (-halfW + 12 + (halfW - clusterW - 12)) / 2
        missionContainer.isHidden = true

        bossBarBG.removeFromParent()
        bossBarBG = trough(width: bossBarWidth, height: 18)
        bossBarBG.position = CGPoint(x: centerX, y: top - 30); bossBar.addChild(bossBarBG)
        bossBarFill.removeFromParent(); bossBar.addChild(bossBarFill)
        bossBar.children.filter { $0.name == "tick" }.forEach { $0.removeFromParent() }
        // phase tick marks
        if total > 3 {
            for s in stride(from: 3, to: total, by: 3) {
                let frac = CGFloat(s) / CGFloat(total)
                let tick = SKSpriteNode(color: Palette.ink, size: CGSize(width: 2.5, height: 12))
                tick.name = "tick"
                tick.position = CGPoint(x: centerX - (bossBarWidth - 6)/2 + (bossBarWidth - 6) * frac, y: bossBarBG.position.y + 1)
                tick.zPosition = 2; bossBar.addChild(tick)
            }
        }
        bossName.text = "⚡ \(name) ⚡"
        bossName.position = CGPoint(x: centerX, y: top - 8)
        bossHint.removeFromParent(); bossBar.addChild(bossHint)
        bossHint.text = "Get close as HERO & tap HIT!  ·  SHIELD blocks zaps"
        bossHint.position = CGPoint(x: centerX, y: top - 50)
        bossHint.setScale(1)
        let hintMax = bossBarWidth + 16
        if bossHint.frame.width > hintMax { bossHint.setScale(hintMax / bossHint.frame.width) }
        bossHint.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)])))
        bossBar.isHidden = false
        updateBossHealth(remaining: total, total: total)
    }

    func updateBossHealth(remaining: Int, total: Int) {
        let p = max(0, min(1, CGFloat(remaining) / CGFloat(max(1, total))))
        let inner = bossBarWidth - 6, h: CGFloat = 12
        let color = p < 0.34 ? Palette.energy : Palette.heroRed
        let bar = ToonArt.rect(size: CGSize(width: 10, height: h), style: Self.barTexture(color))
        bossBarFill.texture = bar.texture; bossBarFill.centerRect = bar.centerRect
        bossBarFill.size = CGSize(width: max(h, inner * p), height: h)
        bossBarFill.isHidden = p <= 0
        bossBarFill.position = CGPoint(x: bossBarBG.position.x - inner / 2, y: bossBarBG.position.y + 1)
    }

    func hideBossBar() {
        bossBar.isHidden = true
        missionContainer.isHidden = false
    }

    /// Mission panel height: tight for a one-line title, taller when it wraps.
    private func panelHeight() -> CGFloat {
        let twoLines = (missionTitle.frame.height > missionTitle.fontSize * 1.7)
        return twoLines ? 78 : 62
    }

    /// Prefer a single (slightly condensed) title line so the panel stays short;
    /// only genuinely long titles wrap to two lines.
    private func fitTitle() {
        let maxW = panelW - (panelInset + 2) * 2
        missionTitle.setScale(1)
        missionTitle.preferredMaxLayoutWidth = 0
        missionTitle.numberOfLines = 1
        let w = missionTitle.frame.width
        if w <= maxW { return }
        if w <= maxW / 0.84 { missionTitle.setScale(maxW / w); return }
        missionTitle.numberOfLines = 2
        missionTitle.preferredMaxLayoutWidth = maxW
    }

    /// Positions the mission panel's contents for the current title length.
    private func layoutMissionPanel() {
        guard size != .zero else { return }
        let halfW = size.width / 2, halfH = size.height / 2
        let pad: CGFloat = 12
        let top = halfH - topInsetStored - pad
        fitTitle()
        let panelH = panelHeight()
        let face = panelH - 4   // the bottom 4 pt of the sprite is its drop shadow
        missionBG.size = CGSize(width: panelW, height: panelH)
        missionContainer.position = CGPoint(x: -halfW + pad + panelW/2, y: top - panelH/2)
        let faceTop = panelH/2, faceBottom = panelH/2 - face
        let textLeft = -panelW/2 + panelInset + 2
        levelLabel.position = CGPoint(x: textLeft, y: faceTop - 14)
        missionProgress.position = CGPoint(x: panelW/2 - panelInset - 2, y: faceTop - 14)
        missionHint.position = CGPoint(x: textLeft, y: faceBottom + 12)
        let titleMid = ((faceTop - 24) + (faceBottom + 22)) / 2
        missionTitle.position = CGPoint(x: textLeft, y: titleMid)
        // Keep the single-line hint inside the panel.
        let maxW = panelW - (panelInset + 2) * 2
        missionHint.setScale(1)
        let w = missionHint.frame.width
        if w > maxW { missionHint.setScale(maxW / w) }
    }

    func layout(for size: CGSize, topInset: CGFloat = 0) {
        self.size = size
        self.topInsetStored = topInset
        let halfW = size.width / 2
        let halfH = size.height / 2
        let pad: CGFloat = 12
        let top = halfH - topInset - pad

        // Right cluster reserves a fixed width; the mission panel takes the rest.
        let clusterW: CGFloat = 132
        panelW = min(size.width - clusterW - pad * 2, 380)
        missionHint.preferredMaxLayoutWidth = 0
        layoutMissionPanel()

        // Top-right cluster: crystal counter, energy bar, coins, hearts.
        let left = halfW - clusterW + 4
        crystalIcon.position = CGPoint(x: left + 14, y: top - 14)
        crystalLabel.position = CGPoint(x: left + 32, y: top - 14)

        energyBarWidth = clusterW - 30
        energyBarBG.removeFromParent()
        energyBarBG = trough(width: energyBarWidth, height: barH - 2)
        energyBarBG.zPosition = 0
        addChild(energyBarBG)
        let barCenterX = left + 18 + energyBarWidth / 2
        energyBarBG.position = CGPoint(x: barCenterX, y: top - 42)
        energyIcon.position = CGPoint(x: left + 11, y: top - 41)
        updateEnergy(lastEnergy)

        coinIcon.position = CGPoint(x: left + 14, y: top - 68)
        coinLabel.position = CGPoint(x: left + 30, y: top - 68)

        livesNode.position = CGPoint(x: left + 2, y: top - 92)

        toastRestY = top - 128   // below the mission panel and the hearts row, never on top of them
        if toastBanner.action(forKey: "toast") == nil { toastBanner.position = CGPoint(x: 0, y: toastRestY) }
    }

    func updateObjective(level: String, title: String, hint: String, progress: String) {
        let changed = missionTitle.text != title || missionHint.text != hint
        levelLabel.text = level.uppercased()
        missionTitle.text = title
        missionHint.text = hint
        missionProgress.text = progress
        if changed { layoutMissionPanel() }
    }

    func updateCrystals(_ n: Int) { crystalLabel.text = "\(n)" }

    func setCrystalsHidden(_ hidden: Bool) { crystalIcon.isHidden = hidden; crystalLabel.isHidden = hidden }

    func updateCoins(_ n: Int) {
        coinLabel.text = "\(n)"
        coinIcon.isHidden = n == 0
        coinLabel.isHidden = n == 0
        if n > 0 { coinIcon.run(.sequence([.scale(to: 1.4, duration: 0.08), .scale(to: 1.0, duration: 0.1)])) }
    }

    func resetCoins() { coinLabel.text = "0"; coinIcon.isHidden = true; coinLabel.isHidden = true }

    private var energyLow: Bool?
    func updateEnergy(_ pct: CGFloat) {
        let p = max(0, min(1, pct))
        lastEnergy = p
        let inner = energyBarWidth - 6, h: CGFloat = barH - 8
        let low = p < 0.25
        if low != energyLow || energyBarFill.texture == nil {
            energyLow = low
            let bar = ToonArt.rect(size: CGSize(width: 10, height: h), style: Self.barTexture(low ? Palette.heroRed : Palette.energy))
            energyBarFill.texture = bar.texture; energyBarFill.centerRect = bar.centerRect
        }
        // keep the fill left-anchored within the trough (above its 2 pt shadow band)
        energyBarFill.size = CGSize(width: max(h, inner * p), height: h)
        energyBarFill.isHidden = p <= 0.001
        energyBarFill.position = CGPoint(x: energyBarBG.position.x - inner / 2, y: energyBarBG.position.y + 1)
    }

    func showToast(_ text: String, color: SKColor = .white) {
        toast.setScale(1)
        toast.numberOfLines = 1
        toast.preferredMaxLayoutWidth = 0
        toast.text = text
        toast.fontColor = color
        // Fit the pill on screen: condense slightly, or wrap long messages onto two lines.
        let maxText = max(200, size.width - 24 - 36)
        var h: CGFloat = 42
        let tw = toast.frame.width
        if tw > maxText {
            if tw * 0.86 <= maxText {
                toast.setScale(maxText / tw)
            } else {
                toast.numberOfLines = 2
                toast.preferredMaxLayoutWidth = maxText
                h = 64
            }
        }
        let w = max(160, min(toast.frame.width, maxText) + 36)
        toastBG.removeFromParent()
        toastBG = ToonArt.rect(size: CGSize(width: w, height: h), style: ToonArt.RectStyle(corner: 19, fill: Theme.panelFill, trim: color.withAlphaComponent(0.55)))
        toastBG.zPosition = -1
        toastBanner.insertChild(toastBG, at: 0)
        toast.position = CGPoint(x: 0, y: 2)   // center on the face (above the shadow band)

        toastBanner.removeAction(forKey: "toast")
        toastBanner.alpha = 0
        toastBanner.position = CGPoint(x: 0, y: toastRestY + 22)
        toastBanner.setScale(0.9)
        let drop = SKAction.moveTo(y: toastRestY, duration: 0.22); drop.timingMode = .easeOut
        let pop = SKAction.scale(to: 1, duration: 0.22); pop.timingMode = .easeOut
        toastBanner.run(.sequence([
            .group([.fadeIn(withDuration: 0.16), drop, pop]),
            .wait(forDuration: 1.7),
            .group([.fadeOut(withDuration: 0.35), .moveTo(y: toastRestY + 12, duration: 0.35)])
        ]), withKey: "toast")
    }
}
