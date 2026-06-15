import SpriteKit

/// Heads-up display parented to the camera so it stays fixed on screen.
/// Shows mission objective, crystal count, energy meter, plus a transient toast.
/// Fully responsive: the mission panel and corner cluster reflow to the screen.
final class HUD: SKNode {
    // Mission panel (container + redrawn background)
    private let missionContainer = SKNode()
    private var missionBG = SKShapeNode()
    private let levelLabel = SKLabelNode()
    private let missionTitle = SKLabelNode()
    private let missionHint = SKLabelNode()
    private let missionProgress = SKLabelNode()

    // Top-right cluster
    private let crystalIcon: SKShapeNode
    private let crystalLabel = SKLabelNode()
    private let coinIcon: SKShapeNode
    private let coinLabel = SKLabelNode()
    private let energyBarBG: SKShapeNode
    private let energyBarFill: SKShapeNode
    private var energyBarWidth: CGFloat = 120

    private let toastBanner = SKNode()
    private var toastBG = SKShapeNode()
    private let toast = SKLabelNode()

    // Boss health bar (shown during a boss fight)
    private let bossBar = SKNode()
    private var bossBarBG = SKShapeNode()
    private var bossBarFill = SKShapeNode()
    private let bossName = SKLabelNode()
    private var bossBarWidth: CGFloat = 220
    private var size: CGSize = .zero
    private var lastEnergy: CGFloat = 1
    private var topInsetStored: CGFloat = 20
    private var toastRestY: CGFloat = 0

    override init() {
        coinIcon = SKShapeNode(circleOfRadius: 10)
        crystalIcon = SKShapeNode(circleOfRadius: 13)
        energyBarBG = roundedRect(size: CGSize(width: 120, height: 14), corner: 7, color: SKColor(white: 0, alpha: 0.5))
        energyBarFill = roundedRect(size: CGSize(width: 120, height: 14), corner: 7, color: Palette.energy)
        super.init()
        zPosition = ZLayer.hud
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        // Mission panel
        missionContainer.zPosition = ZLayer.hud
        addChild(missionContainer)
        missionBG.zPosition = 0
        missionContainer.addChild(missionBG)

        levelLabel.fontName = "AvenirNext-Heavy"
        levelLabel.fontSize = 10
        levelLabel.fontColor = Palette.hudAccent
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.verticalAlignmentMode = .center
        levelLabel.zPosition = 1
        missionContainer.addChild(levelLabel)

        missionTitle.fontName = "AvenirNext-Bold"
        missionTitle.fontSize = 13.5
        missionTitle.fontColor = .white
        missionTitle.horizontalAlignmentMode = .left
        missionTitle.verticalAlignmentMode = .center
        missionTitle.numberOfLines = 2
        missionTitle.zPosition = 1
        missionContainer.addChild(missionTitle)

        missionHint.fontName = "AvenirNext-Regular"
        missionHint.fontSize = 11
        missionHint.fontColor = Palette.hudAccent
        missionHint.horizontalAlignmentMode = .left
        missionHint.verticalAlignmentMode = .center
        missionHint.numberOfLines = 1
        missionHint.zPosition = 1
        missionContainer.addChild(missionHint)

        missionProgress.fontName = "AvenirNext-Heavy"
        missionProgress.fontSize = 18
        missionProgress.fontColor = Palette.crystal
        missionProgress.horizontalAlignmentMode = .right
        missionProgress.verticalAlignmentMode = .center
        missionProgress.zPosition = 1
        missionContainer.addChild(missionProgress)

        // Crystal counter
        crystalIcon.fillColor = Palette.crystal
        crystalIcon.strokeColor = .white
        crystalIcon.lineWidth = 2
        addChild(crystalIcon)

        crystalLabel.fontName = "AvenirNext-Heavy"
        crystalLabel.fontSize = 20
        crystalLabel.fontColor = .white
        crystalLabel.horizontalAlignmentMode = .left
        crystalLabel.verticalAlignmentMode = .center
        crystalLabel.text = "0"
        addChild(crystalLabel)

        // Coin counter (hidden until a coin is collected)
        coinIcon.fillColor = Palette.energy; coinIcon.strokeColor = Palette.energy.darker; coinIcon.lineWidth = 2
        coinIcon.isHidden = true; addChild(coinIcon)
        coinLabel.fontName = "AvenirNext-Heavy"; coinLabel.fontSize = 16; coinLabel.fontColor = .white
        coinLabel.horizontalAlignmentMode = .left; coinLabel.verticalAlignmentMode = .center
        coinLabel.text = "0"; coinLabel.isHidden = true; addChild(coinLabel)

        // Energy bar
        addChild(energyBarBG)
        energyBarFill.zPosition = 1
        addChild(energyBarFill)

        // Toast banner (pill that drops from the top-center)
        toastBanner.zPosition = ZLayer.hud + 6
        toastBanner.alpha = 0
        addChild(toastBanner)
        toastBG = roundedRect(size: CGSize(width: 200, height: 38), corner: 19, color: Palette.hudPanel)
        toastBG.strokeColor = Palette.hudAccent; toastBG.lineWidth = 1.5
        toastBanner.addChild(toastBG)
        toast.fontName = "AvenirNext-Bold"
        toast.fontSize = 16
        toast.fontColor = .white
        toast.verticalAlignmentMode = .center
        toast.horizontalAlignmentMode = .center
        toastBanner.addChild(toast)

        // Boss bar (hidden until a boss fight)
        bossBar.zPosition = ZLayer.hud
        bossBar.isHidden = true
        addChild(bossBar)
        bossName.fontName = "AvenirNext-Heavy"; bossName.fontSize = 13; bossName.fontColor = Palette.heroRed
        bossName.verticalAlignmentMode = .center; bossName.horizontalAlignmentMode = .center
        bossBar.addChild(bossName)
    }

