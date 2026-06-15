import SpriteKit

final class GameScene: SKScene {

    // Persistent nodes
    private let cam = SKCameraNode()
    private let player = Player()
    private var worldNode = SKNode()

    // Controls
    private let joystick = Joystick()
    private var interactBtn: GameButton!
    private var dashBtn: GameButton!
    private var shieldBtn: GameButton!
    private var disguiseBtn: GameButton!
    private var buttonTouches: [ObjectIdentifier: GameButton] = [:]

    // HUD
    private let hud = HUD()

    // Level
    private var levelIndex = 0
    private var level: LevelData = Levels.level1
    private var biome: Biome { level.biome }
    private var worldSize: CGSize { level.worldSize }

    // Entities (rebuilt each level)
    private var npcs: [NPC] = []
    private var minions: [Minion] = []
    private var crystalNodes: [SKShapeNode] = []
    private var coverRects: [CGRect] = []
    private var exitPortal: SKNode?
    private var powerCore: SKShapeNode?
    private var villain: SKNode?

    // Driving level state
    private var truck: SKNode?
    private var trafficCars: [SKSpriteNode] = []
    private var trafficTimer: TimeInterval = 0
    private var driveSpinTimer: TimeInterval = 0
    private var chaseTime: TimeInterval = 0
    private var truckTiredAnnounced = false
    private var roadMinX: CGFloat = 150
    private var roadMaxX: CGFloat = 610

    // Expansion mechanics state
    private var coinNodes: [SKNode] = []
    private var coins = 0
    private var keycardNode: SKNode?
    private var hasKeycard = false
    private var speedPads: [SKNode] = []
    private var magnetNodes: [SKNode] = []
    private var starNodes: [SKNode] = []
    private var lasers: [SKShapeNode] = []
    private var waterRects: [CGRect] = []
    private var magnetTimer: TimeInterval = 0
    private var starTimer: TimeInterval = 0
    private var speedTimer: TimeInterval = 0
    private var bossPhase = 1

    // Atmosphere (parented to camera)
    private var ambientOverlay: SKSpriteNode?
    private var vignetteNode: SKSpriteNode?
    private var ambientEmitter: SKEmitterNode?

    // Objective state
    private enum Objective { case collect, charge, reachExit, boss, done }
    private var objective: Objective = .collect
    private var crystals = 0
    private var bossHits = 0

    // Flow
    private enum State { case title, intro, playing, dialogue, complete, won }
    private var state: State = .title
    private var lastUpdate: TimeInterval = 0
    private var nearestInteract: (() -> Void)?
    private var safeTop: CGFloat = 0
    private var safeBottom: CGFloat = 0
    private var caughtCooldown: TimeInterval = 0

    // Dialogue
    private var dialogueCloseCallbacks: [() -> Void] = []

    // Autopilot (KAIDITYA_DEMO=1)
    private let demoMode = ProcessInfo.processInfo.environment["KAIDITYA_DEMO"] == "1"
    private var demoActionTimer: TimeInterval = 0

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        camera = cam
        addChild(cam)
        addChild(worldNode)
        setupControls()
        updateSafeInsets()
        layoutHUD()
        showTitle()

        DispatchQueue.main.async { [weak self] in _ = self?.becomeFirstResponder() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.updateSafeInsets()
            self.layoutHUD()
            self.refreshAtmosphereForSize()
            self.cam.children.filter { $0.name?.hasSuffix("Overlay") == true }.forEach { self.positionOverlay($0) }
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        updateSafeInsets()
        layoutControls()
        hud.layout(for: size, topInset: safeTop)
        refreshAtmosphereForSize()
        cam.children.filter { $0.name?.hasSuffix("Overlay") == true }.forEach { positionOverlay($0) }
    }

    private func updateSafeInsets() {
        let insets = view?.window?.safeAreaInsets ?? view?.safeAreaInsets
        if let insets {
            safeTop = max(insets.top, 20)
            safeBottom = max(insets.bottom, 16)
        }
    }

    // MARK: - Controls / HUD

    private let controlPanel = SKNode()
    private var moveHint: SKNode?