    func showBossBar(name: String, total: Int) {
        let halfW = size.width / 2, halfH = size.height / 2
        let pad: CGFloat = 12, clusterW: CGFloat = 132
        let top = halfH - topInsetStored - pad
        bossBarWidth = size.width - clusterW - 28
        let centerX = (-halfW + 12 + (halfW - clusterW - 12)) / 2
        missionContainer.isHidden = true

        bossBarBG.removeFromParent(); bossBarFill.removeFromParent()
        bossBarBG = roundedRect(size: CGSize(width: bossBarWidth, height: 16), corner: 8, color: SKColor(white: 0, alpha: 0.55))
        bossBarBG.strokeColor = Palette.heroRed; bossBarBG.lineWidth = 1.5
        bossBarBG.position = CGPoint(x: centerX, y: top - 30); bossBar.addChild(bossBarBG)
        bossBarFill = roundedRect(size: CGSize(width: bossBarWidth - 4, height: 12), corner: 6, color: Palette.heroRed)
        bossBarFill.position = bossBarBG.position; bossBarFill.zPosition = 1; bossBar.addChild(bossBarFill)
        // phase tick marks
        if total > 3 {
            for s in stride(from: 3, to: total, by: 3) {
                let frac = CGFloat(s) / CGFloat(total)
                let tick = SKSpriteNode(color: SKColor(white: 0, alpha: 0.7), size: CGSize(width: 2, height: 16))
                tick.position = CGPoint(x: centerX - bossBarWidth/2 + bossBarWidth * frac, y: top - 30)
                tick.zPosition = 2; bossBar.addChild(tick)
            }
        }
        bossName.text = "⚡ \(name) ⚡"
        bossName.position = CGPoint(x: centerX, y: top - 8)
        bossBar.isHidden = false
        updateBossHealth(remaining: total, total: total)
    }

    func updateBossHealth(remaining: Int, total: Int) {
        let p = max(0, min(1, CGFloat(remaining) / CGFloat(max(1, total))))
        bossBarFill.xScale = max(0.001, p)
        let leftX = bossBarBG.position.x - (bossBarWidth - 4) / 2
        bossBarFill.position = CGPoint(x: leftX + (bossBarWidth - 4) * p / 2, y: bossBarBG.position.y)
        bossBarFill.fillColor = p < 0.34 ? Palette.energy : Palette.heroRed
    }