    private func setupControls() {
        cam.addChild(joystick)

        // Grouped backing for the action cluster (a soft rounded "gamepad" plate).
        let plate = SKShapeNode(circleOfRadius: 108)
        plate.fillColor = SKColor(white: 0.05, alpha: 0.28)
        plate.strokeColor = SKColor(white: 1, alpha: 0.12)
        plate.lineWidth = 1.5
        plate.zPosition = ZLayer.hud - 1
        plate.name = "plate"
        controlPanel.addChild(plate)
        controlPanel.zPosition = ZLayer.hud - 1
        cam.addChild(controlPanel)

        interactBtn = GameButton(key: "interact", title: "TALK", color: Palette.heroBlue, radius: 38)
        dashBtn = GameButton(key: "dash", title: "DASH", color: Palette.energy.darker, radius: 38)
        shieldBtn = GameButton(key: "shield", title: "SHIELD", color: Palette.heroRed, radius: 38)
        disguiseBtn = GameButton(key: "disguise", title: "HIDE", color: Palette.bush, radius: 38)
        for b in [interactBtn!, dashBtn!, shieldBtn!, disguiseBtn!] { cam.addChild(b) }
        interactBtn.setEnabled(false)

        // Left-side "move" hint (a dashed ring), hidden after first use.
        let hint = SKNode()
        let ring = SKShapeNode(circleOfRadius: 52)
        ring.strokeColor = SKColor(white: 1, alpha: 0.3); ring.lineWidth = 3; ring.fillColor = SKColor(white: 1, alpha: 0.05)
        hint.addChild(ring)
        let dot = SKShapeNode(circleOfRadius: 22)
        dot.fillColor = SKColor(white: 1, alpha: 0.18); dot.strokeColor = .clear
        hint.addChild(dot)
        let lbl = SKLabelNode(text: "MOVE"); lbl.fontName = "AvenirNext-Bold"; lbl.fontSize = 11
        lbl.fontColor = SKColor(white: 1, alpha: 0.5); lbl.position = CGPoint(x: 0, y: -70)
        hint.addChild(lbl)
        hint.zPosition = ZLayer.hud
        hint.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)])))
        cam.addChild(hint); moveHint = hint

        cam.addChild(hud)
    }

    private func layoutControls() {
        guard interactBtn != nil else { return }
        let halfW = size.width / 2, halfH = size.height / 2
        let cx = halfW - 116
        let cy = -halfH + safeBottom + 138
        let s: CGFloat = 62
        controlPanel.position = CGPoint(x: cx, y: cy)
        shieldBtn.position   = CGPoint(x: cx,     y: cy + s)   // top
        dashBtn.position     = CGPoint(x: cx + s, y: cy)       // right
        interactBtn.position = CGPoint(x: cx,     y: cy - s)   // bottom
        disguiseBtn.position = CGPoint(x: cx - s, y: cy)       // left
        moveHint?.position = CGPoint(x: -halfW + 92, y: -halfH + safeBottom + 110)
    }

    private func layoutHUD() {
        updateSafeInsets()
        layoutControls()
        hud.layout(for: size, topInset: safeTop)
    }

    private func setControlsHidden(_ hidden: Bool) {
        setButtonsHidden(hidden)
        hud.isHidden = hidden
    }
    private var hasMoved = false
    private func setButtonsHidden(_ hidden: Bool) {
        interactBtn.isHidden = hidden
        dashBtn.isHidden = hidden
        shieldBtn.isHidden = hidden
        disguiseBtn.isHidden = hidden
        controlPanel.isHidden = hidden
        moveHint?.isHidden = hidden || hasMoved
    }

    // MARK: - Level loading

    private func loadLevel(_ idx: Int) {
        levelIndex = idx
        level = Levels.all[idx]

        // Teardown previous world cleanly (prevents lingering actions/closures).
        removeAction(forKey: "bossLoop")
        removeAllActions()
        worldNode.removeAllActions()
        worldNode.removeFromParent()
        worldNode = SKNode()
        addChild(worldNode)

        npcs = []; minions = []; crystalNodes = []; coverRects = []
        exitPortal = nil; powerCore = nil; villain = nil
        truck = nil; trafficCars = []; trafficTimer = 0; driveSpinTimer = 0
        chaseTime = 0; truckTiredAnnounced = false
        coinNodes = []; coins = 0; keycardNode = nil; hasKeycard = false
        speedPads = []; magnetNodes = []; starNodes = []; lasers = []; waterRects = []
        magnetTimer = 0; starTimer = 0; speedTimer = 0; bossPhase = 1
        bossHits = 0; crystals = 0; caughtCooldown = 0
        nearestInteract = nil
        objective = level.isDriving ? .reachExit : .collect

        player.removeFromParent()
        player.resetForLevel()
        player.position = level.heroSpawn
        worldNode.addChild(player)
        disguiseBtn.setTitle("HIDE")

        backgroundColor = biome.groundB
        if level.isDriving {
            player.setDriving(true, boat: level.isBoat)
            buildDrivingWorld()
        } else {
            buildWorld()
        }
        setupAtmosphere()
        cam.position = level.isDriving ? drivingCamera() : clampedCamera(player.position)

        hud.updateObjective(level: "Level \(level.index) · \(level.name)",
                            title: level.objective, hint: objectiveHint(), progress: progressText())
        hud.updateCrystals(0)
        hud.updateCoins(0)
        hud.updateEnergy(1)
        refreshQuestMarkers()
        showLevelIntro()
    }

    private func progressText() -> String {
        if level.isDriving {
            guard let t = truck else { return "" }
            return "\(max(0, Int((t.position.y - player.position.y) / 10)))m"
        }
        switch objective {
        case .collect: return "\(crystals)/\(level.crystalsRequired)"
        default: return "✓"
        }
    }

    private func objectiveHint() -> String {
        if level.isDriving { return "Steer to dodge traffic · BOOST to catch up!" }
        switch objective {
        case .collect: return "Tap HIDE to blend in · HERO to grab crystals"
        case .charge:  return "Bring them to the glowing Power Core"
        case .reachExit: return "Head to the \(level.exitLabel) portal!"
        case .boss:    return "Use SHIELD, then DASH into Lord Chow-Chow!"
        case .done:    return "Victory!"
        }
    }

    // MARK: - World building

    private func buildWorld() {
        buildGround()
        buildPaths()
        for s in level.signs { addSign(text: s.text, at: s.pos) }
        for b in level.buildings { addBuilding(b) }
        for t in level.treeSpots { addTree(at: t) }
        for c in level.coverSpots { addCover(at: c) }
        for spot in level.crystalSpots { addCrystal(at: spot) }
        for wp in level.minionPatrols {
            let m = Minion(waypoints: wp, speed: level.minionSpeed, range: level.minionRange, drone: level.dronesStyle)
            worldNode.addChild(m); minions.append(m)
        }
        if let core = level.corePos { addPowerCore(at: core) }
        for n in level.npcs { addNPCSpec(n) }
        buildMechanics()

        if level.hasBoss {
            addVillain(at: level.exitPos)
        } else {
            let portal = Effects.portal(accent: biome.accent, label: level.exitLabel)
            portal.position = level.exitPos
            portal.zPosition = ZLayer.items
            worldNode.addChild(portal)
            exitPortal = portal
        }

        let border = SKShapeNode(rect: CGRect(origin: .zero, size: worldSize))
        border.strokeColor = biome.borderColor
        border.lineWidth = 10
        border.zPosition = ZLayer.decals
        worldNode.addChild(border)
    }

    // MARK: - Expansion mechanics

    private func buildMechanics() {
        waterRects = level.waterRects
        for r in waterRects {
            let w = SKShapeNode(rect: r, cornerRadius: 14)
            w.fillColor = Palette.water.withAlphaComponent(0.62); w.strokeColor = Palette.water.darker; w.lineWidth = 3
            w.zPosition = ZLayer.pathDeco; worldNode.addChild(w)
        }
        for p in level.coinSpots {
            let c = CharacterFactory.makeCoin(); c.position = p; c.zPosition = ZLayer.items
            c.run(.repeatForever(.sequence([.scaleX(to: 0.3, duration: 0.4), .scaleX(to: 1, duration: 0.4)])))
            worldNode.addChild(c); coinNodes.append(c)
        }
        for p in level.speedPads {
            let pad = roundedRect(size: CGSize(width: 64, height: 64), corner: 12, color: biome.accent.withAlphaComponent(0.45))
            pad.strokeColor = biome.accent; pad.lineWidth = 2; pad.position = p; pad.zPosition = ZLayer.pathDeco + 0.6
            let arrow = SKLabelNode(text: "»»"); arrow.fontName = "AvenirNext-Heavy"; arrow.fontSize = 26
            arrow.fontColor = .white; arrow.verticalAlignmentMode = .center; arrow.zRotation = .pi/2; pad.addChild(arrow)
            worldNode.addChild(pad); speedPads.append(pad)
        }
        for p in level.magnetSpots {
            let m = CharacterFactory.makePowerup("magnet"); m.position = p; m.zPosition = ZLayer.items
            worldNode.addChild(m); magnetNodes.append(m)
        }
        for p in level.starSpots {
            let s = CharacterFactory.makePowerup("star"); s.position = p; s.zPosition = ZLayer.items
            worldNode.addChild(s); starNodes.append(s)
        }
        for p in level.searchlights {
            let sl = Minion(waypoints: [p], speed: 0, range: max(level.minionRange, 175), rotating: true)
            worldNode.addChild(sl); minions.append(sl)
        }
        for p in level.laserGates {
            let beam = SKShapeNode(rectOf: CGSize(width: 220, height: 10), cornerRadius: 5)
            beam.fillColor = Palette.heroRed.withAlphaComponent(0.85); beam.strokeColor = Palette.heroRed; beam.glowWidth = 6
            beam.position = p; beam.zPosition = ZLayer.fx
            beam.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.1), .wait(forDuration: 1.1),
                                               .fadeAlpha(to: 0.06, duration: 0.1), .wait(forDuration: 0.9)])))
            for ex in [-110.0, 110.0] {
                let emitter = SKShapeNode(circleOfRadius: 9); emitter.fillColor = SKColor(white: 0.28, alpha: 1)
                emitter.strokeColor = Palette.heroRed; emitter.lineWidth = 2; emitter.position = CGPoint(x: ex, y: 0); beam.addChild(emitter)
            }
            worldNode.addChild(beam); lasers.append(beam)
        }
        if let kp = level.keycardPos {
            let k = CharacterFactory.makeKeycard(); k.position = kp; k.zPosition = ZLayer.items
            worldNode.addChild(k); keycardNode = k
        }
    }

    private func blip(_ pos: CGPoint, _ text: String, _ color: SKColor) {
        let s = SKLabelNode(text: text); s.fontSize = 26; s.fontColor = color
        s.position = pos; s.zPosition = ZLayer.fx; worldNode.addChild(s)
        s.run(.sequence([.group([.moveBy(x: 0, y: 42, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    private var playerInWater: Bool { waterRects.contains { $0.contains(player.position) } }

    private func updateMechanics(dt: TimeInterval) {
        if magnetTimer > 0 { magnetTimer -= dt }
        if speedTimer > 0 { speedTimer -= dt }
        if starTimer > 0 { starTimer -= dt; if starTimer <= 0 { player.setStar(false) } }

        let pp = player.position
        for c in coinNodes where c.parent != nil && c.position.distance(to: pp) < 38 {
            c.removeFromParent(); coins += 1; hud.updateCoins(coins); blip(c.position, "★", Palette.energy)
        }
        if let k = keycardNode, k.parent != nil, k.position.distance(to: pp) < 42 {
            k.removeFromParent(); hasKeycard = true
            hud.showToast("Keycard! The exit is unlocked.", color: Palette.energy)
            exitPortal?.run(.fadeIn(withDuration: 0.3))
        }
        for m in magnetNodes where m.parent != nil && m.position.distance(to: pp) < 40 {
            m.removeFromParent(); magnetTimer = 6; hud.showToast("Crystal Magnet! 🧲", color: Palette.crystal)
        }
        for s in starNodes where s.parent != nil && s.position.distance(to: pp) < 40 {
            s.removeFromParent(); starTimer = 6; player.setStar(true); hud.showToast("Super Star — invincible!", color: Palette.energy)
        }
        if magnetTimer > 0 && objective == .collect && player.inCostume {
            for c in crystalNodes where c.parent != nil && c.position.distance(to: pp) < 200 {
                let d = CGVector(dx: pp.x - c.position.x, dy: pp.y - c.position.y)
                let len = max(hypot(d.dx, d.dy), 1)
                c.position.x += d.dx/len * 320 * CGFloat(dt); c.position.y += d.dy/len * 320 * CGFloat(dt)
            }
        }
        for pad in speedPads where pad.position.distance(to: pp) < 40 { speedTimer = 1.3 }
        if starTimer <= 0 && !player.isShielded {
            for beam in lasers where beam.alpha > 0.5
                && abs(beam.position.x - pp.x) < 110 && abs(beam.position.y - pp.y) < 16 {
                handleCaught(); break
            }
        }
        // Stealth takedown: reach a minion while unseen / dashing / starred.
        for m in minions where !m.isStunned && m.position.distance(to: pp) < 36 {
            if starTimer > 0 || player.isDashing || !m.canSee(point: pp) {
                m.stun(3.0); blip(m.position, "💫", biome.accent)
            }
        }
    }

    private func buildGround() {
        let tile: CGFloat = 200
        let cols = Int(worldSize.width / tile) + 1
        let rows = Int(worldSize.height / tile) + 1
        for r in 0..<rows {
            for c in 0..<cols {
                let n = SKSpriteNode(color: (r + c) % 2 == 0 ? biome.groundA : biome.groundB,
                                     size: CGSize(width: tile, height: tile))
                n.position = CGPoint(x: CGFloat(c) * tile + tile/2, y: CGFloat(r) * tile + tile/2)
                n.zPosition = ZLayer.ground
                worldNode.addChild(n)
                // subtle detail fleck for texture
                if (r * 7 + c * 13) % 3 == 0 {
                    let fleck = SKShapeNode(circleOfRadius: 5)
                    fleck.fillColor = biome.groundA.darker.withAlphaComponent(0.35)
                    fleck.strokeColor = .clear
                    fleck.position = CGPoint(x: n.position.x + CGFloat((c*37)%120) - 60,
                                             y: n.position.y + CGFloat((r*53)%120) - 60)
                    fleck.zPosition = ZLayer.ground + 0.5
                    worldNode.addChild(fleck)
                }
            }
        }
    }

    private func buildPaths() {
        // A guiding path strip from the spawn toward the exit.
        let a = level.heroSpawn, b = level.exitPos
        let mid = CGPoint(x: (a.x + b.x)/2, y: (a.y + b.y)/2)
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 1)
        let strip = SKSpriteNode(color: biome.pathColor, size: CGSize(width: len + 120, height: 96))
        strip.position = mid
        strip.zRotation = atan2(dy, dx)
        strip.alpha = 0.9
        strip.zPosition = ZLayer.pathDeco
        worldNode.addChild(strip)
    }

    private func addBuilding(_ spec: BuildingSpec) {
        let p = spec.pos, sz = spec.size
        let shadow = Effects.groundShadow(width: sz.width * 1.05, height: 26)
        shadow.position = CGPoint(x: p.x, y: p.y - sz.height/2 - 6)
        shadow.zPosition = ZLayer.buildings - 0.5
        worldNode.addChild(shadow)

        let wall = roundedRect(size: sz, corner: 8, color: biome.buildingWall, stroke: biome.buildingWall.darker, lineWidth: 2)
        wall.position = p; wall.zPosition = ZLayer.buildings
        worldNode.addChild(wall)
        let roof = roundedRect(size: CGSize(width: sz.width + 16, height: 34), corner: 6, color: spec.roof)
        roof.position = CGPoint(x: p.x, y: p.y + sz.height/2 + 6); roof.zPosition = ZLayer.buildings + 1
        worldNode.addChild(roof)
        let door = roundedRect(size: CGSize(width: 34, height: 46), corner: 4, color: spec.roof.darker)
        door.position = CGPoint(x: p.x, y: p.y - sz.height/2 + 23); door.zPosition = ZLayer.buildings + 1
        worldNode.addChild(door)
        for ddx in [-sz.width/3, sz.width/3] {
            let win = roundedRect(size: CGSize(width: 26, height: 26), corner: 4, color: biome.accent.withAlphaComponent(0.5))
            win.position = CGPoint(x: p.x + ddx, y: p.y + 14); win.zPosition = ZLayer.buildings + 1
            worldNode.addChild(win)
        }
        if let label = spec.label {
            let l = SKLabelNode(text: label)
            l.fontName = "AvenirNext-Heavy"; l.fontSize = 26; l.fontColor = .white
            l.verticalAlignmentMode = .center
            l.position = CGPoint(x: p.x, y: p.y); l.zPosition = ZLayer.buildings + 2
            worldNode.addChild(l)
        }
    }

    private func addTree(at p: CGPoint) {
        let shadow = Effects.groundShadow(width: 80, height: 22)
        shadow.position = CGPoint(x: p.x, y: p.y - 36); shadow.zPosition = ZLayer.decals - 0.5
        worldNode.addChild(shadow)
        let trunk = SKSpriteNode(color: SKColor(red:0.45,green:0.32,blue:0.2,alpha:1), size: CGSize(width: 18, height: 34))
        trunk.position = CGPoint(x: p.x, y: p.y - 30); trunk.zPosition = ZLayer.decals
        worldNode.addChild(trunk)
        let canopy = SKShapeNode(circleOfRadius: 46)
        canopy.fillColor = biome.treeFill; canopy.strokeColor = biome.treeFill.darker; canopy.lineWidth = 2
        canopy.position = p; canopy.zPosition = ZLayer.coverTops
        worldNode.addChild(canopy)
    }

    private func addCover(at p: CGPoint) {
        let (node, rect) = CharacterFactory.makeCover(shape: biome.coverShape, fill: biome.coverFill, detail: biome.coverDetail)
        node.position = p
        node.zPosition = ZLayer.coverTops
        worldNode.addChild(node)
        coverRects.append(CGRect(x: p.x + rect.minX, y: p.y + rect.minY, width: rect.width, height: rect.height))
    }

    private func addCrystal(at p: CGPoint) {
        let glow = SKShapeNode(circleOfRadius: 16)
        glow.fillColor = Palette.crystal.withAlphaComponent(0.2); glow.strokeColor = .clear
        glow.glowWidth = 5
        let c = CharacterFactory.makeCrystal()
        c.position = p; c.zPosition = ZLayer.items
        glow.position = p; glow.zPosition = ZLayer.items - 0.5
        c.run(.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 0.8), .moveBy(x: 0, y: -8, duration: 0.8)])))
        c.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 6)))
        worldNode.addChild(glow); worldNode.addChild(c)
        crystalNodes.append(c)
    }

    private func addPowerCore(at p: CGPoint) {
        let core = SKShapeNode(circleOfRadius: 36)
        core.fillColor = SKColor(white: 0.15, alpha: 1)
        core.strokeColor = biome.accent; core.lineWidth = 4; core.glowWidth = 6
        core.position = p; core.zPosition = ZLayer.buildings
        let ring = SKShapeNode(circleOfRadius: 24)
        ring.strokeColor = biome.accent; ring.lineWidth = 3; ring.fillColor = .clear
        ring.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4)))
        core.addChild(ring)
        let label = SKLabelNode(text: "POWER CORE")
        label.fontName = "AvenirNext-Bold"; label.fontSize = 12; label.fontColor = biome.accent
        label.position = CGPoint(x: 0, y: -54); core.addChild(label)
        worldNode.addChild(core)
        powerCore = core
    }

    private func addVillain(at p: CGPoint) {
        let v = CharacterFactory.makeVillain()
        v.position = p; v.zPosition = ZLayer.characters
        v.run(.repeatForever(.sequence([.moveBy(x:0,y:6,duration:0.6), .moveBy(x:0,y:-6,duration:0.6)])))
        worldNode.addChild(v)
        villain = v
        let l = SKLabelNode(text: "LORD CHOW-CHOW")
        l.fontName = "AvenirNext-Heavy"; l.fontSize = 14; l.fontColor = biome.signColor
        l.position = CGPoint(x: 0, y: 60); l.zPosition = ZLayer.fx
        v.addChild(l)
    }

    private func addNPCSpec(_ spec: NPCSpec) {
        let npc = NPC(id: spec.id, name: spec.name, tint: spec.tint)
        npc.position = spec.pos
        worldNode.addChild(npc); npcs.append(npc)
    }

    private func addSign(text: String, at p: CGPoint) {
        let plate = roundedRect(size: CGSize(width: CGFloat(text.count) * 12 + 28, height: 32), corner: 8, color: biome.signColor)
        plate.strokeColor = .white; plate.lineWidth = 2
        plate.position = p; plate.zPosition = ZLayer.decals
        let l = SKLabelNode(text: text)
        l.fontName = "AvenirNext-Heavy"; l.fontSize = 17; l.fontColor = .white
        l.verticalAlignmentMode = .center
        plate.addChild(l)
        worldNode.addChild(plate)
    }

    // MARK: - Atmosphere

    private func setupAtmosphere() {
        ambientOverlay?.removeFromParent(); vignetteNode?.removeFromParent(); ambientEmitter?.removeFromParent()
        ambientOverlay = nil; vignetteNode = nil; ambientEmitter = nil

        if biome.ambientAlpha > 0 {
            let o = Effects.ambientOverlay(color: biome.ambientColor, alpha: biome.ambientAlpha)
            cam.addChild(o); ambientOverlay = o
        }
        let v = Effects.vignette(screen: size, strength: biome.vignette)
        cam.addChild(v); vignetteNode = v
        if let e = Effects.ambient(biome.ambientFX, screen: size) {
            cam.addChild(e); ambientEmitter = e
        }
    }

    private func refreshAtmosphereForSize() {
        guard vignetteNode != nil || ambientEmitter != nil else { return }
        vignetteNode?.removeFromParent()
        let v = Effects.vignette(screen: size, strength: biome.vignette)
        cam.addChild(v); vignetteNode = v
        if let e = ambientEmitter { e.particlePositionRange = CGVector(dx: size.width + 200, dy: size.height + 200) }
    }

    // MARK: - Driving level

    // Curved road centerline as a function of distance up the road.
    private let curveAmp: CGFloat = 175
    private let curveK: CGFloat = .pi * 2 / 1250
    private let roadHalf: CGFloat = 250
    private func roadCenterX(_ y: CGFloat) -> CGFloat { worldSize.width/2 + curveAmp * sin(y * curveK) }

    private func buildDrivingWorld() {
        // Base: grass for road, deep water for the boat channel.
        let grass = SKSpriteNode(color: level.isBoat ? Palette.water.darker : biome.treeFill, size: worldSize)
        grass.position = CGPoint(x: worldSize.width/2, y: worldSize.height/2)
        grass.zPosition = ZLayer.ground
        worldNode.addChild(grass)

        // Smooth curved asphalt as one filled ribbon (left edge up, right edge back down).
        let ys = stride(from: -60, through: worldSize.height + 60, by: 24).map { $0 }
        let asphalt = CGMutablePath()
        asphalt.move(to: CGPoint(x: roadCenterX(ys[0]) - roadHalf, y: ys[0]))
        for y in ys { asphalt.addLine(to: CGPoint(x: roadCenterX(y) - roadHalf, y: y)) }
        for y in ys.reversed() { asphalt.addLine(to: CGPoint(x: roadCenterX(y) + roadHalf, y: y)) }
        asphalt.closeSubpath()
        let road = SKShapeNode(path: asphalt)
        road.fillColor = biome.pathColor; road.strokeColor = .clear; road.zPosition = ZLayer.pathDeco
        worldNode.addChild(road)

        // Smooth edge lines (stroked curves).
        for sign in [-1.0, 1.0] {
            let edge = CGMutablePath()
            edge.move(to: CGPoint(x: roadCenterX(ys[0]) + CGFloat(sign) * (roadHalf - 8), y: ys[0]))
            for y in ys { edge.addLine(to: CGPoint(x: roadCenterX(y) + CGFloat(sign) * (roadHalf - 8), y: y)) }
            let line = SKShapeNode(path: edge)
            line.strokeColor = biome.signColor; line.lineWidth = 8; line.lineCap = .round
            line.zPosition = ZLayer.pathDeco + 0.4
            worldNode.addChild(line)
        }
        // Center dashed line that follows the curve.
        for laneDX in [-roadHalf/3, roadHalf/3] {
            for y in stride(from: 40, to: Int(worldSize.height), by: 130) {
                let yy = CGFloat(y)
                let dash = SKShapeNode(rectOf: CGSize(width: 9, height: 54), cornerRadius: 3)
                dash.fillColor = SKColor(white: 1, alpha: 0.85); dash.strokeColor = .clear
                // tilt the dash along the local road slope
                let slope = roadCenterX(yy + 20) - roadCenterX(yy - 20)
                dash.zRotation = atan2(40, slope) - .pi/2
                dash.position = CGPoint(x: roadCenterX(yy) + laneDX, y: yy); dash.zPosition = ZLayer.pathDeco + 0.5
                worldNode.addChild(dash)
            }
        }

        buildRoadsideDecor()

        // The getaway vehicle (chase target): truck on road, speedboat on water.
        let t = level.isBoat ? CharacterFactory.makeBoat(body: Palette.villain, big: true) : CharacterFactory.makeTruck()
        t.position = level.exitPos; t.zPosition = ZLayer.characters
        worldNode.addChild(t); truck = t
        let l = SKLabelNode(text: "LORD CHOW-CHOW"); l.fontName = "AvenirNext-Heavy"; l.fontSize = 13
        l.fontColor = biome.signColor; l.position = CGPoint(x: 0, y: 80); t.addChild(l)
    }

    /// Varied scenery beyond the road shoulders for an interesting backdrop.
    private func buildRoadsideDecor() {
        var idx = 0
        for y in stride(from: 160, to: Int(worldSize.height) - 120, by: 270) {
            let cy = CGFloat(y)
            for side in [-1.0, 1.0] {
                let cx = roadCenterX(cy) + CGFloat(side) * (roadHalf + 95)
                switch (idx + (side < 0 ? 0 : 1)) % 5 {
                case 0: addTree(at: CGPoint(x: cx, y: cy))
                case 1: addBillboard(at: CGPoint(x: cx, y: cy), flip: side > 0)
                case 2: addBuildingCluster(at: CGPoint(x: cx + CGFloat(side) * 40, y: cy))
                case 3: addLamp(at: CGPoint(x: roadCenterX(cy) + CGFloat(side) * (roadHalf + 22), y: cy))
                default: addPond(at: CGPoint(x: cx + CGFloat(side) * 30, y: cy))
                }
            }
            idx += 1
        }
    }

    private func addBillboard(at p: CGPoint, flip: Bool) {
        let post = SKSpriteNode(color: SKColor(white: 0.3, alpha: 1), size: CGSize(width: 10, height: 60))
        post.position = CGPoint(x: p.x, y: p.y - 30); post.zPosition = ZLayer.decals
        worldNode.addChild(post)
        let board = roundedRect(size: CGSize(width: 110, height: 64), corner: 8,
                                color: [Palette.heroBlue, Palette.heroRed, Palette.energy.darker].randomishPick(p.y))
        board.strokeColor = .white; board.lineWidth = 2
        board.position = p; board.zPosition = ZLayer.coverTops
        let msg = ["GO KAIDITYA!", "⚡ DANGER", "CITY 12 mi", "K-MART", "TURBO!"].randomishPick(p.y)
        let txt = SKLabelNode(text: msg); txt.fontName = "AvenirNext-Heavy"; txt.fontSize = 13
        txt.fontColor = .white; txt.verticalAlignmentMode = .center
        txt.numberOfLines = 2; txt.preferredMaxLayoutWidth = 100; board.addChild(txt)
        worldNode.addChild(board)
    }

    private func addBuildingCluster(at p: CGPoint) {
        for (i, dx) in [-50.0, 0.0, 52.0].enumerated() {
            let h = [70.0, 110.0, 86.0][i]
            let b = roundedRect(size: CGSize(width: 46, height: h), corner: 4,
                                color: biome.buildingWall.darker)
            b.strokeColor = biome.buildingWall.darker.darker; b.lineWidth = 1
            b.position = CGPoint(x: p.x + dx, y: p.y); b.zPosition = ZLayer.coverTops
            worldNode.addChild(b)
            for wy in stride(from: -Int(h)/2 + 14, to: Int(h)/2 - 6, by: 20) {
                for wx in [-12, 12] {
                    let w = SKSpriteNode(color: Palette.energy.withAlphaComponent(0.7), size: CGSize(width: 8, height: 8))
                    w.position = CGPoint(x: p.x + dx + CGFloat(wx), y: p.y + CGFloat(wy)); w.zPosition = ZLayer.coverTops + 0.5
                    worldNode.addChild(w)
                }
            }
        }
    }

    private func addLamp(at p: CGPoint) {
        let post = SKSpriteNode(color: SKColor(white: 0.35, alpha: 1), size: CGSize(width: 6, height: 46))
        post.position = CGPoint(x: p.x, y: p.y - 23); post.zPosition = ZLayer.decals
        worldNode.addChild(post)
        let glow = SKShapeNode(circleOfRadius: 16)
        glow.fillColor = Palette.energy.withAlphaComponent(0.5); glow.strokeColor = Palette.energy
        glow.glowWidth = 6; glow.position = p; glow.zPosition = ZLayer.coverTops
        worldNode.addChild(glow)
    }

    private func addPond(at p: CGPoint) {
        let pond = SKShapeNode(ellipseOf: CGSize(width: 130, height: 90))
        pond.fillColor = Palette.water; pond.strokeColor = Palette.water.darker; pond.lineWidth = 3
        pond.position = p; pond.zPosition = ZLayer.decals
        worldNode.addChild(pond)
    }

    private func drivingCamera() -> CGPoint {
        // Follow the car in x (so it never leaves the screen) and look ahead in y.
        let lookAhead = size.height * 0.16
        let camX = max(size.width/2, min(worldSize.width - size.width/2, player.position.x))
        let camY = max(size.height/2, min(worldSize.height - size.height/2, player.position.y + lookAhead))
        return CGPoint(x: camX, y: camY)
    }

    private func updateDriving(dt: TimeInterval) {
        let dtf = CGFloat(dt)
        var speed: CGFloat = 330 + (player.isDashing ? 360 : 0)
        if driveSpinTimer > 0 { speed *= 0.45; driveSpinTimer -= dt }
        player.position.y += speed * dtf

        // Steering (x). Clamp to the curving road.
        let steer = joystick.vector.dx + keyboardVector().dx
        let cx = roadCenterX(player.position.y)
        player.position.x = max(cx - roadHalf + 36, min(cx + roadHalf - 36, player.position.x + steer * 320 * dtf))
        player.carNode?.zRotation = -steer * 0.22

        // Real chase: the truck flees fast at first (you must BOOST to keep up),
        // then gradually tires so you can close the gap with time + skill.
        chaseTime += dt
        let truckSpeed = max(195, 370 - CGFloat(chaseTime) * 7.5)
        if let t = truck {
            t.position.y = min(t.position.y + truckSpeed * dtf, worldSize.height - 200)
            t.position.x = roadCenterX(t.position.y) + sin(t.position.y / 200) * 70
        }
        if truckSpeed <= 330 && !truckTiredAnnounced {
            truckTiredAnnounced = true
            hud.showToast("Lord Chow-Chow is tiring — catch him!", color: biome.accent)
        }

        // Same-direction traffic to overtake (spawns ahead, moves up slower).
        trafficTimer += dt
        if trafficTimer > 0.8 { trafficTimer = 0; spawnTraffic() }
        for car in trafficCars {
            car.position.y += 150 * dtf
            car.position.x = roadCenterX(car.position.y) + (car.userData?["lane"] as? CGFloat ?? 0)
            if car.position.y < player.position.y - 360 { car.removeFromParent() }
        }
        trafficCars.removeAll { $0.parent == nil }

        if driveSpinTimer <= 0 {
            for car in trafficCars where abs(car.position.x - player.position.x) < 46 && abs(car.position.y - player.position.y) < 86 {
                drivingCrash(into: car); break
            }
        }

        if let t = truck, t.position.y - player.position.y < 100 {
            objective = .done
            hud.showToast("Gotcha, Lord Chow-Chow! 🚓", color: biome.accent)
            player.position.y = t.position.y - 100
            completeLevel()
        }
        hud.updateObjective(level: "Level \(level.index) · \(level.name)", title: level.objective, hint: objectiveHint(), progress: progressText())
    }

    private func spawnTraffic() {
        let laneOffsets: [CGFloat] = [-roadHalf/2, 0, roadHalf/2]
        let lane = laneOffsets[Int(abs(player.position.y / 53).rounded()) % 3]
        let palette = [SKColor(red:0.9,green:0.4,blue:0.4,alpha:1), SKColor(red:0.4,green:0.6,blue:0.85,alpha:1),
                       SKColor(red:0.95,green:0.8,blue:0.35,alpha:1), SKColor(white: 0.85, alpha: 1)]
        let color = palette[Int(abs(player.position.x + trafficTimer*1000)) % 4]
        let car = level.isBoat ? CharacterFactory.makeBoat(body: color) : CharacterFactory.makeCar(body: color)
        let spawnY = player.position.y + size.height * 0.7
        let sprite = SKSpriteNode(color: .clear, size: CGSize(width: 48, height: 84))
        sprite.addChild(car)
        sprite.userData = ["lane": lane]
        sprite.position = CGPoint(x: roadCenterX(spawnY) + lane, y: spawnY)
        sprite.zPosition = ZLayer.characters - 0.1
        worldNode.addChild(sprite)
        trafficCars.append(sprite)
    }

    private func drivingCrash(into car: SKSpriteNode) {
        driveSpinTimer = 0.7
        player.position.y -= 60
        player.carNode?.run(.sequence([.rotate(byAngle: .pi * 2, duration: 0.5), .run { [weak self] in self?.player.carNode?.zRotation = 0 }]))
        car.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        hud.showToast("CRASH! 💥", color: Palette.heroRed)
        let flash = SKSpriteNode(color: SKColor(red:1,green:0.3,blue:0.2,alpha:0.35), size: CGSize(width: 6000, height: 6000))
        flash.zPosition = ZLayer.overlay - 1; cam.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func applyControlMode() {
        if level.isDriving {
            shieldBtn.isHidden = true; disguiseBtn.isHidden = true; interactBtn.isHidden = true
            controlPanel.isHidden = true
            dashBtn.isHidden = false; dashBtn.setTitle("BOOST")
        } else {
            controlPanel.isHidden = false
            dashBtn.setTitle("DASH")
            setButtonsHidden(false)
        }
    }

    // MARK: - Screens

    private func positionOverlay(_ node: SKNode) { node.position = .zero }

    /// Radial light rays behind a card for a dramatic reveal.
    private func rayBurst(accent: SKColor) -> SKNode {
        let node = SKNode()
        let count = 16
        for i in 0..<count {
            let ray = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: -28, y: 520))
                p.addLine(to: CGPoint(x: 28, y: 520))
                p.closeSubpath(); return p
            }())
            ray.fillColor = accent.withAlphaComponent(0.06)
            ray.strokeColor = .clear
            ray.zRotation = CGFloat(i) / CGFloat(count) * .pi * 2
            node.addChild(ray)
        }
        node.zPosition = -1
        node.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 40)))
        return node
    }

    /// Slam-in bounce + flash for a card; optional ray burst behind it.
    private func dramatize(_ card: SKNode, in overlay: SKNode, accent: SKColor, rays: Bool = true) {
        if rays {
            let burst = rayBurst(accent: accent)
            burst.position = card.position
            overlay.insertChild(burst, at: min(1, overlay.children.count))
            burst.setScale(0.2); burst.alpha = 0
            burst.run(.group([.fadeAlpha(to: 1, duration: 0.5), .scale(to: 1, duration: 0.6)]))
        }
        card.setScale(1.35); card.alpha = 0
        let pop = SKAction.scale(to: 1.0, duration: 0.32)
        pop.timingMode = .easeOut
        card.run(.group([.fadeIn(withDuration: 0.16), pop]))

        let flash = SKSpriteNode(color: .white, size: CGSize(width: 6000, height: 6000))
        flash.alpha = 0.0; flash.zPosition = ZLayer.overlay + 10
        overlay.addChild(flash)
        flash.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.06), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func showTitle() {
        state = .title
        setControlsHidden(true)
        let overlay = SKNode()
        overlay.name = "titleOverlay"; overlay.zPosition = ZLayer.overlay

        let bg = SKSpriteNode(color: SKColor(red: 0.10, green: 0.13, blue: 0.22, alpha: 1), size: CGSize(width: 4000, height: 4000))
        overlay.addChild(bg)
        // soft sky particles
        if let stars = Effects.ambient(.sparks, screen: size) {
            stars.particleColor = SKColor(red: 0.5, green: 0.8, blue: 1, alpha: 1)
            stars.particleBirthRate = 6; overlay.addChild(stars)
        }

        let card = roundedRect(size: CGSize(width: min(size.width - 40, 460), height: 340), corner: 24, color: Palette.hudPanel)
        card.strokeColor = Palette.hudAccent; card.lineWidth = 2
        card.position = CGPoint(x: 0, y: 30); overlay.addChild(card)

        let title = SKLabelNode(text: "KAIDITYA")
        title.fontName = "AvenirNext-Heavy"; title.fontSize = 56; title.fontColor = Palette.energy
        title.position = CGPoint(x: 0, y: 96); card.addChild(title)
        let sub = SKLabelNode(text: "Pint-Sized Hero, Big-Time Save")
        sub.fontName = "AvenirNext-Medium"; sub.fontSize = 17; sub.fontColor = .white
        sub.position = CGPoint(x: 0, y: 56); card.addChild(sub)

        let hero = CharacterFactory.makeHero()
        hero.setScale(1.7); hero.position = CGPoint(x: 0, y: -8)
        hero.run(.repeatForever(.sequence([.moveBy(x:0,y:9,duration:0.5), .moveBy(x:0,y:-9,duration:0.5)])))
        card.addChild(hero)

        let play = roundedRect(size: CGSize(width: 220, height: 56), corner: 14, color: Palette.heroBlue)
        play.strokeColor = .white; play.lineWidth = 2
        play.position = CGPoint(x: 0, y: -112); play.name = "playButton"
        play.run(.repeatForever(.sequence([.scale(to: 1.04, duration: 0.7), .scale(to: 1.0, duration: 0.7)])))
        let playLabel = SKLabelNode(text: "▶  PLAY")
        playLabel.fontName = "AvenirNext-Heavy"; playLabel.fontSize = 23; playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center; play.addChild(playLabel)
        card.addChild(play)

        dramatize(card, in: overlay, accent: Palette.energy)
        cam.addChild(overlay)
        positionOverlay(overlay)
    }

    private func showLevelIntro() {
        state = .intro
        setControlsHidden(true)
        let overlay = SKNode()
        overlay.name = "introOverlay"; overlay.zPosition = ZLayer.overlay
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55), size: CGSize(width: 4000, height: 4000))
        overlay.addChild(dim)

        let card = roundedRect(size: CGSize(width: min(size.width - 36, 520), height: 260), corner: 22, color: Palette.hudPanel)
        card.strokeColor = biome.accent; card.lineWidth = 2.5
        overlay.addChild(card)

        let eyebrow = SKLabelNode(text: "LEVEL \(level.index)")
        eyebrow.fontName = "AvenirNext-Heavy"; eyebrow.fontSize = 16; eyebrow.fontColor = biome.accent
        eyebrow.position = CGPoint(x: 0, y: 86); card.addChild(eyebrow)
        let name = SKLabelNode(text: level.name)
        name.fontName = "AvenirNext-Heavy"; name.fontSize = 34; name.fontColor = .white
        name.position = CGPoint(x: 0, y: 46); card.addChild(name)
        let sub = SKLabelNode(text: level.subtitle)
        sub.fontName = "AvenirNext-Medium"; sub.fontSize = 15; sub.fontColor = SKColor(white: 0.85, alpha: 1)
        sub.numberOfLines = 2; sub.preferredMaxLayoutWidth = min(size.width - 90, 460)
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: 6); card.addChild(sub)
        let obj = SKLabelNode(text: "🎯  " + level.objective)
        obj.fontName = "AvenirNext-Medium"; obj.fontSize = 14; obj.fontColor = biome.accent
        obj.numberOfLines = 2; obj.preferredMaxLayoutWidth = min(size.width - 90, 460)
        obj.verticalAlignmentMode = .center
        obj.position = CGPoint(x: 0, y: -46); card.addChild(obj)
        let go = SKLabelNode(text: "tap to begin ▸")
        go.fontName = "AvenirNext-Bold"; go.fontSize = 14; go.fontColor = .white
        go.position = CGPoint(x: 0, y: -98); card.addChild(go)
        go.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))

        dramatize(card, in: overlay, accent: biome.accent)
        cam.addChild(overlay)
        positionOverlay(overlay)
    }

    private func dismissIntro() {
        cam.childNode(withName: "introOverlay")?.removeFromParent()
        state = .playing
        setControlsHidden(false)
        applyControlMode()
        if level.isDriving {
            hud.showToast("Floor it! 🏎️", color: biome.accent)
            return
        }
        if levelIndex == 0 {
            hud.showToast("Find the crystals — and watch the minions!", color: biome.accent)
        } else {
            hud.showToast(level.name + "!", color: biome.accent)
        }
    }

    private func showLevelComplete() {
        state = .complete
        setControlsHidden(true)
        let overlay = SKNode()
        overlay.name = "completeOverlay"; overlay.zPosition = ZLayer.overlay
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55), size: CGSize(width: 4000, height: 4000))
        overlay.addChild(dim)
        let card = roundedRect(size: CGSize(width: min(size.width - 36, 460), height: 250), corner: 22, color: Palette.hudPanel)
        card.strokeColor = Palette.energy; card.lineWidth = 3
        overlay.addChild(card)
        let badge = SKLabelNode(text: "LEVEL \(level.index) CLEAR!")
        badge.fontName = "AvenirNext-Heavy"; badge.fontSize = 30; badge.fontColor = Palette.energy
        badge.position = CGPoint(x: 0, y: 70); card.addChild(badge)
        let star = SKLabelNode(text: "⭐️ ⭐️ ⭐️")
        star.fontSize = 30; star.position = CGPoint(x: 0, y: 18); card.addChild(star)
        let nextName = Levels.all[levelIndex + 1].name
        let nxt = SKLabelNode(text: "Next: \(nextName)")
        nxt.fontName = "AvenirNext-Medium"; nxt.fontSize = 16; nxt.fontColor = .white
        nxt.position = CGPoint(x: 0, y: -34); card.addChild(nxt)
        let go = SKLabelNode(text: "tap to continue ▸")
        go.fontName = "AvenirNext-Bold"; go.fontSize = 14; go.fontColor = Palette.hudAccent
        go.position = CGPoint(x: 0, y: -82); card.addChild(go)
        go.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))
        // stars pop in sequence
        star.setScale(0); star.run(.sequence([.wait(forDuration: 0.3), .scale(to: 1.0, duration: 0.3)]))
        dramatize(card, in: overlay, accent: Palette.energy)
        if let conf = Effects.ambient(.sparks, screen: size) {
            conf.particleColor = Palette.energy; conf.particleBirthRate = 40
            conf.run(.sequence([.wait(forDuration: 1.5), .run { conf.particleBirthRate = 0 }]))
            overlay.addChild(conf)
        }
        cam.addChild(overlay)
        positionOverlay(overlay)
    }

    private func showWinScreen() {
        state = .won
        setControlsHidden(true)
        let overlay = SKNode(); overlay.name = "winOverlay"; overlay.zPosition = ZLayer.overlay
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.62), size: CGSize(width: 5000, height: 5000))
        overlay.addChild(dim)
        if let conf = Effects.ambient(.sparks, screen: size) {
            conf.particleColor = Palette.energy; conf.particleBirthRate = 30; overlay.addChild(conf)
        }
        let card = roundedRect(size: CGSize(width: min(size.width - 28, 520), height: 330), corner: 22, color: Palette.hudPanel)
        card.strokeColor = Palette.energy; card.lineWidth = 3
        overlay.addChild(card)
        let t1 = SKLabelNode(text: "YOU SAVED"); t1.fontName = "AvenirNext-Heavy"; t1.fontSize = 40; t1.fontColor = Palette.energy
        t1.position = CGPoint(x: 0, y: 108); card.addChild(t1)
        let t2 = SKLabelNode(text: "THE WORLD!"); t2.fontName = "AvenirNext-Heavy"; t2.fontSize = 40; t2.fontColor = Palette.energy
        t2.position = CGPoint(x: 0, y: 62); card.addChild(t2)
        let s = SKLabelNode(text: "Lord Chow-Chow is defeated across the whole city."); s.fontName = "AvenirNext-Medium"; s.fontSize = 15; s.fontColor = .white
        s.position = CGPoint(x: 0, y: 18); card.addChild(s)
        let s2 = SKLabelNode(text: "Kaiditya is the city's greatest hero!"); s2.fontName = "AvenirNext-Medium"; s2.fontSize = 15; s2.fontColor = .white
        s2.position = CGPoint(x: 0, y: -6); card.addChild(s2)
        let hero = CharacterFactory.makeHero(); hero.setScale(1.8); hero.position = CGPoint(x: 0, y: -92)
        hero.run(.repeatForever(.sequence([.moveBy(x:0,y:10,duration:0.5), .moveBy(x:0,y:-10,duration:0.5)])))
        card.addChild(hero)
        dramatize(card, in: overlay, accent: Palette.energy)
        cam.addChild(overlay)
        positionOverlay(overlay)
    }

    // MARK: - Dialogue

    private func showDialogue(speaker: String, lines: [String], onClose: (() -> Void)? = nil) {
        state = .dialogue
        setButtonsHidden(true)
        joystick.end()
        let overlay = SKNode(); overlay.name = "dialogueOverlay"; overlay.zPosition = ZLayer.overlay

        let boxW = min(size.width - 28, 640), inset: CGFloat = 26
        let box = roundedRect(size: CGSize(width: boxW, height: 180), corner: 16, color: Palette.hudPanel)
        box.strokeColor = Palette.hudAccent; box.lineWidth = 2
        let finalY = -size.height/2 + safeBottom + 110
        box.position = CGPoint(x: 0, y: finalY)
        overlay.addChild(box)
        // slide up with a slight overshoot
        box.position.y = finalY - 240; box.alpha = 0
        let rise = SKAction.moveTo(y: finalY, duration: 0.28); rise.timingMode = .easeOut
        box.run(.group([.fadeIn(withDuration: 0.18), rise]))

        // speaker name plate that pops
        let nameBg = roundedRect(size: CGSize(width: CGFloat(speaker.count) * 12 + 26, height: 30), corner: 10, color: Palette.heroBlue)
        nameBg.strokeColor = .white; nameBg.lineWidth = 1.5
        nameBg.position = CGPoint(x: -boxW/2 + inset + (CGFloat(speaker.count) * 12 + 26)/2 - 6, y: 76)
        nameBg.zPosition = 2; box.addChild(nameBg)
        nameBg.setScale(0); nameBg.run(.sequence([.wait(forDuration: 0.12), .scale(to: 1, duration: 0.2)]))
        let name = SKLabelNode(text: speaker)
        name.fontName = "AvenirNext-Heavy"; name.fontSize = 18; name.fontColor = .white
        name.verticalAlignmentMode = .center; nameBg.addChild(name)
        let body = SKLabelNode(text: lines.first ?? "")
        body.fontName = "AvenirNext-Medium"; body.fontSize = 17; body.fontColor = .white
        body.horizontalAlignmentMode = .left; body.verticalAlignmentMode = .top
        body.numberOfLines = 4; body.preferredMaxLayoutWidth = boxW - inset * 2
        body.position = CGPoint(x: -boxW/2 + inset, y: 30); body.name = "dlgBody"; box.addChild(body)
        let hint = SKLabelNode(text: "tap to continue ▸")
        hint.fontName = "AvenirNext-Medium"; hint.fontSize = 13; hint.fontColor = Palette.hudAccent
        hint.horizontalAlignmentMode = .right; hint.position = CGPoint(x: boxW/2 - inset, y: -70); box.addChild(hint)

        overlay.userData = ["lines": lines, "idx": 0]
        if let cb = onClose { dialogueCloseCallbacks.append(cb) }
        cam.addChild(overlay)
    }

    private func advanceDialogue() {
        guard let overlay = cam.childNode(withName: "dialogueOverlay"),
              var idx = overlay.userData?["idx"] as? Int,
              let lines = overlay.userData?["lines"] as? [String] else { return }
        idx += 1
        if idx >= lines.count {
            overlay.removeFromParent()
            state = .playing
            setButtonsHidden(false)
            let cbs = dialogueCloseCallbacks; dialogueCloseCallbacks.removeAll()
            cbs.forEach { $0() }
        } else {
            overlay.userData?["idx"] = idx
            (overlay.childNode(withName: "//dlgBody") as? SKLabelNode)?.text = lines[idx]
        }
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let p = t.location(in: self)
            let camP = t.location(in: cam)
            switch state {
            case .title:    startGame(); return
            case .intro:    dismissIntro(); return
            case .dialogue: advanceDialogue(); return
            case .complete: cam.childNode(withName: "completeOverlay")?.removeFromParent(); loadLevel(levelIndex + 1); return
            case .won:      return
            case .playing:  break
            }
            if !interactBtn.isHidden, interactBtn.enabled, interactBtn.contains(scenePoint: p, in: self) {
                interactBtn.press(); buttonTouches[ObjectIdentifier(t)] = interactBtn; nearestInteract?(); continue
            }
            if dashBtn.contains(scenePoint: p, in: self) {
                dashBtn.press(); buttonTouches[ObjectIdentifier(t)] = dashBtn
                if !player.tryDash() { hud.showToast("Need power!", color: Palette.heroRed) }; continue
            }
            if shieldBtn.contains(scenePoint: p, in: self) {
                shieldBtn.press(); buttonTouches[ObjectIdentifier(t)] = shieldBtn
                if player.tryShield() { hud.showToast("Shield up!", color: Palette.hudAccent) }
                else { hud.showToast("Need power!", color: Palette.heroRed) }; continue
            }
            if disguiseBtn.contains(scenePoint: p, in: self) {
                disguiseBtn.press(); buttonTouches[ObjectIdentifier(t)] = disguiseBtn; toggleDisguise(); continue
            }
            if !joystick.isActive {
                joystick.begin(at: camP, touch: t)
                if !hasMoved { hasMoved = true; moveHint?.isHidden = true }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches where joystick.owns(t) { joystick.update(to: t.location(in: cam)) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { buttonTouches[ObjectIdentifier(t)] = nil; if joystick.owns(t) { joystick.end() } }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }

    // MARK: - Keyboard

    private var pressedKeys = Set<UIKeyboardHIDUsage>()
    override var canBecomeFirstResponder: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses { if let key = press.key { handled = true; handleKeyDown(key.keyCode) } }
        if !handled { super.pressesBegan(presses, with: event) }
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { pressedKeys.remove(key.keyCode) } }
        super.pressesEnded(presses, with: event)
    }

    private func handleKeyDown(_ code: UIKeyboardHIDUsage) {
        switch state {
        case .title: startGame(); return
        case .intro: dismissIntro(); return
        case .complete: cam.childNode(withName: "completeOverlay")?.removeFromParent(); loadLevel(levelIndex + 1); return
        case .dialogue:
            if code == .keyboardSpacebar || code == .keyboardReturnOrEnter || code == .keyboardJ { advanceDialogue() }
            return
        case .won: return
        case .playing: break
        }
        switch code {
        case .keyboardSpacebar, .keyboardReturnOrEnter, .keyboardJ: nearestInteract?()
        case .keyboardK: if !player.tryDash() { hud.showToast("Need power!", color: Palette.heroRed) }
        case .keyboardL:
            if player.tryShield() { hud.showToast("Shield up!", color: Palette.hudAccent) }
            else { hud.showToast("Need power!", color: Palette.heroRed) }
        case .keyboardH: toggleDisguise()
        default: pressedKeys.insert(code); nudge(for: code)
        }
    }

    private func nudge(for code: UIKeyboardHIDUsage) {
        var dx: CGFloat = 0, dy: CGFloat = 0
        switch code {
        case .keyboardW, .keyboardUpArrow: dy = 1
        case .keyboardS, .keyboardDownArrow: dy = -1
        case .keyboardA, .keyboardLeftArrow: dx = -1
        case .keyboardD, .keyboardRightArrow: dx = 1
        default: return
        }
        let step: CGFloat = 55
        player.position = CGPoint(x: max(30, min(worldSize.width - 30, player.position.x + dx*step)),
                                  y: max(30, min(worldSize.height - 30, player.position.y + dy*step)))
        player.faceMovement(CGVector(dx: dx, dy: dy))
        if !hasMoved { hasMoved = true; moveHint?.isHidden = true }
    }

    private func keyboardVector() -> CGVector {
        var dx: CGFloat = 0, dy: CGFloat = 0
        for k in pressedKeys {
            switch k {
            case .keyboardW, .keyboardUpArrow: dy += 1
            case .keyboardS, .keyboardDownArrow: dy -= 1
            case .keyboardA, .keyboardLeftArrow: dx -= 1
            case .keyboardD, .keyboardRightArrow: dx += 1
            default: break
            }
        }
        let mag = sqrt(dx*dx + dy*dy)
        return mag < 0.01 ? .zero : CGVector(dx: dx/mag, dy: dy/mag)
    }

    private func startGame() {
        cam.childNode(withName: "titleOverlay")?.removeFromParent()
        let start = Int(ProcessInfo.processInfo.environment["KAIDITYA_START_LEVEL"] ?? "") ?? 0
        loadLevel(min(max(start, 0), Levels.all.count - 1))
    }

    private func toggleDisguise() {
        player.setCostume(!player.inCostume)
        if player.inCostume { disguiseBtn.setTitle("HIDE"); hud.showToast("Hero mode! Minions can see you.", color: Palette.heroRed) }
        else { disguiseBtn.setTitle("HERO"); hud.showToast("Secret identity — blend in!", color: Palette.bush.lighter) }
    }

    // MARK: - Update

    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 { lastUpdate = currentTime }
        let dt = min(currentTime - lastUpdate, 1.0/30.0)
        lastUpdate = currentTime
        if demoMode { runDemo(dt: dt) }

        // Driving levels use a dedicated update path.
        if level.isDriving {
            if state == .playing { updateDriving(dt: dt) }
            player.update(dt: dt)
            cam.position = drivingCamera()
            hud.updateEnergy(player.energyPct)
            if !demoMode { dashBtn.setEnabled(player.energy >= 25) }
            return
        }

        if state == .playing { movePlayer(dt: dt) }
        player.update(dt: dt)
        cam.position = clampedCamera(player.position)

        for m in minions { m.update(dt: dt) }
        if state == .playing {
            updateStealth(dt: dt)
            updatePickups(dt: dt)
            updateMechanics(dt: dt)
            updateObjectiveProximity()
            updateInteractTarget()
        }
        hud.updateEnergy(player.energyPct)
        if !demoMode {
            dashBtn.setEnabled(player.energy >= 25)
            shieldBtn.setEnabled(player.energy >= 35 && !player.isShielded)
        }
    }

    private func clampedCamera(_ pos: CGPoint) -> CGPoint {
        CGPoint(x: max(size.width/2, min(worldSize.width - size.width/2, pos.x)),
                y: max(size.height/2, min(worldSize.height - size.height/2, pos.y)))
    }

    private func movePlayer(dt: TimeInterval) {
        var v = joystick.vector
        if v.dx == 0 && v.dy == 0 { v = keyboardVector() }
        if v.dx == 0 && v.dy == 0 { player.stopWalk(); return }
        var spd = player.currentSpeed()
        if speedTimer > 0 { spd *= 1.7 }       // speed pad boost
        if playerInWater { spd *= 0.5 }        // water slows you down
        let nx = max(30, min(worldSize.width - 30, player.position.x + v.dx * spd * CGFloat(dt)))
        let ny = max(30, min(worldSize.height - 30, player.position.y + v.dy * spd * CGFloat(dt)))
        player.position = CGPoint(x: nx, y: ny)
        player.faceMovement(v)
    }

    // MARK: - Stealth

    private var playerHidden: Bool { coverRects.contains { $0.contains(player.position) } }

    private func updateStealth(dt: TimeInterval) {
        if caughtCooldown > 0 { caughtCooldown -= dt }
        let exposed = player.inCostume && !playerHidden && !player.isShielded && starTimer <= 0
        var caught = false
        for m in minions {
            let sees = exposed && m.canSee(point: player.position)
            m.setSeeing(sees, dt: dt)
            if sees && m.alertLevel >= 1 { caught = true }
        }
        player.visual.alpha = playerHidden ? 0.55 : (player.inCostume ? 1.0 : 0.92)
        if caught { handleCaught() }
    }

    private func handleCaught() {
        guard caughtCooldown <= 0 else { return }
        caughtCooldown = 2.0
        let flash = SKSpriteNode(color: SKColor(red:1,green:0,blue:0,alpha:0.4), size: CGSize(width: 6000, height: 6000))
        flash.zPosition = ZLayer.overlay - 1; cam.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        // During the boss fight, a hit just knocks you back a little (don't reset the arena).
        if objective == .boss {
            hud.showToast("Zapped! 💥", color: Palette.heroRed)
            if let v = villain {
                let away = CGVector(dx: player.position.x - v.position.x, dy: player.position.y - v.position.y)
                let len = max(hypot(away.dx, away.dy), 1)
                player.position.x = max(40, min(worldSize.width - 40, player.position.x + away.dx/len * 120))
                player.position.y = max(40, min(worldSize.height - 40, player.position.y + away.dy/len * 120))
            }
        } else {
            hud.showToast("Spotted! Back to the start.", color: Palette.heroRed)
            player.position = level.heroSpawn
        }
        for m in minions { m.setSeeing(false, dt: 1) }
    }

    // MARK: - Pickups & objective

    private func updatePickups(dt: TimeInterval) {
        guard objective == .collect, player.inCostume else { return }
        for c in crystalNodes where c.parent != nil {
            if c.position.distance(to: player.position) < 42 { collectCrystal(c) }
        }
    }

    private func collectCrystal(_ c: SKShapeNode) {
        c.removeFromParent()
        crystals += 1
        player.addEnergy(18)
        hud.updateCrystals(crystals)
        hud.showToast("Energy Crystal! ✦  (\(crystals)/\(level.crystalsRequired))", color: Palette.crystal)
        let spark = SKLabelNode(text: "✦"); spark.fontSize = 28; spark.fontColor = Palette.crystal
        spark.position = c.position; spark.zPosition = ZLayer.fx; worldNode.addChild(spark)
        spark.run(.sequence([.group([.moveBy(x:0,y:44,duration:0.5), .fadeOut(withDuration:0.5)]), .removeFromParent()]))
        hud.updateObjective(level: "Level \(level.index) · \(level.name)", title: level.objective, hint: objectiveHint(), progress: progressText())
        if crystals >= level.crystalsRequired { advanceFromCollect() }
    }

    private func advanceFromCollect() {
        if level.corePos != nil {
            objective = .charge
            hud.showToast("All crystals! Charge the Power Core.", color: biome.accent)
        } else {
            activateExit()
        }
        hud.updateObjective(level: "Level \(level.index) · \(level.name)", title: level.objective, hint: objectiveHint(), progress: progressText())
    }

    private func activateExit() {
        objective = level.hasBoss ? .boss : .reachExit
        let needsKey = (level.keycardPos != nil && !hasKeycard)
        if !needsKey { exitPortal?.run(.fadeIn(withDuration: 0.4)); exitPortal?.run(.scale(to: 1.2, duration: 0.2)) }
        if level.hasBoss {
            hud.showToast("Now confront Lord Chow-Chow!", color: Palette.heroRed)
        } else if needsKey {
            hud.showToast("Find the keycard, then reach the \(level.exitLabel)!", color: biome.accent)
        } else {
            hud.showToast("The \(level.exitLabel) is open — go!", color: biome.accent)
        }
    }

    private func updateObjectiveProximity() {
        // Walk into an active portal to finish a non-boss level (keycard required if any).
        if objective == .reachExit, let portal = exitPortal,
           (level.keycardPos == nil || hasKeycard),
           portal.position.distance(to: player.position) < 46 {
            completeLevel()
        }
    }

    private func completeLevel() {
        objective = .done
        if levelIndex + 1 < Levels.all.count {
            let burst = SKShapeNode(circleOfRadius: 30); burst.strokeColor = biome.accent; burst.lineWidth = 4; burst.fillColor = .clear
            burst.position = player.position; burst.zPosition = ZLayer.fx; worldNode.addChild(burst)
            burst.run(.sequence([.group([.scale(to: 6, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
            showLevelComplete()
        } else {
            showWinScreen()
        }
    }

    // MARK: - Interactions

    private func updateInteractTarget() {
        nearestInteract = nil
        var label = "TALK"; var enabled = false

        if let npc = nearestNPC(), npc.position.distance(to: player.position) < 70 {
            enabled = true; label = "TALK"; nearestInteract = { [weak self] in self?.talkTo(npc) }
        }
        if objective == .charge, let core = powerCore, core.position.distance(to: player.position) < 80 {
            enabled = true; label = "CHARGE"; nearestInteract = { [weak self] in self?.chargeCore() }
        }
        if objective == .boss, let v = villain, v.position.distance(to: player.position) < 96 {
            enabled = true; label = "FIGHT"; nearestInteract = { [weak self] in self?.fightVillain() }
        }
        interactBtn.setTitle(label)
        interactBtn.setEnabled(enabled)
    }

    private func nearestNPC() -> NPC? {
        npcs.min(by: { $0.position.distance(to: player.position) < $1.position.distance(to: player.position) })
    }

    private func talkTo(_ npc: NPC) {
        switch npc.id {
        case "mayor":
            showDialogue(speaker: "Mayor Mia", lines: [
                "Kaiditya! Lord Chow-Chow stole our Energy Crystals!",
                "Sneak into the Static Zone and bring back \(level.crystalsRequired).",
                "Tap HIDE to disguise as a normal kid so minions ignore you — switch to HERO to grab a crystal. Bushes hide you too!"
            ])
        case "kid":
            showDialogue(speaker: "Tommy", lines: ["Whoa, a REAL superhero!", "Tap DASH to zoom super fast!"])
        case "gran":
            showDialogue(speaker: "Granny Gold", lines: ["Careful, dearie.", "Minions can't see you if you hide in the bushes."])
        default:
            showDialogue(speaker: npc.displayName, lines: ["Go get 'em, hero!"])
        }
    }

    private func chargeCore() {
        guard let core = powerCore else { return }
        objective = .reachExit
        core.run(.sequence([.scale(to: 1.3, duration: 0.2), .scale(to: 1.0, duration: 0.2)]))
        let burst = SKShapeNode(circleOfRadius: 40); burst.strokeColor = biome.accent; burst.lineWidth = 4; burst.fillColor = .clear
        burst.position = core.position; burst.zPosition = ZLayer.fx; worldNode.addChild(burst)
        burst.run(.sequence([.group([.scale(to: 4, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        activateExit()
        hud.updateObjective(level: "Level \(level.index) · \(level.name)", title: level.objective, hint: objectiveHint(), progress: progressText())
    }

    private func fightVillain() {
        guard objective == .boss else { return }
        objective = .done   // lock interaction; boss loop drives the rest
        showDialogue(speaker: "Lord Chow-Chow", lines: [
            "You?! A pint-sized hero?",
            "I'll zap you with my static powers!"
        ]) { [weak self] in
            self?.objective = .boss
            self?.hud.showToast("SHIELD up, then DASH into Static!", color: Palette.energy)
            self?.beginBossFight()
        }
    }

    private func beginBossFight() {
        guard let v = villain else { return }
        v.run(.repeatForever(.sequence([.moveBy(x: 140, y: 0, duration: 0.8), .moveBy(x: -140, y: 0, duration: 0.8)])), withKey: "dodge")
        run(.repeatForever(.sequence([.wait(forDuration: 0.05), .run { [weak self] in self?.checkBossHit() }])), withKey: "bossLoop")
    }

    private func checkBossHit() {
        guard objective == .boss, let v = villain else { return }
        let hitsPerPhase = 3
        let totalNeeded = hitsPerPhase * level.bossPhases
        if v.position.distance(to: player.position) < 74 && player.isDashing && action(forKey: "hitCooldown") == nil {
            bossHits += 1
            run(.wait(forDuration: 0.6), withKey: "hitCooldown")
            v.run(.sequence([.scale(to: 0.8, duration: 0.1), .scale(to: 1.0, duration: 0.1)]))
            let pow = SKLabelNode(text: "POW!"); pow.fontName = "AvenirNext-Heavy"; pow.fontSize = 30; pow.fontColor = Palette.heroRed
            pow.position = CGPoint(x: v.position.x, y: v.position.y + 50); pow.zPosition = ZLayer.fx; worldNode.addChild(pow)
            pow.run(.sequence([.group([.moveBy(x:0,y:30,duration:0.4), .fadeOut(withDuration:0.4)]), .removeFromParent()]))
            hud.showToast("Hit \(bossHits)/\(totalNeeded)!", color: Palette.energy)
            // Phase transition?
            if bossHits < totalNeeded && bossHits % hitsPerPhase == 0 {
                bossPhase += 1
                startBossPhase()
            }
            if bossHits >= totalNeeded { defeatVillain() }
        }
    }

    private func startBossPhase() {
        guard let v = villain else { return }
        hud.showToast("Lord Chow-Chow is FURIOUS! Phase \(bossPhase)!", color: Palette.heroRed)
        let flash = SKSpriteNode(color: SKColor(red:1,green:0.2,blue:0.2,alpha:0.4), size: CGSize(width: 6000, height: 6000))
        flash.zPosition = ZLayer.overlay - 1; cam.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        // faster dodging
        v.removeAction(forKey: "dodge")
        let d = max(0.4, 0.85 - CGFloat(bossPhase) * 0.15)
        v.run(.repeatForever(.sequence([.moveBy(x: 170, y: 0, duration: d), .moveBy(x: -170, y: 0, duration: d)])), withKey: "dodge")
        // spawn two guard minions
        for sx in [-160.0, 160.0] {
            let m = Minion(waypoints: [CGPoint(x: v.position.x + sx, y: v.position.y - 120),
                                       CGPoint(x: v.position.x + sx, y: v.position.y + 120)],
                           speed: 110, range: 150)
            worldNode.addChild(m); minions.append(m)
        }
    }

    private func defeatVillain() {
        removeAction(forKey: "bossLoop")
        objective = .done
        villain?.removeAction(forKey: "dodge")
        villain?.run(.sequence([
            .group([.rotate(byAngle: .pi*4, duration: 0.8), .scale(to: 0.1, duration: 0.8), .fadeOut(withDuration: 0.8)]),
            .removeFromParent()
        ]))
        run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.completeLevel() }]))
    }

    private func refreshQuestMarkers() {
        for npc in npcs { npc.setQuestMarker(npc.id == "mayor" && levelIndex == 0) }
    }

    // MARK: - Autopilot (reactive)

    private func runDemo(dt: TimeInterval) {
        demoActionTimer += dt
        func tap(_ minGap: TimeInterval = 0.8) -> Bool {
            if demoActionTimer >= minGap { demoActionTimer = 0; return true }
            return false
        }
        switch state {
        case .title: if tap(0.5) { startGame() }; return
        case .intro: if tap(1.2) { dismissIntro() }; return
        case .complete: if tap(1.5) { cam.childNode(withName: "completeOverlay")?.removeFromParent(); loadLevel(levelIndex + 1) }; return
        case .dialogue: if tap(0.7) { advanceDialogue() }; return
        case .won: return
        case .playing: break
        }

        // Driving: steer toward the truck, dodging traffic ahead; boost when able.
        if level.isDriving {
            var targetX = truck?.position.x ?? player.position.x
            for c in trafficCars where c.position.y > player.position.y
                && c.position.y - player.position.y < 240 && abs(c.position.x - player.position.x) < 70 {
                targetX = player.position.x + (c.position.x > player.position.x ? -160 : 160)
                break
            }
            let cx = roadCenterX(player.position.y)
            targetX = max(cx - roadHalf + 40, min(cx + roadHalf - 40, targetX))
            let dx = targetX - player.position.x
            player.position.x += (dx > 0 ? 1 : -1) * min(abs(dx), 260) * (1.0/60.0)
            if !player.isDashing && player.energy >= 25 { player.tryDash() }
            return
        }

        // Keep shield up to traverse safely — except during the boss, where
        // energy must be saved for dashing.
        if objective != .boss, !player.isShielded, player.energy >= 40 { player.tryShield() }

        switch objective {
        case .collect:
            if let c = crystalNodes.first(where: { $0.parent != nil }) { demoSteer(to: c.position) }
        case .charge:
            if let core = powerCore { demoSteer(to: core.position); if core.position.distance(to: player.position) < 70, tap(0.4) { chargeCore() } }
        case .reachExit:
            if let k = keycardNode, k.parent != nil, !hasKeycard { demoSteer(to: k.position) }
            else if let p = exitPortal { demoSteer(to: p.position) }
        case .boss:
            if let v = villain {
                demoSteer(to: v.position)
                if v.position.distance(to: player.position) < 90, tap(0.5) { fightVillain() }
                if !player.isDashing && player.energy >= 25 { player.tryDash() }
            }
        case .done: break
        }
    }

    private func demoSteer(to target: CGPoint) {
        let dx = target.x - player.position.x, dy = target.y - player.position.y
        let dist = hypot(dx, dy)
        if dist < 6 { return }
        let spd = player.currentSpeed()
        player.position = CGPoint(x: max(30, min(worldSize.width - 30, player.position.x + dx/dist * spd * (1.0/60.0))),
                                  y: max(30, min(worldSize.height - 30, player.position.y + dy/dist * spd * (1.0/60.0))))
        player.faceMovement(CGVector(dx: dx/dist, dy: dy/dist))
    }
}

extension CGPoint {
    func distance(to p: CGPoint) -> CGFloat { hypot(p.x - x, p.y - y) }
}