    func hideBossBar() {
        bossBar.isHidden = true
        missionContainer.isHidden = false
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
        let panelH: CGFloat = 84
        let panelW = min(size.width - clusterW - pad * 2, 380)
        let panelInset: CGFloat = 12

        // Redraw mission background at the computed width.
        missionBG.removeFromParent()
        missionBG = roundedRect(size: CGSize(width: panelW, height: panelH), corner: 12, color: Palette.hudPanel)
        missionBG.strokeColor = Palette.hudAccent
        missionBG.lineWidth = 1.5
        missionBG.zPosition = 0
        missionContainer.addChild(missionBG)

        missionContainer.position = CGPoint(x: -halfW + pad + panelW/2, y: top - panelH/2)

        let textLeft = -panelW/2 + panelInset
        let progressW: CGFloat = 34
        levelLabel.position = CGPoint(x: textLeft, y: 30)
        missionTitle.preferredMaxLayoutWidth = panelW - panelInset * 2 - progressW
        missionTitle.position = CGPoint(x: textLeft, y: 7)
        missionHint.preferredMaxLayoutWidth = panelW - panelInset * 2 - progressW
        missionHint.position = CGPoint(x: textLeft, y: -27)
        missionProgress.position = CGPoint(x: panelW/2 - panelInset, y: 12)

        // Top-right cluster: crystal counter then energy bar below it.
        crystalIcon.position = CGPoint(x: halfW - clusterW + 18, y: top - 14)
        crystalLabel.position = CGPoint(x: halfW - clusterW + 36, y: top - 14)

        energyBarWidth = clusterW - 24
        energyBarBG.xScale = energyBarWidth / 120
        energyBarFill.xScale = (energyBarWidth / 120) * max(0.001, lastEnergy)
        let barCenterX = halfW - clusterW/2 - 2
        energyBarBG.position = CGPoint(x: barCenterX, y: top - 42)
        updateEnergy(lastEnergy)

        coinIcon.position = CGPoint(x: halfW - clusterW + 20, y: top - 66)
        coinLabel.position = CGPoint(x: halfW - clusterW + 36, y: top - 66)

        toastRestY = top - 4
        if toastBanner.action(forKey: "toast") == nil { toastBanner.position = CGPoint(x: 0, y: toastRestY) }
    }

    func updateObjective(level: String, title: String, hint: String, progress: String) {
        levelLabel.text = level.uppercased()
        missionTitle.text = title
        missionHint.text = hint
        missionProgress.text = progress
    }

    func updateCrystals(_ n: Int) { crystalLabel.text = "\(n)" }

    func updateCoins(_ n: Int) {
        coinLabel.text = "\(n)"
        coinIcon.isHidden = n == 0
        coinLabel.isHidden = n == 0
        if n > 0 { coinIcon.run(.sequence([.scale(to: 1.4, duration: 0.08), .scale(to: 1.0, duration: 0.1)])) }
    }

    func resetCoins() { coinLabel.text = "0"; coinIcon.isHidden = true; coinLabel.isHidden = true }

    func updateEnergy(_ pct: CGFloat) {
        let p = max(0, min(1, pct))
        lastEnergy = p
        let fullScale = energyBarWidth / 120
        energyBarFill.xScale = fullScale * max(0.001, p)
        // keep the fill left-anchored within the bar
        let leftX = energyBarBG.position.x - energyBarWidth / 2
        energyBarFill.position = CGPoint(x: leftX + (energyBarWidth * p) / 2, y: energyBarBG.position.y)
        energyBarFill.fillColor = p < 0.25 ? Palette.heroRed : Palette.energy
    }

    func showToast(_ text: String, color: SKColor = .white) {
        toast.text = text
        toast.fontColor = color
        let w = max(160, toast.frame.width + 44)
        toastBG.removeFromParent()
        toastBG = roundedRect(size: CGSize(width: w, height: 38), corner: 19, color: Palette.hudPanel)
        toastBG.strokeColor = color.withAlphaComponent(0.9); toastBG.lineWidth = 1.5
        toastBG.zPosition = -1
        toastBanner.insertChild(toastBG, at: 0)

        toastBanner.removeAction(forKey: "toast")
        toastBanner.alpha = 0
        toastBanner.position = CGPoint(x: 0, y: toastRestY + 22)
        let drop = SKAction.moveTo(y: toastRestY, duration: 0.22); drop.timingMode = .easeOut
        toastBanner.run(.sequence([
            .group([.fadeIn(withDuration: 0.16), drop]),
            .wait(forDuration: 1.7),
            .group([.fadeOut(withDuration: 0.35), .moveTo(y: toastRestY + 12, duration: 0.35)])
        ]), withKey: "toast")
    }
}
