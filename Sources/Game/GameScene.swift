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
    private var grappleBtn: GameButton!
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
    private var hazards: [SKNode] = []
    private var magnetTimer: TimeInterval = 0
    private var starTimer: TimeInterval = 0
    private var speedTimer: TimeInterval = 0
    private var bossPhase = 1
    private var bossFightActive = false
    private let maxLives = 5
    private var lives = 5

    // Difficulty ramps gently with mission progression (levelIndex 0…10).
    private var stealthAlertRate: CGFloat { 1.05 + CGFloat(levelIndex) * 0.10 }  // ~0.95s → ~0.5s to be spotted
    private var stealthRangeMul: CGFloat { 1.0 + CGFloat(levelIndex) * 0.02 }    // up to ~1.2x vision range
    private var stealthSpeedMul: CGFloat { 1.0 + CGFloat(levelIndex) * 0.025 }   // up to ~1.25x patrol/sweep
    private var bossProjectiles: [SKNode] = []
    private var bossCharging = false
    private var bossAttackCounter = 0
    private var grappleAnchorNodes: [SKNode] = []
    private var grappleTarget: SKNode?
    private var grappling = false

    // Progression / map
    private var maxUnlocked = 0

    // Hub
    private var inHub = false
    private var shopDoor: CGPoint?
    private var arcadeDoor: CGPoint?
    private var missionsPortal: SKNode?
    private var chestNode: SKNode?
    private var petNode: SKNode?
    private let chestPos = CGPoint(x: 830, y: 1080)
    private let fountainPos = CGPoint(x: 950, y: 600)
    private var shopFromHub = false
    // Hub side-quest (Tommy's Coin Rush)
    private var questActive = false
    private var questDone = false
    private var questTarget = 5
    private var questProgress = 0
    // Deliver quest (Granny's pie -> Mayor)
    private var deliverActive = false
    private var deliverDone = false
    private var carriedItem: SKNode?

    // Minigame (Crystal Catch)
    private let mgLayer = SKNode()
    private var mgCatcher: SKNode?
    private var mgCrystals: [SKShapeNode] = []
    private var mgScore = 0
    private var mgTime: TimeInterval = 30
    private var mgSpawn: TimeInterval = 0
    private var mgOver = false

    // Camera shake
    private var shakeTime: TimeInterval = 0
    private var shakeMag: CGFloat = 0
    private var shakeElapsed: TimeInterval = 0

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
    private enum State { case title, map, shop, intro, tour, playing, dialogue, complete, won, minigame }
    private var tourStep = 0
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
        maxUnlocked = UserDefaults.standard.integer(forKey: "kaiditya.maxUnlocked")
        SoundFX.shared.warmUp()
        setupControls()
        updateSafeInsets()
        layoutHUD()
        showTitle()

        if ProcessInfo.processInfo.environment["KAIDITYA_SHOP"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.showShop() }
        }
        if ProcessInfo.processInfo.environment["KAIDITYA_HUB"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.cam.childNode(withName: "titleOverlay")?.removeFromParent(); self?.enterHub()
            }
        }
        if let lv = ProcessInfo.processInfo.environment["KAIDITYA_PLAYLEVEL"], let idx = Int(lv) {
            // Jump straight into a level for real play (normal flow: intro → controls).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.cam.childNode(withName: "titleOverlay")?.removeFromParent()
                self?.loadLevel(idx)
            }
        }
        if let lv = ProcessInfo.processInfo.environment["KAIDITYA_VIEWLEVEL"], let idx = Int(lv) {
            // Static level view for art validation: load the level, dismiss the
            // intro, but DO NOT autopilot — the player never moves, so nothing is
            // collected or persisted (keeps the save untouched).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                self.cam.childNode(withName: "titleOverlay")?.removeFromParent()
                let savedMax = UserDefaults.standard.integer(forKey: "kaiditya.maxUnlocked")
                self.loadLevel(idx)
                // loadLevel bumps & persists maxUnlocked — restore it so a static
                // art-preview never unlocks zones in the player's save.
                self.maxUnlocked = savedMax
                UserDefaults.standard.set(savedMax, forKey: "kaiditya.maxUnlocked")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self else { return }
                    self.cam.childNode(withName: "introOverlay")?.removeFromParent()
                    if self.state == .intro { self.state = .playing }
                    self.setControlsHidden(false)   // un-hide the HUD for the preview
                    // Move the camera onto the enemies (offset clear of hazards).
                    if self.level.hasBoss {
                        self.player.position = CGPoint(x: self.level.exitPos.x, y: self.level.exitPos.y - 130)
                    } else if let h = self.level.hazardSpots.first {
                        self.player.position = CGPoint(x: h.x, y: h.y - 80)
                    } else if let s = self.level.searchlights.first {
                        self.player.position = CGPoint(x: s.x, y: s.y - 150)
                    } else if let g = self.level.laserGates.first {
                        self.player.position = CGPoint(x: g.x, y: g.y - 150)
                    } else if let route = self.level.minionPatrols.first, let m = route.first {
                        self.player.position = CGPoint(x: m.x, y: m.y - 90)
                    }
                    self.cam.position = self.clampedCamera(self.player.position)
                    // Preview the live boss fight (bar + hint + HIT button) on boss levels.
                    if self.level.hasBoss { self.objective = .boss; self.beginBossFight() }
                }
            }
        }
        if ProcessInfo.processInfo.environment["KAIDITYA_ARCADE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.cam.childNode(withName: "titleOverlay")?.removeFromParent(); self?.startMinigame()
            }
        }
        if ProcessInfo.processInfo.environment["KAIDITYA_WISH"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                self.cam.childNode(withName: "titleOverlay")?.removeFromParent(); self.enterHub()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self else { return }
                    self.player.position = CGPoint(x: self.fountainPos.x, y: self.fountainPos.y - 70)
                    self.updateHubInteract()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.makeWish() }
                }
            }
        }
        if ProcessInfo.processInfo.environment["KAIDITYA_PET"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                self.cam.childNode(withName: "titleOverlay")?.removeFromParent(); self.enterHub()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                    guard let self, let dog = self.petNode else { return }
                    self.player.position = CGPoint(x: dog.position.x - 40, y: dog.position.y)
                    self.cam.position = self.clampedCamera(self.player.position)
                    self.updateHubInteract()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.petDog() }
                }
            }
        }
        if ProcessInfo.processInfo.environment["KAIDITYA_MAP"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.cam.childNode(withName: "titleOverlay")?.removeFromParent(); self?.showMap()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.showStats() }
            }
        }
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
    private let objectiveArrow = SKNode()

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
        grappleBtn = GameButton(key: "grapple", title: "GRAPPLE", color: Palette.crystal.darker, radius: 38)
        for b in [interactBtn!, dashBtn!, shieldBtn!, disguiseBtn!, grappleBtn!] { cam.addChild(b) }
        interactBtn.setEnabled(false)
        grappleBtn.isHidden = true

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

        // Objective direction arrow (points to keycard / exit / crystals).
        let tri = SKShapeNode(path: {
            let p = CGMutablePath(); p.move(to: CGPoint(x: 16, y: 0))
            p.addLine(to: CGPoint(x: -10, y: -11)); p.addLine(to: CGPoint(x: -10, y: 11)); p.closeSubpath(); return p
        }())
        tri.name = "tri"; tri.fillColor = Palette.energy; tri.strokeColor = .white; tri.lineWidth = 1.5; tri.glowWidth = 2
        objectiveArrow.addChild(tri)
        let arrowLbl = SKLabelNode(text: ""); arrowLbl.name = "lbl"
        arrowLbl.fontName = "AvenirNext-Heavy"; arrowLbl.fontSize = 11; arrowLbl.fontColor = .white
        arrowLbl.verticalAlignmentMode = .center; arrowLbl.horizontalAlignmentMode = .center
        let arrowPlate = roundedRect(size: CGSize(width: 72, height: 18), corner: 9, color: SKColor(white: 0, alpha: 0.6))
        arrowPlate.name = "plate"; arrowPlate.position = CGPoint(x: 0, y: -24); arrowPlate.addChild(arrowLbl)
        objectiveArrow.addChild(arrowPlate)
        objectiveArrow.zPosition = ZLayer.hud + 2
        objectiveArrow.isHidden = true
        cam.addChild(objectiveArrow)

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
        grappleBtn.position  = CGPoint(x: cx,     y: cy + s * 2 + 4)   // contextual, above SHIELD
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
        grappleBtn?.isHidden = true   // contextual; shown by updateGrappleTarget
        objectiveArrow.isHidden = true   // contextual; shown by updateObjectiveArrow
        controlPanel.isHidden = hidden
        moveHint?.isHidden = hidden || hasMoved
    }

    // MARK: - Level loading

    private func loadLevel(_ idx: Int) {
        levelIndex = idx
        level = Levels.all[idx]
        inHub = false
        cam.childNode(withName: "dayNight")?.removeFromParent()
        carriedItem?.removeFromParent(); carriedItem = nil
        deliverActive = false

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
        speedPads = []; magnetNodes = []; starNodes = []; lasers = []; waterRects = []; hazards = []
        magnetTimer = 0; starTimer = 0; speedTimer = 0; bossPhase = 1
        bossProjectiles = []; bossCharging = false; bossAttackCounter = 0; bossFightActive = false
        grappleAnchorNodes = []; grappleTarget = nil; grappling = false
        maxUnlocked = max(maxUnlocked, idx)
        UserDefaults.standard.set(maxUnlocked, forKey: "kaiditya.maxUnlocked")
        bossHits = 0; crystals = 0; caughtCooldown = 0
        lives = maxLives; hud.setLives(lives, max: maxLives)
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
        hud.updateCrystals(0); hud.setCrystalsHidden(false)
        hud.updateCoins(Economy.coins)
        hud.updateEnergy(1)
        hud.hideBossBar()
        refreshQuestMarkers()
        // Background music by level mood.
        if level.isDriving { SoundFX.shared.playMusic("chase") }
        else if level.index == 1 { SoundFX.shared.playMusic("explore") }
        else { SoundFX.shared.playMusic("stealth") }
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
            let m = Minion(waypoints: wp, speed: level.minionSpeed * stealthSpeedMul,
                           range: level.minionRange * stealthRangeMul, drone: level.dronesStyle)
            m.alertRate = stealthAlertRate
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
            let sl = Minion(waypoints: [p], speed: 0, range: max(level.minionRange, 175) * stealthRangeMul, rotating: true)
            sl.alertRate = stealthAlertRate
            sl.sweepSpeed = 1.1 * stealthSpeedMul
            worldNode.addChild(sl); minions.append(sl)
        }
        for p in level.laserGates {
            let beam = SKShapeNode(rectOf: CGSize(width: 220, height: 10), cornerRadius: 5)
            beam.fillColor = Palette.heroRed.withAlphaComponent(0.85); beam.strokeColor = Palette.heroRed; beam.glowWidth = 6
            beam.position = p; beam.zPosition = ZLayer.fx
            // Later levels: beam stays on longer and the safe gap shrinks.
            let onTime = 1.1 + Double(levelIndex) * 0.04
            let offTime = max(0.5, 0.9 - Double(levelIndex) * 0.035)
            beam.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.1), .wait(forDuration: onTime),
                                               .fadeAlpha(to: 0.06, duration: 0.1), .wait(forDuration: offTime)])))
            worldNode.addChild(beam); lasers.append(beam)
            // Cannon-bots bookend the beam — solid (not children of the blinking beam).
            for ex in [-110.0, 110.0] {
                let turret = CharacterFactory.makeLaserTurret(facingRight: ex < 0)
                turret.position = CGPoint(x: p.x + ex, y: p.y); turret.zPosition = ZLayer.fx + 0.2
                worldNode.addChild(turret)
            }
        }
        for p in level.hazardSpots {
            let t = CharacterFactory.makeStaticTrap(); t.position = p; t.zPosition = ZLayer.items
            worldNode.addChild(t); hazards.append(t)
        }
        if let kp = level.keycardPos {
            let k = CharacterFactory.makeKeycard(); k.position = kp; k.zPosition = ZLayer.items
            worldNode.addChild(k); keycardNode = k
        }
        for p in level.grappleAnchors {
            let a = CharacterFactory.makeGrappleAnchor(accent: biome.accent)
            a.position = p; a.zPosition = ZLayer.coverTops + 0.5
            worldNode.addChild(a); grappleAnchorNodes.append(a)
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
            c.removeFromParent(); coins += 1; Economy.addCoins(1); hud.updateCoins(Economy.coins)
            blip(c.position, "★", Palette.energy); SoundFX.shared.play("coin")
        }
        if let k = keycardNode, k.parent != nil, k.position.distance(to: pp) < 42 {
            k.removeFromParent(); hasKeycard = true
            hud.showToast("Keycard! The exit is unlocked.", color: Palette.energy)
            exitPortal?.run(.fadeIn(withDuration: 0.3)); SoundFX.shared.play("powerup")
        }
        for m in magnetNodes where m.parent != nil && m.position.distance(to: pp) < 40 {
            m.removeFromParent(); magnetTimer = 6; hud.showToast("Crystal Magnet! 🧲", color: Palette.crystal); SoundFX.shared.play("powerup")
        }
        for s in starNodes where s.parent != nil && s.position.distance(to: pp) < 40 {
            s.removeFromParent(); starTimer = 6; player.setStar(true); hud.showToast("Super Star — invincible!", color: Palette.energy); SoundFX.shared.play("powerup")
        }
        if magnetTimer > 0 && objective == .collect && player.inCostume {
            for c in crystalNodes where c.parent != nil && c.position.distance(to: pp) < 200 {
                let d = CGVector(dx: pp.x - c.position.x, dy: pp.y - c.position.y)
                let len = max(hypot(d.dx, d.dy), 1)
                c.position.x += d.dx/len * 320 * CGFloat(dt); c.position.y += d.dy/len * 320 * CGFloat(dt)
            }
        }
        for pad in speedPads where pad.position.distance(to: pp) < 40 { speedTimer = 1.3 }
        if starTimer <= 0 && !player.isShielded && !grappling {
            for beam in lasers where beam.alpha > 0.5
                && abs(beam.position.x - pp.x) < 110 && abs(beam.position.y - pp.y) < 16 {
                handleCaught(); break
            }
            // Electric traps cost a life on contact.
            for t in hazards where t.position.distance(to: pp) < 28 {
                hud.showToast("Zapped by a trap! ⚡", color: Palette.heroRed); handleCaught(); break
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
        SoundFX.shared.play("crash"); shake(11, 0.3)
        let flash = SKSpriteNode(color: SKColor(red:1,green:0.3,blue:0.2,alpha:0.35), size: CGSize(width: 6000, height: 6000))
        flash.zPosition = ZLayer.overlay - 1; cam.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        lives = max(0, lives - 1)
        hud.setLives(lives, max: maxLives)
        if lives <= 0 {
            hud.showToast("Out of lives! Restarting level…", color: Palette.heroRed)
            run(.sequence([.wait(forDuration: 1.1),
                           .run { [weak self] in guard let self else { return }; self.loadLevel(self.levelIndex) }]),
                withKey: "levelRestart")
        } else {
            hud.showToast("CRASH! 💔 \(lives) left", color: Palette.heroRed)
        }
    }

    private func applyControlMode() {
        if level.isDriving {
            shieldBtn.isHidden = true; disguiseBtn.isHidden = true; interactBtn.isHidden = true
            grappleBtn.isHidden = true
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

    private func addMuteButton(to overlay: SKNode) {
        let b = SKNode(); b.name = "muteButton"; b.zPosition = 50
        b.position = CGPoint(x: size.width/2 - 40, y: size.height/2 - safeTop - 30)
        let circ = SKShapeNode(circleOfRadius: 22)
        circ.fillColor = Palette.hudPanel; circ.strokeColor = Palette.hudAccent; circ.lineWidth = 1.5; b.addChild(circ)
        let icon = SKLabelNode(text: SoundFX.shared.muted ? "🔇" : "🔊")
        icon.name = "muteIcon"; icon.fontSize = 22; icon.verticalAlignmentMode = .center; b.addChild(icon)
        overlay.addChild(b)
    }

    private func toggleMute(in overlay: SKNode?) {
        let muted = SoundFX.shared.toggleMute()
        (overlay?.childNode(withName: "//muteIcon") as? SKLabelNode)?.text = muted ? "🔇" : "🔊"
        if !muted { SoundFX.shared.play("tap") }
    }

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
        SoundFX.shared.playMusic("menu")
        let overlay = SKNode()
        overlay.name = "titleOverlay"; overlay.zPosition = ZLayer.overlay

        let bg = SKSpriteNode(color: SKColor(red: 0.10, green: 0.13, blue: 0.22, alpha: 1), size: CGSize(width: 4000, height: 4000))
        overlay.addChild(bg)
        // soft sky particles
        if let stars = Effects.ambient(.sparks, screen: size) {
            stars.particleColor = SKColor(red: 0.5, green: 0.8, blue: 1, alpha: 1)
            stars.particleBirthRate = 6; overlay.addChild(stars)
        }

        let card = roundedRect(size: CGSize(width: min(size.width - 40, 460), height: 400), corner: 24, color: Palette.hudPanel)
        card.strokeColor = Palette.hudAccent; card.lineWidth = 2
        card.position = CGPoint(x: 0, y: 10); overlay.addChild(card)

        let title = SKLabelNode(text: "KAIDITYA")
        title.fontName = "AvenirNext-Heavy"; title.fontSize = 56; title.fontColor = Palette.energy
        title.position = CGPoint(x: 0, y: 130); card.addChild(title)
        let sub = SKLabelNode(text: "Pint-Sized Hero, Big-Time Save")
        sub.fontName = "AvenirNext-Medium"; sub.fontSize = 17; sub.fontColor = .white
        sub.position = CGPoint(x: 0, y: 90); card.addChild(sub)

        let hero = CharacterFactory.makeHero()
        hero.setScale(1.2); hero.position = CGPoint(x: 0, y: -20)
        hero.run(.repeatForever(.sequence([.moveBy(x:0,y:9,duration:0.5), .moveBy(x:0,y:-9,duration:0.5)])))
        card.addChild(hero)

        let play = roundedRect(size: CGSize(width: 220, height: 56), corner: 14, color: Palette.heroBlue)
        play.strokeColor = .white; play.lineWidth = 2
        play.position = CGPoint(x: 0, y: -150); play.name = "playButton"
        play.run(.repeatForever(.sequence([.scale(to: 1.04, duration: 0.7), .scale(to: 1.0, duration: 0.7)])))
        let playLabel = SKLabelNode(text: "▶  PLAY")
        playLabel.fontName = "AvenirNext-Heavy"; playLabel.fontSize = 23; playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center; play.addChild(playLabel)
        card.addChild(play)

        dramatize(card, in: overlay, accent: Palette.energy)
        addMuteButton(to: overlay)
        cam.addChild(overlay)
        positionOverlay(overlay)
    }

    private func showMap() {
        state = .map
        setControlsHidden(true)
        SoundFX.shared.playMusic("menu")
        cam.childNode(withName: "mapOverlay")?.removeFromParent()
        let overlay = SKNode(); overlay.name = "mapOverlay"; overlay.zPosition = ZLayer.overlay
        let bg = SKSpriteNode(color: SKColor(red: 0.09, green: 0.11, blue: 0.20, alpha: 1), size: CGSize(width: 4000, height: 4000))
        overlay.addChild(bg)
        if let stars = Effects.ambient(.sparks, screen: size) {
            stars.particleColor = SKColor(red: 0.5, green: 0.8, blue: 1, alpha: 1); stars.particleBirthRate = 5
            overlay.addChild(stars)
        }
        let title = SKLabelNode(text: "SELECT A ZONE")
        title.fontName = "AvenirNext-Heavy"; title.fontSize = 30; title.fontColor = Palette.energy
        title.position = CGPoint(x: 0, y: size.height/2 - safeTop - 60); overlay.addChild(title)

        // Stats button (top-left, mirrors the mute button).
        let stats = SKNode(); stats.name = "statsButton"; stats.zPosition = 50
        stats.position = CGPoint(x: -size.width/2 + 40, y: size.height/2 - safeTop - 30)
        let sc = SKShapeNode(circleOfRadius: 22); sc.fillColor = Palette.hudPanel; sc.strokeColor = Palette.hudAccent; sc.lineWidth = 1.5
        stats.addChild(sc)
        let si = SKLabelNode(text: "📊"); si.fontSize = 20; si.verticalAlignmentMode = .center; stats.addChild(si)
        overlay.addChild(stats)

        // Serpentine layout of the 9 zones.
        let cols = 3
        let colX: [CGFloat] = [-110, 0, 110]
        let rowGap: CGFloat = 150
        let topY = size.height/2 - safeTop - 150
        var positions: [CGPoint] = []
        for i in 0..<Levels.all.count {
            let row = i / cols
            var col = i % cols
            if row % 2 == 1 { col = cols - 1 - col }   // serpentine
            positions.append(CGPoint(x: colX[col], y: topY - CGFloat(row) * rowGap))
        }
        // Connecting path lines.
        let path = CGMutablePath()
        path.move(to: positions[0])
        for p in positions.dropFirst() { path.addLine(to: p) }
        let line = SKShapeNode(path: path)
        line.strokeColor = SKColor(white: 1, alpha: 0.18); line.lineWidth = 5; line.lineCap = .round
        line.zPosition = 0; overlay.addChild(line)

        for (i, lvl) in Levels.all.enumerated() {
            let unlocked = i <= maxUnlocked
            let node = SKNode(); node.position = positions[i]; node.name = "mapnode_\(i)"; node.zPosition = 1
            let circle = SKShapeNode(circleOfRadius: 30)
            circle.fillColor = unlocked ? lvl.biome.accent.withAlphaComponent(0.92) : SKColor(white: 0.25, alpha: 0.9)
            circle.strokeColor = unlocked ? .white : SKColor(white: 0.45, alpha: 1); circle.lineWidth = 3
            if unlocked { circle.glowWidth = 3 }
            node.addChild(circle)
            let num = SKLabelNode(text: unlocked ? "\(lvl.index)" : "🔒")
            num.fontName = "AvenirNext-Heavy"; num.fontSize = unlocked ? 22 : 18
            num.fontColor = unlocked ? .white : SKColor(white: 0.6, alpha: 1)
            num.verticalAlignmentMode = .center; node.addChild(num)
            let name = SKLabelNode(text: lvl.name)
            name.fontName = "AvenirNext-Bold"; name.fontSize = 10
            name.fontColor = unlocked ? .white : SKColor(white: 0.5, alpha: 1)
            name.verticalAlignmentMode = .center; name.position = CGPoint(x: 0, y: -44)
            name.numberOfLines = 2; name.preferredMaxLayoutWidth = 100; node.addChild(name)
            if i == maxUnlocked && maxUnlocked < Levels.all.count {
                circle.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.5), .scale(to: 1.0, duration: 0.5)])))
            }
            overlay.addChild(node)
        }
        let hint = SKLabelNode(text: "tap a zone to play")
        hint.fontName = "AvenirNext-Medium"; hint.fontSize = 13; hint.fontColor = Palette.hudAccent
        hint.position = CGPoint(x: 0, y: -size.height/2 + safeBottom + 70); overlay.addChild(hint)
        addMuteButton(to: overlay)

        // SHOP button
        let shop = roundedRect(size: CGSize(width: 180, height: 44), corner: 14, color: Palette.energy.darker)
        shop.strokeColor = .white; shop.lineWidth = 2; shop.name = "shopButton"
        shop.position = CGPoint(x: 0, y: -size.height/2 + safeBottom + 30)
        let shopLbl = SKLabelNode(text: "🛒  SHOP  ·  \(Economy.coins)★")
        shopLbl.fontName = "AvenirNext-Heavy"; shopLbl.fontSize = 16; shopLbl.fontColor = .white
        shopLbl.verticalAlignmentMode = .center; shop.addChild(shopLbl)
        shop.position = CGPoint(x: -98, y: -size.height/2 + safeBottom + 30)
        overlay.addChild(shop)

        let home = roundedRect(size: CGSize(width: 150, height: 44), corner: 14, color: Palette.heroBlue)
        home.strokeColor = .white; home.lineWidth = 2; home.name = "homeButton"
        home.position = CGPoint(x: 96, y: -size.height/2 + safeBottom + 30)
        let homeLbl = SKLabelNode(text: "🏠  CITY"); homeLbl.fontName = "AvenirNext-Heavy"; homeLbl.fontSize = 16
        homeLbl.fontColor = .white; homeLbl.verticalAlignmentMode = .center; home.addChild(homeLbl)
        overlay.addChild(home)

        cam.addChild(overlay)
        positionOverlay(overlay)
    }

    private func showShop() {
        state = .shop
        ["shopOverlay", "titleOverlay", "mapOverlay"].forEach { cam.childNode(withName: $0)?.removeFromParent() }
        let overlay = SKNode(); overlay.name = "shopOverlay"; overlay.zPosition = ZLayer.overlay
        let bg = SKSpriteNode(color: SKColor(red: 0.09, green: 0.11, blue: 0.20, alpha: 1), size: CGSize(width: 4000, height: 4000))
        overlay.addChild(bg)
        let title = SKLabelNode(text: "GADGET SHOP")
        title.fontName = "AvenirNext-Heavy"; title.fontSize = 30; title.fontColor = Palette.energy
        title.position = CGPoint(x: 0, y: size.height/2 - safeTop - 60); overlay.addChild(title)
        let purse = SKLabelNode(text: "Coins: \(Economy.coins) ★")
        purse.fontName = "AvenirNext-Bold"; purse.fontSize = 17; purse.fontColor = .white
        purse.position = CGPoint(x: 0, y: size.height/2 - safeTop - 96); overlay.addChild(purse)

        let rowW = min(size.width - 40, 460), rowH: CGFloat = 78
        var y = size.height * 0.18
        for u in Upgrade.allCases {
            let owned = Economy.owned(u)
            let afford = Economy.coins >= u.price
            let row = roundedRect(size: CGSize(width: rowW, height: rowH), corner: 14, color: Palette.hudPanel)
            row.strokeColor = owned ? Palette.crystal : (afford ? Palette.energy : SKColor(white: 0.4, alpha: 1))
            row.lineWidth = 2; row.position = CGPoint(x: 0, y: y); row.name = "shoprow_\(u.rawValue)"
            let g = SKLabelNode(text: u.glyph); g.fontSize = 30; g.verticalAlignmentMode = .center
            g.position = CGPoint(x: -rowW/2 + 34, y: 0); row.addChild(g)
            let t = SKLabelNode(text: u.title); t.fontName = "AvenirNext-Heavy"; t.fontSize = 17; t.fontColor = .white
            t.horizontalAlignmentMode = .left; t.position = CGPoint(x: -rowW/2 + 62, y: 12); row.addChild(t)
            let d = SKLabelNode(text: u.desc); d.fontName = "AvenirNext-Regular"; d.fontSize = 12; d.fontColor = SKColor(white: 0.8, alpha: 1)
            d.horizontalAlignmentMode = .left; d.position = CGPoint(x: -rowW/2 + 62, y: -12); row.addChild(d)
            let price = SKLabelNode(text: owned ? "OWNED ✓" : "\(u.price) ★")
            price.fontName = "AvenirNext-Heavy"; price.fontSize = 16
            price.fontColor = owned ? Palette.crystal : (afford ? Palette.energy : SKColor(white: 0.55, alpha: 1))
            price.horizontalAlignmentMode = .right; price.position = CGPoint(x: rowW/2 - 20, y: 0); row.addChild(price)
            overlay.addChild(row)
            y -= rowH + 12
        }

        // Costume picker.
        let costLbl = SKLabelNode(text: "COSTUMES"); costLbl.fontName = "AvenirNext-Heavy"; costLbl.fontSize = 14
        costLbl.fontColor = Palette.hudAccent; costLbl.position = CGPoint(x: 0, y: y - 6); overlay.addChild(costLbl)
        let all = Costume.allCases
        let sw: CGFloat = 50, gap: CGFloat = 12
        let totalW = CGFloat(all.count) * sw + CGFloat(all.count - 1) * gap
        var cx = -totalW/2 + sw/2
        for c in all {
            let node = SKNode(); node.position = CGPoint(x: cx, y: y - 56); node.name = "cosrow_\(c.rawValue)"
            let body = roundedRect(size: CGSize(width: sw, height: sw), corner: 10, color: c.suit)
            let equipped = Economy.equippedCostume == c
            let owned = Economy.ownedCostume(c)
            body.strokeColor = equipped ? Palette.energy : (owned ? .white : SKColor(white: 0.45, alpha: 1))
            body.lineWidth = equipped ? 3.5 : 2
            node.addChild(body)
            let capeChip = roundedRect(size: CGSize(width: 14, height: 22), corner: 3, color: c.cape)
            capeChip.position = CGPoint(x: 14, y: -4); node.addChild(capeChip)
            let tag = SKLabelNode(text: equipped ? "✓" : (owned ? c.name : "\(c.price)★"))
            tag.fontName = "AvenirNext-Bold"; tag.fontSize = equipped ? 16 : 9
            tag.fontColor = equipped ? Palette.energy : .white; tag.verticalAlignmentMode = .center
            tag.position = CGPoint(x: 0, y: -sw/2 - 9); node.addChild(tag)
            overlay.addChild(node)
            cx += sw + gap
        }

        let back = roundedRect(size: CGSize(width: 160, height: 44), corner: 14, color: Palette.heroBlue)
        back.strokeColor = .white; back.lineWidth = 2; back.name = "shopBack"
        back.position = CGPoint(x: 0, y: -size.height/2 + safeBottom + 34)
        let bl = SKLabelNode(text: "◂ BACK"); bl.fontName = "AvenirNext-Heavy"; bl.fontSize = 16; bl.fontColor = .white
        bl.verticalAlignmentMode = .center; back.addChild(bl); overlay.addChild(back)
        cam.addChild(overlay); positionOverlay(overlay)
    }

    private func exitShop() {
        cam.childNode(withName: "shopOverlay")?.removeFromParent()
        if shopFromHub { shopFromHub = false; enterHub() } else { showMap() }
    }

    private func handleShopTap(_ camP: CGPoint) {
        guard let overlay = cam.childNode(withName: "shopOverlay") else { return }
        if let back = overlay.childNode(withName: "shopBack"), back.contains(camP) {
            exitShop(); return
        }
        for u in Upgrade.allCases {
            if let row = overlay.childNode(withName: "shoprow_\(u.rawValue)"), row.contains(camP) {
                if Economy.buy(u) { SoundFX.shared.play("powerup"); showShop() }   // refresh
                else { SoundFX.shared.play("caught") }
                return
            }
        }
        for c in Costume.allCases {
            if let node = overlay.childNode(withName: "cosrow_\(c.rawValue)"),
               node.contains(cam.convert(camP, to: node.parent!)) {
                if Economy.selectCostume(c) { SoundFX.shared.play("powerup"); showShop() }
                else { SoundFX.shared.play("caught") }
                return
            }
        }
    }

    private func showStats() {
        guard let mapOverlay = cam.childNode(withName: "mapOverlay") else { return }
        mapOverlay.childNode(withName: "statsCard")?.removeFromParent()
        let panel = SKNode(); panel.name = "statsCard"; panel.zPosition = 60
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.78), size: CGSize(width: 4000, height: 4000))
        panel.addChild(dim)
        let card = roundedRect(size: CGSize(width: min(size.width - 60, 380), height: 320), corner: 20, color: Palette.hudPanel)
        card.strokeColor = Palette.hudAccent; card.lineWidth = 2.5; panel.addChild(card)
        let title = SKLabelNode(text: "HERO STATS"); title.fontName = "AvenirNext-Heavy"; title.fontSize = 26
        title.fontColor = Palette.energy; title.position = CGPoint(x: 0, y: 122); card.addChild(title)
        let zonesReached = min(UserDefaults.standard.integer(forKey: "kaiditya.maxUnlocked") + 1, Levels.all.count)
        let rows: [(String, String)] = [
            ("🪙  Coins earned", "\(Economy.coinsEarned)"),
            ("💰  Coins now", "\(Economy.coins)"),
            ("🗺  Zones reached", "\(zonesReached) / \(Levels.all.count)"),
            ("🎯  Best arcade", "\(Economy.bestCatch)"),
            ("🥸  Costumes", "\(Economy.costumesOwned) / \(Costume.allCases.count)"),
            ("🔥  Daily streak", "\(Economy.dailyStreak)")
        ]
        var y: CGFloat = 78
        for (label, value) in rows {
            let l = SKLabelNode(text: label); l.fontName = "AvenirNext-Medium"; l.fontSize = 16; l.fontColor = .white
            l.horizontalAlignmentMode = .left; l.position = CGPoint(x: -150, y: y); card.addChild(l)
            let v = SKLabelNode(text: value); v.fontName = "AvenirNext-Heavy"; v.fontSize = 16; v.fontColor = Palette.crystal
            v.horizontalAlignmentMode = .right; v.position = CGPoint(x: 150, y: y); card.addChild(v)
            y -= 34
        }
        let go = SKLabelNode(text: "tap to close ▸"); go.fontName = "AvenirNext-Bold"; go.fontSize = 13; go.fontColor = Palette.hudAccent
        go.position = CGPoint(x: 0, y: -132); card.addChild(go)
        dramatize(card, in: panel, accent: Palette.hudAccent, rays: false)
        mapOverlay.addChild(panel)
        SoundFX.shared.play("tap")
    }

    private func handleMapTap(_ camP: CGPoint) {
        // If the stats card is up, any tap closes it.
        if let mapOverlay = cam.childNode(withName: "mapOverlay"), let stats = mapOverlay.childNode(withName: "statsCard") {
            stats.removeFromParent(); return
        }
        if let overlay = cam.childNode(withName: "mapOverlay"),
           let sb = overlay.childNode(withName: "statsButton"), sb.contains(cam.convert(camP, to: overlay)) {
            showStats(); return
        }
        if let overlay = cam.childNode(withName: "mapOverlay"),
           let mb = overlay.childNode(withName: "muteButton"), mb.contains(cam.convert(camP, to: overlay)) {
            toggleMute(in: overlay); return
        }
        if let shop = cam.childNode(withName: "//shopButton"), shop.contains(cam.convert(camP, to: shop.parent!)) {
            cam.childNode(withName: "mapOverlay")?.removeFromParent(); shopFromHub = false; showShop(); return
        }
        if let home = cam.childNode(withName: "//homeButton"), home.contains(cam.convert(camP, to: home.parent!)) {
            cam.childNode(withName: "mapOverlay")?.removeFromParent(); enterHub(); return
        }
        for i in 0..<Levels.all.count where i <= maxUnlocked {
            if let node = cam.childNode(withName: "//mapnode_\(i)"),
               node.contains(cam.convert(camP, to: node.parent!)) {
                cam.childNode(withName: "mapOverlay")?.removeFromParent()
                loadLevel(i); return
            }
        }
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
        // First-time tour on level 1.
        if levelIndex == 0, !demoMode, !UserDefaults.standard.bool(forKey: "kaiditya.tourSeen") {
            UserDefaults.standard.set(true, forKey: "kaiditya.tourSeen")
            tourStep = 0
            showTour()
            return
        }
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

    // MARK: - Start tour

    private func tourSteps() -> [(text: String, target: CGPoint?)] {
        [
            ("Welcome, Kaiditya! Touch the LEFT side of the screen and drag to MOVE.", moveHint?.position),
            ("Tap HIDE to disguise as an ordinary kid — the minions won't recognize you.", disguiseBtn.position),
            ("Tap HERO to suit up again so you can grab crystals and take on bad guys.", disguiseBtn.position),
            ("DASH zooms you forward. SHIELD makes you invincible for a moment.", dashBtn.position),
            ("When you see a GRAPPLE point, tap it to zip across gaps and water!", grappleBtn.position),
            ("Sneak past the glowing vision cones, hide in bushes, and collect the Energy Crystals. Now go save the world!", nil)
        ]
    }

    private func showTour() {
        state = .tour
        cam.childNode(withName: "tourOverlay")?.removeFromParent()
        let steps = tourSteps()
        let step = steps[min(tourStep, steps.count - 1)]

        let overlay = SKNode(); overlay.name = "tourOverlay"; overlay.zPosition = ZLayer.overlay
        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.62), size: CGSize(width: 5000, height: 5000))
        overlay.addChild(dim)

        // Highlight ring around the target control.
        if let target = step.target {
            let ring = SKShapeNode(circleOfRadius: 54)
            ring.strokeColor = Palette.energy; ring.lineWidth = 4; ring.fillColor = .clear; ring.glowWidth = 4
            ring.position = target; ring.zPosition = 1
            ring.run(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.5), .scale(to: 1.0, duration: 0.5)])))
            overlay.addChild(ring)
        }

        // Text card (kept away from bottom controls).
        let cardW = min(size.width - 48, 460)
        let card = roundedRect(size: CGSize(width: cardW, height: 150), corner: 18, color: Palette.hudPanel)
        card.strokeColor = Palette.hudAccent; card.lineWidth = 2
        card.position = CGPoint(x: 0, y: size.height * 0.16)
        overlay.addChild(card)
        let eyebrow = SKLabelNode(text: "TIP \(tourStep + 1)/\(steps.count)")
        eyebrow.fontName = "AvenirNext-Heavy"; eyebrow.fontSize = 12; eyebrow.fontColor = Palette.hudAccent
        eyebrow.position = CGPoint(x: 0, y: 50); card.addChild(eyebrow)
        let body = SKLabelNode(text: step.text)
        body.fontName = "AvenirNext-Medium"; body.fontSize = 16; body.fontColor = .white
        body.numberOfLines = 4; body.preferredMaxLayoutWidth = cardW - 40
        body.verticalAlignmentMode = .center; body.horizontalAlignmentMode = .center
        body.position = CGPoint(x: 0, y: 2); card.addChild(body)
        let go = SKLabelNode(text: tourStep < steps.count - 1 ? "tap to continue ▸" : "tap to play ▸")
        go.fontName = "AvenirNext-Bold"; go.fontSize = 13; go.fontColor = Palette.energy
        go.position = CGPoint(x: 0, y: -56); card.addChild(go)
        go.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])))

        dramatize(card, in: overlay, accent: Palette.hudAccent, rays: false)
        cam.addChild(overlay)
        positionOverlay(overlay)
        SoundFX.shared.play("tap")
    }

    private func advanceTour() {
        tourStep += 1
        if tourStep >= tourSteps().count {
            cam.childNode(withName: "tourOverlay")?.removeFromParent()
            state = .playing
            hud.showToast("Find the crystals — and watch the minions!", color: biome.accent)
        } else {
            showTour()
        }
    }

    private func showLevelComplete() {
        state = .complete
        setControlsHidden(true)
        SoundFX.shared.play("clear")
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
        SoundFX.shared.stopMusic()
        SoundFX.shared.play("win")
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
            case .title:
                if let overlay = cam.childNode(withName: "titleOverlay"),
                   let mb = overlay.childNode(withName: "muteButton"), mb.contains(cam.convert(camP, to: overlay)) {
                    toggleMute(in: overlay)
                } else { startGame() }
                return
            case .map:      handleMapTap(camP); return
            case .shop:     handleShopTap(camP); return
            case .intro:    dismissIntro(); return
            case .tour:     advanceTour(); return
            case .dialogue: advanceDialogue(); return
            case .complete: cam.childNode(withName: "completeOverlay")?.removeFromParent(); loadLevel(levelIndex + 1); return
            case .won:      cam.childNode(withName: "winOverlay")?.removeFromParent(); showMap(); return
            case .minigame:
                if mgOver { closeMinigame() }
                else if let quit = mgLayer.childNode(withName: "mgQuit"), quit.contains(camP) {
                    SoundFX.shared.play("tap"); endMinigame()
                } else if !joystick.isActive { joystick.begin(at: camP, touch: t) }
                return
            case .playing:  break
            }
            if !interactBtn.isHidden, interactBtn.enabled, interactBtn.contains(scenePoint: p, in: self) {
                interactBtn.press(); buttonTouches[ObjectIdentifier(t)] = interactBtn; nearestInteract?(); continue
            }
            if dashBtn.contains(scenePoint: p, in: self) {
                dashBtn.press(); buttonTouches[ObjectIdentifier(t)] = dashBtn
                if player.tryDash() { SoundFX.shared.play("dash") } else { hud.showToast("Need power!", color: Palette.heroRed) }; continue
            }
            if shieldBtn.contains(scenePoint: p, in: self) {
                shieldBtn.press(); buttonTouches[ObjectIdentifier(t)] = shieldBtn
                if player.tryShield() { hud.showToast("Shield up!", color: Palette.hudAccent); SoundFX.shared.play("shield") }
                else { hud.showToast("Need power!", color: Palette.heroRed) }; continue
            }
            if disguiseBtn.contains(scenePoint: p, in: self) {
                disguiseBtn.press(); buttonTouches[ObjectIdentifier(t)] = disguiseBtn; toggleDisguise(); continue
            }
            if !grappleBtn.isHidden, grappleBtn.contains(scenePoint: p, in: self) {
                grappleBtn.press(); buttonTouches[ObjectIdentifier(t)] = grappleBtn; grapple(); continue
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
        case .map: cam.childNode(withName: "mapOverlay")?.removeFromParent(); loadLevel(min(maxUnlocked, Levels.all.count - 1)); return
        case .shop: exitShop(); return
        case .intro: dismissIntro(); return
        case .tour: advanceTour(); return
        case .complete: cam.childNode(withName: "completeOverlay")?.removeFromParent(); loadLevel(levelIndex + 1); return
        case .dialogue:
            if code == .keyboardSpacebar || code == .keyboardReturnOrEnter || code == .keyboardJ { advanceDialogue() }
            return
        case .won: cam.childNode(withName: "winOverlay")?.removeFromParent(); showMap(); return
        case .minigame: if mgOver { closeMinigame() } else { pressedKeys.insert(code) }; return
        case .playing: break
        }
        switch code {
        case .keyboardSpacebar, .keyboardReturnOrEnter, .keyboardJ: nearestInteract?()
        case .keyboardK: if player.tryDash() { SoundFX.shared.play("dash") } else { hud.showToast("Need power!", color: Palette.heroRed) }
        case .keyboardL:
            if player.tryShield() { hud.showToast("Shield up!", color: Palette.hudAccent); SoundFX.shared.play("shield") }
            else { hud.showToast("Need power!", color: Palette.heroRed) }
        case .keyboardH: toggleDisguise()
        case .keyboardG: grapple()
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
        if demoMode {
            let start = Int(ProcessInfo.processInfo.environment["KAIDITYA_START_LEVEL"] ?? "") ?? 0
            loadLevel(min(max(start, 0), Levels.all.count - 1))
        } else {
            enterHub()
        }
    }

    // MARK: - Hub town

    private func enterHub() {
        inHub = true
        level = Levels.hub
        levelIndex = -1
        removeAction(forKey: "bossLoop"); removeAllActions()
        worldNode.removeAllActions(); worldNode.removeFromParent()
        worldNode = SKNode(); addChild(worldNode)
        npcs = []; minions = []; crystalNodes = []; coverRects = []
        exitPortal = nil; powerCore = nil; villain = nil
        grappleAnchorNodes = []; grappleTarget = nil; grappling = false
        shopDoor = nil; arcadeDoor = nil; missionsPortal = nil; petNode = nil
        coinNodes = []; questActive = false; questDone = false; questProgress = 0
        deliverActive = false; deliverDone = false
        carriedItem?.removeFromParent(); carriedItem = nil
        objective = .done
        player.removeFromParent(); player.resetForLevel()
        player.position = level.heroSpawn
        worldNode.addChild(player)
        disguiseBtn.setTitle("HIDE")

        backgroundColor = biome.groundB
        buildHubWorld()
        setupAtmosphere()
        startDayNight()
        cam.position = clampedCamera(player.position)
        hud.updateObjective(level: "HERO CITY", title: "Welcome home, hero!",
                            hint: "Tap MISSIONS to play · explore the town!", progress: "")
        hud.updateCrystals(0); hud.setCrystalsHidden(true)
        hud.updateCoins(Economy.coins); hud.updateEnergy(1); hud.hideBossBar()
        hud.setLives(0, max: 0)   // no lives shown in the safe hub
        setControlsHidden(false); applyControlMode()
        refreshQuestMarkers()
        state = .playing
        SoundFX.shared.playMusic("explore")
        hud.showToast("Welcome to Hero City! 🦸", color: biome.accent)
    }

    private func buildHubWorld() {
        buildGround()
        buildHubDecor()
        for s in level.signs { addSign(text: s.text, at: s.pos) }
        for t in level.treeSpots { addTree(at: t) }
        // Buildings with glowing doors.
        addHubBuilding(label: "HQ", at: CGPoint(x: 950, y: 1280), roof: Palette.heroBlue, door: nil)
        let shop = CGPoint(x: 520, y: 1050)
        addHubBuilding(label: "SHOP", at: CGPoint(x: 520, y: 1180), roof: Palette.energy.darker, door: shop)
        shopDoor = shop
        let arcade = CGPoint(x: 1380, y: 1050)
        addHubBuilding(label: "ARCADE", at: CGPoint(x: 1380, y: 1180), roof: Palette.heroRed, door: arcade)
        arcadeDoor = arcade
        for n in level.npcs { addNPCSpec(n) }
        // Wandering townsfolk for life.
        for npc in npcs where npc.id != "tommy" {
            let dx = CGFloat([60, -70, 80].randomishPick(npc.position.x))
            npc.run(.repeatForever(.sequence([
                .moveBy(x: dx, y: 0, duration: 2.2), .wait(forDuration: 0.6),
                .moveBy(x: -dx, y: 0, duration: 2.2), .wait(forDuration: 0.6)
            ])))
        }
        // Coins scattered around town.
        for p in level.coinSpots {
            let c = CharacterFactory.makeCoin(); c.position = p; c.zPosition = ZLayer.items
            c.run(.repeatForever(.sequence([.scaleX(to: 0.3, duration: 0.4), .scaleX(to: 1, duration: 0.4)])))
            worldNode.addChild(c); coinNodes.append(c)
        }
        // Daily bonus chest.
        let chest = CharacterFactory.makeChest(glowing: Economy.canClaimDaily)
        chest.position = chestPos; chest.zPosition = ZLayer.items
        worldNode.addChild(chest); chestNode = chest
        let chestTag = SKLabelNode(text: "DAILY"); chestTag.fontName = "AvenirNext-Heavy"; chestTag.fontSize = 11
        chestTag.fontColor = Palette.energy; chestTag.position = CGPoint(x: 0, y: -34); chest.addChild(chestTag)
        // Biscuit the puppy — wanders the plaza, pettable.
        addPuppy(at: CGPoint(x: 1080, y: 980))
        // Missions portal.
        let portal = Effects.portal(accent: biome.accent, label: "MISSIONS")
        portal.position = level.exitPos; portal.zPosition = ZLayer.items
        portal.alpha = 1
        worldNode.addChild(portal); missionsPortal = portal
        let border = SKShapeNode(rect: CGRect(origin: .zero, size: worldSize))
        border.strokeColor = biome.borderColor; border.lineWidth = 10; border.zPosition = ZLayer.decals
        worldNode.addChild(border)
    }

    private func buildHubDecor() {
        // A plaza path under the town center.
        let plaza = SKShapeNode(circleOfRadius: 380)
        plaza.fillColor = biome.pathColor.withAlphaComponent(0.5); plaza.strokeColor = .clear
        plaza.position = CGPoint(x: 950, y: 850); plaza.zPosition = ZLayer.pathDeco
        worldNode.addChild(plaza)

        addFountain(at: fountainPos)
        for p in [CGPoint(x: 300, y: 520), CGPoint(x: 1600, y: 520),
                  CGPoint(x: 300, y: 1150), CGPoint(x: 1600, y: 1150)] { addLamp(at: p) }
        for p in [CGPoint(x: 790, y: 600), CGPoint(x: 1110, y: 600)] { addBench(at: p) }
        addBalloons(at: CGPoint(x: 1110, y: 720))
        addBalloons(at: CGPoint(x: 800, y: 720))
        for p in [CGPoint(x: 740, y: 800), CGPoint(x: 1170, y: 820), CGPoint(x: 690, y: 1010),
                  CGPoint(x: 1210, y: 1000), CGPoint(x: 880, y: 640), CGPoint(x: 1050, y: 1130),
                  CGPoint(x: 430, y: 760), CGPoint(x: 1500, y: 760)] {
            addFlowerPatch(at: p)
        }

        // A few decorative townsfolk going about their day (non-interactive).
        let tints: [SKColor] = [SKColor(red:0.9,green:0.7,blue:0.4,alpha:1),
                                SKColor(red:0.5,green:0.8,blue:0.7,alpha:1),
                                SKColor(red:0.85,green:0.5,blue:0.6,alpha:1)]
        for (i, p) in [CGPoint(x: 470, y: 920), CGPoint(x: 1430, y: 940), CGPoint(x: 1050, y: 470)].enumerated() {
            let person = CharacterFactory.makeNPC(tint: tints[i])
            person.position = p; person.zPosition = ZLayer.characters - 0.2
            let dx = CGFloat([70, -80, 60][i])
            person.run(.repeatForever(.sequence([.moveBy(x: dx, y: 0, duration: 2.4), .wait(forDuration: 0.5),
                                                 .moveBy(x: -dx, y: 0, duration: 2.4), .wait(forDuration: 0.5)])))
            worldNode.addChild(person)
        }

        // Ambient bird flocks drifting across the sky for a touch of life.
        worldNode.run(.repeatForever(.sequence([.wait(forDuration: 6), .run { [weak self] in self?.flyBirdFlock() }])),
                      withKey: "birds")
    }

    /// A small V of birds glides across the hub at a high z-layer, then despawns.
    private func flyBirdFlock() {
        let flock = SKNode(); flock.zPosition = ZLayer.fx + 2
        let leftToRight = (Int(player.position.x) % 2 == 0)
        let y = CGFloat(1000 + (Int(player.position.y) % 400))
        let startX: CGFloat = leftToRight ? -200 : 2100
        let endX: CGFloat = leftToRight ? 2100 : -200
        flock.position = CGPoint(x: startX, y: y)
        let n = 3 + (Int(player.position.x) % 3)
        for i in 0..<n {
            let bird = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -9, y: 5)); path.addLine(to: CGPoint(x: 0, y: 0)); path.addLine(to: CGPoint(x: 9, y: 5))
            bird.path = path
            bird.strokeColor = SKColor(white: 0.25, alpha: 0.85); bird.lineWidth = 2.5; bird.lineCap = .round
            bird.xScale = leftToRight ? 1 : -1
            let row = i / 2 + 1
            bird.position = CGPoint(x: CGFloat((i % 2 == 0 ? -1 : 1) * row) * 26, y: CGFloat(-row) * 16)
            // gentle wing flap
            bird.run(.repeatForever(.sequence([.scaleY(to: 0.6, duration: 0.25), .scaleY(to: 1.0, duration: 0.25)])))
            flock.addChild(bird)
        }
        worldNode.addChild(flock)
        flock.run(.sequence([.moveTo(x: endX, duration: 9), .removeFromParent()]))
    }

    private func addFountain(at p: CGPoint) {
        let basin = SKShapeNode(circleOfRadius: 70)
        basin.fillColor = SKColor(white: 0.75, alpha: 1); basin.strokeColor = SKColor(white: 0.55, alpha: 1); basin.lineWidth = 4
        basin.position = p; basin.zPosition = ZLayer.decals; worldNode.addChild(basin)
        let water = SKShapeNode(circleOfRadius: 54)
        water.fillColor = Palette.water; water.strokeColor = Palette.water.darker; water.lineWidth = 2
        water.position = p; water.zPosition = ZLayer.decals + 0.5; worldNode.addChild(water)
        let column = SKShapeNode(circleOfRadius: 14)
        column.fillColor = SKColor(white: 0.8, alpha: 1); column.strokeColor = SKColor(white: 0.6, alpha: 1)
        column.position = p; column.zPosition = ZLayer.decals + 0.6; worldNode.addChild(column)
        if let spray = Effects.ambient(.sparks, screen: CGSize(width: 60, height: 60)) {
            spray.particleColor = Palette.water.lighter; spray.particleBirthRate = 16; spray.particleLifetime = 1.0
            spray.particlePositionRange = CGVector(dx: 24, dy: 8); spray.emissionAngle = .pi/2; spray.emissionAngleRange = 0.5
            spray.particleSpeed = 70; spray.yAcceleration = -120
            spray.position = CGPoint(x: p.x, y: p.y + 6); spray.zPosition = ZLayer.fx; worldNode.addChild(spray)
        }
    }

    /// A small cluster of simple flowers in the grass — pure ground decor.
    private func addFlowerPatch(at p: CGPoint) {
        let petalColors: [SKColor] = [Palette.heroRed, Palette.energy, Palette.crystal,
                                      SKColor(red: 0.85, green: 0.45, blue: 0.7, alpha: 1)]
        let patch = SKNode(); patch.position = p; patch.zPosition = ZLayer.pathDeco + 0.5
        let spots: [CGPoint] = [CGPoint(x: -14, y: 6), CGPoint(x: 12, y: -4), CGPoint(x: 0, y: 14)]
        for (i, s) in spots.enumerated() {
            let flower = SKNode(); flower.position = s
            let petalC = petalColors[(Int(p.x) + i) % petalColors.count]
            for a in stride(from: 0.0, to: .pi * 2, by: .pi / 2.5) {   // 5 petals
                let petal = SKShapeNode(circleOfRadius: 3.2)
                petal.fillColor = petalC; petal.strokeColor = .clear
                petal.position = CGPoint(x: cos(a) * 4.2, y: sin(a) * 4.2); flower.addChild(petal)
            }
            let center = SKShapeNode(circleOfRadius: 2.2)
            center.fillColor = Palette.energy; center.strokeColor = .clear; flower.addChild(center)
            flower.setScale(0.0)
            flower.run(.sequence([.wait(forDuration: Double(i) * 0.12), .scale(to: 1.0, duration: 0.3)]))
            patch.addChild(flower)
        }
        worldNode.addChild(patch)
    }

    /// A cheerful bunch of balloons on strings that sway gently — pure ambient decor.
    private func addBalloons(at p: CGPoint) {
        let colors: [SKColor] = [Palette.heroRed, Palette.energy, Palette.crystal,
                                 SKColor(red: 0.55, green: 0.4, blue: 0.85, alpha: 1)]
        let bunch = SKNode(); bunch.position = p; bunch.zPosition = ZLayer.characters + 0.5
        let offsets: [CGPoint] = [CGPoint(x: -16, y: 96), CGPoint(x: 14, y: 104),
                                  CGPoint(x: -2, y: 116), CGPoint(x: 24, y: 88)]
        for (i, off) in offsets.enumerated() {
            let string = SKShapeNode()
            let sp = CGMutablePath(); sp.move(to: .zero); sp.addLine(to: off)
            string.path = sp; string.strokeColor = SKColor(white: 0.85, alpha: 0.5); string.lineWidth = 1
            bunch.addChild(string)
            let balloon = SKShapeNode(ellipseOf: CGSize(width: 26, height: 32))
            balloon.fillColor = colors[i]; balloon.strokeColor = colors[i].darker; balloon.lineWidth = 1.5
            balloon.position = off
            let hi = SKShapeNode(circleOfRadius: 4); hi.fillColor = SKColor(white: 1, alpha: 0.4)
            hi.strokeColor = .clear; hi.position = CGPoint(x: -6, y: 8); balloon.addChild(hi)
            bunch.addChild(balloon)
        }
        let sway = SKAction.sequence([.rotate(byAngle: 0.06, duration: 1.4), .rotate(byAngle: -0.06, duration: 1.4)])
        bunch.run(.repeatForever(sway))
        worldNode.addChild(bunch)
    }

    /// Biscuit: a small vector puppy that ambles around the plaza and can be petted.
    private func addPuppy(at p: CGPoint) {
        let dog = SKNode(); dog.position = p; dog.zPosition = ZLayer.characters - 0.1
        let fur = SKColor(red: 0.72, green: 0.52, blue: 0.32, alpha: 1)
        let body = roundedRect(size: CGSize(width: 30, height: 18), corner: 8, color: fur, stroke: fur.darker, lineWidth: 1.5)
        body.position = CGPoint(x: -3, y: 0); dog.addChild(body)
        let head = SKShapeNode(circleOfRadius: 10); head.fillColor = fur; head.strokeColor = fur.darker; head.lineWidth = 1.5
        head.position = CGPoint(x: 15, y: 5); dog.addChild(head)
        for ex in [12.0, 19.0] {  // eyes
            let eye = SKShapeNode(circleOfRadius: 1.6); eye.fillColor = .black; eye.strokeColor = .clear
            eye.position = CGPoint(x: ex, y: 7); dog.addChild(eye)
        }
        let ear = SKShapeNode(ellipseOf: CGSize(width: 6, height: 11)); ear.fillColor = fur.darker; ear.strokeColor = .clear
        ear.position = CGPoint(x: 10, y: 11); dog.addChild(ear)
        let tail = SKShapeNode(); let tp = CGMutablePath()
        tp.move(to: CGPoint(x: -18, y: 2)); tp.addLine(to: CGPoint(x: -26, y: 10))
        tail.path = tp; tail.strokeColor = fur.darker; tail.lineWidth = 3; tail.lineCap = .round
        tail.name = "tail"; dog.addChild(tail)
        // Wag the tail and amble back and forth.
        tail.run(.repeatForever(.sequence([.rotate(toAngle: 0.5, duration: 0.25, shortestUnitArc: true),
                                           .rotate(toAngle: -0.2, duration: 0.25, shortestUnitArc: true)])))
        dog.run(.repeatForever(.sequence([
            .moveBy(x: 90, y: 0, duration: 3.0), .wait(forDuration: 0.8),
            .scaleX(to: -1, duration: 0), .moveBy(x: -90, y: 0, duration: 3.0),
            .wait(forDuration: 0.8), .scaleX(to: 1, duration: 0)
        ])))
        worldNode.addChild(dog); petNode = dog
    }

    /// Pet Biscuit: happy hop, bark, and a burst of hearts.
    private func petDog() {
        guard let dog = petNode else { return }
        SoundFX.shared.play("collect")
        dog.removeAction(forKey: "hop")
        dog.run(.sequence([.moveBy(x: 0, y: 14, duration: 0.14), .moveBy(x: 0, y: -14, duration: 0.14)]), withKey: "hop")
        for i in 0..<5 {
            let heart = SKLabelNode(text: "❤️"); heart.fontSize = 16
            heart.position = CGPoint(x: dog.position.x + CGFloat(i * 6 - 12), y: dog.position.y + 18)
            heart.zPosition = ZLayer.fx + 3; worldNode.addChild(heart)
            heart.run(.sequence([.group([.moveBy(x: CGFloat(i * 4 - 8), y: 46, duration: 0.9),
                                         .fadeOut(withDuration: 0.9)]), .removeFromParent()]))
        }
        hud.showToast("Biscuit loves you! 🐶", color: Palette.heroRed)
    }

    private func addBench(at p: CGPoint) {
        let wood = SKColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1)
        let seat = roundedRect(size: CGSize(width: 56, height: 16), corner: 4, color: wood, stroke: wood.darker, lineWidth: 1.5)
        seat.position = p; seat.zPosition = ZLayer.decals + 1; worldNode.addChild(seat)
        for dx in [-22.0, 22.0] {
            let leg = SKSpriteNode(color: wood.darker, size: CGSize(width: 5, height: 12))
            leg.position = CGPoint(x: p.x + dx, y: p.y - 12); leg.zPosition = ZLayer.decals + 0.9; worldNode.addChild(leg)
        }
    }

    private func addHubBuilding(label: String, at p: CGPoint, roof: SKColor, door: CGPoint?) {
        addBuilding(BuildingSpec(pos: p, size: CGSize(width: 180, height: 140), roof: roof, label: label))
        if let d = door {
            let glow = SKShapeNode(circleOfRadius: 26)
            glow.fillColor = roof.withAlphaComponent(0.35); glow.strokeColor = .white; glow.lineWidth = 2; glow.glowWidth = 4
            glow.position = d; glow.zPosition = ZLayer.items
            glow.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.6), .scale(to: 1.0, duration: 0.6)])))
            let tag = SKLabelNode(text: label); tag.fontName = "AvenirNext-Heavy"; tag.fontSize = 12
            tag.fontColor = .white; tag.verticalAlignmentMode = .center; tag.position = CGPoint(x: 0, y: -40)
            glow.addChild(tag)
            worldNode.addChild(glow)
        }
    }

    /// Gentle day↔night tint cycle in the hub.
    private func startDayNight() {
        cam.childNode(withName: "dayNight")?.removeFromParent()
        let overlay = SKSpriteNode(color: SKColor(red: 0.1, green: 0.1, blue: 0.35, alpha: 1),
                                   size: CGSize(width: 4000, height: 4000))
        overlay.zPosition = ZLayer.fx + 1; overlay.alpha = 0; overlay.name = "dayNight"
        cam.addChild(overlay)
        overlay.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.0, duration: 14),   // day
            .fadeAlpha(to: 0.45, duration: 8),   // dusk → night
            .fadeAlpha(to: 0.45, duration: 6),
            .fadeAlpha(to: 0.0, duration: 8)     // dawn
        ])))
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

        if state == .minigame { updateMinigame(dt: dt); return }

        // Free-roam hub: move + contextual interactions, no stealth/objective.
        if inHub {
            if state == .playing { movePlayer(dt: dt); updateHubInteract() }
            player.update(dt: dt)
            cam.position = cameraWithShake(clampedCamera(player.position), dt: dt)
            hud.updateEnergy(player.energyPct)
            return
        }

        // Driving levels use a dedicated update path.
        if level.isDriving {
            if state == .playing { updateDriving(dt: dt) }
            player.update(dt: dt)
            cam.position = cameraWithShake(drivingCamera(), dt: dt)
            hud.updateEnergy(player.energyPct)
            if !demoMode { dashBtn.setEnabled(player.energy >= 25) }
            return
        }

        if state == .playing { movePlayer(dt: dt) }
        player.update(dt: dt)
        cam.position = cameraWithShake(clampedCamera(player.position), dt: dt)

        for m in minions { m.update(dt: dt) }
        if state == .playing {
            updateStealth(dt: dt)
            updatePickups(dt: dt)
            updateMechanics(dt: dt)
            updateBossProjectiles()
            updateGrappleTarget()
            updateObjectiveArrow()
            updateObjectiveProximity()
            updateInteractTarget()
        }
        hud.updateEnergy(player.energyPct)
        if !demoMode {
            dashBtn.setEnabled(player.energy >= 25)
            shieldBtn.setEnabled(player.energy >= 35 && !player.isShielded)
        }
    }

    func shake(_ mag: CGFloat, _ dur: TimeInterval) {
        shakeMag = max(shakeMag, mag)
        shakeTime = max(shakeTime, dur)
    }

    private func cameraWithShake(_ base: CGPoint, dt: TimeInterval) -> CGPoint {
        guard shakeTime > 0 else { return base }
        shakeTime -= dt; shakeElapsed += dt
        let amp = shakeMag * min(1, CGFloat(shakeTime) / 0.2 + 0.25)
        let ox = sin(CGFloat(shakeElapsed) * 92) * amp
        let oy = cos(CGFloat(shakeElapsed) * 71) * amp
        if shakeTime <= 0 { shakeMag = 0 }
        return CGPoint(x: base.x + ox, y: base.y + oy)
    }

    private func clampedCamera(_ pos: CGPoint) -> CGPoint {
        CGPoint(x: max(size.width/2, min(worldSize.width - size.width/2, pos.x)),
                y: max(size.height/2, min(worldSize.height - size.height/2, pos.y)))
    }

    private func movePlayer(dt: TimeInterval) {
        if grappling { return }   // the zip animates the player
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

    // MARK: - Objective arrow

    private func nearestCrystal() -> SKShapeNode? {
        crystalNodes.filter { $0.parent != nil }
            .min { $0.position.distance(to: player.position) < $1.position.distance(to: player.position) }
    }

    private func updateObjectiveArrow() {
        if level.isDriving { objectiveArrow.isHidden = true; return }
        var target: CGPoint?; var text = ""; var color = biome.accent
        if level.keycardPos != nil, !hasKeycard, let k = keycardNode, k.parent != nil {
            target = k.position; text = "KEY"; color = Palette.energy
        } else {
            switch objective {
            case .collect: if let c = nearestCrystal() { target = c.position; text = "CRYSTAL"; color = Palette.crystal }
            case .charge:  target = powerCore?.position; text = "CORE"; color = biome.accent
            case .reachExit: target = exitPortal?.position; text = level.exitLabel; color = biome.accent
            case .boss:    target = villain?.position; text = "FIGHT"; color = Palette.heroRed
            case .done:    break
            }
        }
        guard let t = target else { objectiveArrow.isHidden = true; return }
        let dx = t.x - player.position.x, dy = t.y - player.position.y
        let dist = hypot(dx, dy)
        if dist < 210 { objectiveArrow.isHidden = true; return }   // close enough to see it
        objectiveArrow.isHidden = false
        let ang = atan2(dy, dx)
        let r = min(size.width, size.height) * 0.30
        objectiveArrow.position = CGPoint(x: cos(ang) * r, y: sin(ang) * r * 0.78 + size.height * 0.04)
        (objectiveArrow.childNode(withName: "tri") as? SKShapeNode).map { $0.zRotation = ang; $0.fillColor = color }
        (objectiveArrow.childNode(withName: "//lbl") as? SKLabelNode)?.text = "\(text)  \(Int(dist/10))m"
    }

    // MARK: - Grapple

    private func updateGrappleTarget() {
        if grappling { grappleBtn.isHidden = true; return }
        var best: SKNode?; var bestD = CGFloat.greatestFiniteMagnitude
        for a in grappleAnchorNodes {
            let d = a.position.distance(to: player.position)
            if d > 50 && d < 360 && d < bestD { bestD = d; best = a }
        }
        for a in grappleAnchorNodes where a !== best {
            a.removeAction(forKey: "ghi"); a.setScale(1)
        }
        grappleTarget = best
        if let t = best {
            grappleBtn.isHidden = false; grappleBtn.setEnabled(true)
            if t.action(forKey: "ghi") == nil {
                t.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.4), .scale(to: 1.0, duration: 0.4)])), withKey: "ghi")
            }
        } else {
            grappleBtn.isHidden = true
        }
    }

    private func grapple() {
        guard !grappling, let target = grappleTarget else { return }
        grappling = true
        joystick.end()
        grappleBtn.isHidden = true
        let dest = target.position
        let dist = dest.distance(to: player.position)
        let dur = min(0.5, max(0.18, TimeInterval(dist / 1500)))
        // rope line
        let line = SKShapeNode()
        let p = CGMutablePath(); p.move(to: player.position); p.addLine(to: dest); line.path = p
        line.strokeColor = biome.accent; line.lineWidth = 3; line.glowWidth = 2; line.zPosition = ZLayer.fx
        worldNode.addChild(line)
        line.run(.sequence([.wait(forDuration: dur), .fadeOut(withDuration: 0.15), .removeFromParent()]))
        SoundFX.shared.play("dash")
        let move = SKAction.move(to: dest, duration: dur); move.timingMode = .easeInEaseOut
        player.faceMovement(CGVector(dx: dest.x - player.position.x, dy: dest.y - player.position.y))
        player.run(.sequence([move, .run { [weak self] in self?.grappling = false; self?.shake(5, 0.15) }]), withKey: "grapple")
    }

    // MARK: - Stealth

    private var playerHidden: Bool { coverRects.contains { $0.contains(player.position) } }

    private func updateStealth(dt: TimeInterval) {
        if caughtCooldown > 0 { caughtCooldown -= dt }
        let exposed = player.inCostume && !playerHidden && !player.isShielded && starTimer <= 0 && !grappling
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
        SoundFX.shared.play("caught"); shake(9, 0.25)
        lives = max(0, lives - 1)
        hud.setLives(lives, max: maxLives)

        // Out of lives → restart the whole level.
        if lives <= 0 {
            hud.showToast("Out of lives! Restarting level…", color: Palette.heroRed)
            for m in minions { m.setSeeing(false, dt: 1) }
            run(.sequence([.wait(forDuration: 1.1),
                           .run { [weak self] in guard let self else { return }; self.loadLevel(self.levelIndex) }]),
                withKey: "levelRestart")
            return
        }

        // During the boss fight, a hit just knocks you back a little (don't reset the arena).
        if objective == .boss {
            hud.showToast("Zapped! 💔 \(lives) left", color: Palette.heroRed)
            if let v = villain {
                let away = CGVector(dx: player.position.x - v.position.x, dy: player.position.y - v.position.y)
                let len = max(hypot(away.dx, away.dy), 1)
                player.position.x = max(40, min(worldSize.width - 40, player.position.x + away.dx/len * 120))
                player.position.y = max(40, min(worldSize.height - 40, player.position.y + away.dy/len * 120))
            }
        } else {
            hud.showToast("Spotted! 💔 \(lives) left", color: Palette.heroRed)
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
        SoundFX.shared.play("collect")
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
        if objective == .boss, let v = villain {
            if bossFightActive {
                // Persistent attack button during the fight (no flicker as he dodges).
                enabled = true; label = "HIT!"; nearestInteract = { [weak self] in self?.bossStrike() }
            } else if v.position.distance(to: player.position) < 135 {
                enabled = true; label = "FIGHT"; nearestInteract = { [weak self] in self?.fightVillain() }
            }
        }
        interactBtn.setTitle(label)
        interactBtn.setEnabled(enabled)
    }

    private func updateHubInteract() {
        let pp = player.position
        // Collect coins scattered around town.
        for c in coinNodes where c.parent != nil && c.position.distance(to: pp) < 38 {
            c.removeFromParent(); Economy.addCoins(1); hud.updateCoins(Economy.coins)
            blip(c.position, "★", Palette.energy); SoundFX.shared.play("coin")
            if questActive { questProgress += 1; updateQuestHUD() }
        }
        // Walk into the missions portal → zone map.
        if let portal = missionsPortal, portal.position.distance(to: pp) < 50 {
            inHub = false
            cam.childNode(withName: "dayNight")?.removeFromParent()
            SoundFX.shared.play("powerup")
            showMap()
            return
        }
        nearestInteract = nil
        var label = "TALK"; var enabled = false
        if chestPos.distance(to: pp) < 70 {
            enabled = true; label = Economy.canClaimDaily ? "OPEN" : "DAILY"
            nearestInteract = { [weak self] in self?.openChest() }
        } else if let s = shopDoor, s.distance(to: pp) < 72 {
            enabled = true; label = "SHOP"; nearestInteract = { [weak self] in self?.openShopFromHub() }
        } else if let a = arcadeDoor, a.distance(to: pp) < 72 {
            enabled = true; label = "ARCADE"; nearestInteract = { [weak self] in self?.openArcade() }
        } else if fountainPos.distance(to: pp) < 88 {
            enabled = true; label = "WISH"; nearestInteract = { [weak self] in self?.makeWish() }
        } else if let dog = petNode, dog.position.distance(to: pp) < 64 {
            enabled = true; label = "PET"; nearestInteract = { [weak self] in self?.petDog() }
        } else if let npc = nearestNPC(), npc.position.distance(to: pp) < 72 {
            enabled = true; label = "TALK"; nearestInteract = { [weak self] in self?.talkTo(npc) }
        }
        interactBtn.setTitle(label)
        interactBtn.setEnabled(enabled)
    }

    /// Wishing fountain: a once-per-day fortune with a chance at lucky bonus coins.
    private func makeWish() {
        guard Economy.canWishToday else {
            hud.showToast("You already wished today — come back tomorrow!", color: Palette.hudAccent)
            SoundFX.shared.play("tap"); return
        }
        let result = Economy.wish()
        SoundFX.shared.play(result.bonus > 0 ? "powerup" : "coin")
        // A sparkle burst over the fountain water.
        if let spark = Effects.ambient(.sparks, screen: CGSize(width: 80, height: 80)) {
            spark.particleColor = Palette.energy; spark.particleBirthRate = 120; spark.numParticlesToEmit = 40
            spark.particleLifetime = 0.9; spark.particleSpeed = 90; spark.particlePositionRange = CGVector(dx: 40, dy: 10)
            spark.position = CGPoint(x: fountainPos.x, y: fountainPos.y + 10); spark.zPosition = ZLayer.fx + 2
            worldNode.addChild(spark)
            spark.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
        }
        blip(fountainPos, "✨", Palette.energy)
        hud.showToast("🪙 \"\(result.fortune)\"", color: Palette.crystal)
        if result.bonus > 0 {
            hud.updateCoins(Economy.coins)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                self?.hud.showToast("Lucky wish! +\(result.bonus) ★", color: Palette.energy)
            }
        }
        updateHubInteract()
    }

    private func giveCarriedItem(_ glyph: String) {
        carriedItem?.removeFromParent()
        let item = SKLabelNode(text: glyph); item.fontSize = 26; item.verticalAlignmentMode = .center
        item.position = CGPoint(x: 0, y: 58); item.zPosition = ZLayer.fx
        item.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.5), .moveBy(x: 0, y: -5, duration: 0.5)])))
        player.addChild(item); carriedItem = item
    }

    private func updateQuestHUD() {
        refreshQuestMarkers()
        if deliverActive {
            hud.updateObjective(level: "SIDE-QUEST", title: "Special Delivery",
                                hint: "Carry Granny's pie to Mayor Mia", progress: "🥧")
        } else if questActive {
            hud.updateObjective(level: "SIDE-QUEST", title: "Tommy's Coin Rush",
                                hint: "Collect coins around town, then tell Tommy",
                                progress: "\(min(questProgress, questTarget))/\(questTarget)")
        } else {
            hud.updateObjective(level: "HERO CITY", title: "Welcome home, hero!",
                                hint: "Tap MISSIONS to play · explore the town!", progress: "")
        }
    }

    private func talkTommy() {
        if questDone {
            showDialogue(speaker: "Tommy", lines: ["Thanks again, Kaiditya! You're the best."]); return
        }
        if !questActive {
            showDialogue(speaker: "Tommy", lines: [
                "Hi Kaiditya! I dropped my \(questTarget) lucky coins all over town.",
                "Could you find them for me? I'll give you a reward!"
            ]) { [weak self] in
                guard let self else { return }
                self.questActive = true; self.questProgress = 0; self.updateQuestHUD()
                self.hud.showToast("Quest started: find \(self.questTarget) coins!", color: Palette.energy)
            }
        } else if questProgress >= questTarget {
            showDialogue(speaker: "Tommy", lines: [
                "You found them all! Wow, thank you!",
                "Here's a reward — 15 bonus coins! ★"
            ]) { [weak self] in
                guard let self else { return }
                Economy.addCoins(15); self.hud.updateCoins(Economy.coins)
                self.questActive = false; self.questDone = true; self.updateQuestHUD()
                SoundFX.shared.play("powerup")
                self.hud.showToast("+15 coins! Quest complete 🎉", color: Palette.crystal)
            }
        } else {
            showDialogue(speaker: "Tommy", lines: ["Found \(questProgress) of \(questTarget) so far — keep looking!"])
        }
    }

    private func openShopFromHub() {
        cam.childNode(withName: "dayNight")?.removeFromParent()
        inHub = false
        shopFromHub = true
        showShop()
    }

    private func openArcade() { startMinigame() }

    private func openChest() {
        let (reward, streak) = Economy.claimDaily()
        if reward > 0 {
            hud.updateCoins(Economy.coins)
            SoundFX.shared.play("powerup"); shake(5, 0.2)
            blip(chestPos, "+\(reward) ★", Palette.energy)
            let streakMsg = streak > 1 ? " · \(streak)-day streak! 🔥" : ""
            hud.showToast("Daily bonus: +\(reward) coins!\(streakMsg)", color: Palette.crystal)
            // swap to closed/dim chest
            chestNode?.removeFromParent()
            let closed = CharacterFactory.makeChest(glowing: false)
            closed.position = chestPos; closed.zPosition = ZLayer.items
            let tag = SKLabelNode(text: "DAILY"); tag.fontName = "AvenirNext-Heavy"; tag.fontSize = 11
            tag.fontColor = Palette.energy; tag.position = CGPoint(x: 0, y: -34); closed.addChild(tag)
            worldNode.addChild(closed); chestNode = closed
        } else {
            hud.showToast("Already opened — come back tomorrow!", color: Palette.heroRed)
        }
    }

    // MARK: - Crystal Catch minigame

    private func startMinigame() {
        state = .minigame
        setControlsHidden(true)
        mgLayer.removeAllChildren(); mgLayer.removeFromParent()
        mgCrystals = []; mgScore = 0; mgTime = 30; mgSpawn = 0; mgOver = false
        mgLayer.zPosition = ZLayer.overlay
        cam.addChild(mgLayer)

        let bg = SKSpriteNode(color: SKColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1), size: CGSize(width: 4000, height: 4000))
        mgLayer.addChild(bg)
        let title = SKLabelNode(text: "CRYSTAL CATCH"); title.fontName = "AvenirNext-Heavy"; title.fontSize = 24
        title.fontColor = Palette.crystal; title.position = CGPoint(x: 0, y: size.height/2 - safeTop - 44); mgLayer.addChild(title)
        let score = SKLabelNode(text: "0 ★"); score.name = "mgScore"; score.fontName = "AvenirNext-Heavy"; score.fontSize = 20
        score.fontColor = Palette.energy; score.horizontalAlignmentMode = .left
        score.position = CGPoint(x: -size.width/2 + 24, y: size.height/2 - safeTop - 44); mgLayer.addChild(score)
        let timer = SKLabelNode(text: "30s"); timer.name = "mgTimer"; timer.fontName = "AvenirNext-Heavy"; timer.fontSize = 20
        timer.fontColor = .white; timer.horizontalAlignmentMode = .right
        timer.position = CGPoint(x: size.width/2 - 24, y: size.height/2 - safeTop - 44); mgLayer.addChild(timer)
        let best = SKLabelNode(text: "BEST  \(Economy.bestCatch) ★")
        best.fontName = "AvenirNext-Bold"; best.fontSize = 13; best.fontColor = Palette.crystal
        best.position = CGPoint(x: 0, y: size.height/2 - safeTop - 70); mgLayer.addChild(best)
        let hint = SKLabelNode(text: "Drag / arrows to catch the crystals!")
        hint.fontName = "AvenirNext-Medium"; hint.fontSize = 13; hint.fontColor = Palette.hudAccent
        hint.position = CGPoint(x: 0, y: size.height/2 - safeTop - 92); mgLayer.addChild(hint)

        // Basket catcher near the bottom.
        let catcher = SKNode()
        let basket = roundedRect(size: CGSize(width: 84, height: 30), corner: 10, color: Palette.heroBlue, stroke: .white, lineWidth: 2)
        catcher.addChild(basket)
        let rim = roundedRect(size: CGSize(width: 84, height: 8), corner: 4, color: Palette.crystal)
        rim.position = CGPoint(x: 0, y: 13); catcher.addChild(rim)
        catcher.position = CGPoint(x: 0, y: -size.height/2 + safeBottom + 90)
        catcher.zPosition = 2; mgLayer.addChild(catcher); mgCatcher = catcher

        // Early-exit button (bottom-left, clear of the catcher) — quitting banks crystals caught so far.
        let quit = SKShapeNode(circleOfRadius: 22); quit.name = "mgQuit"
        quit.fillColor = Palette.hudPanel; quit.strokeColor = Palette.heroRed; quit.lineWidth = 1.5
        quit.position = CGPoint(x: -size.width/2 + 40, y: -size.height/2 + safeBottom + 40); quit.zPosition = 6
        let qx = SKLabelNode(text: "✕"); qx.fontName = "AvenirNext-Heavy"; qx.fontSize = 20
        qx.fontColor = .white; qx.verticalAlignmentMode = .center; quit.addChild(qx)
        mgLayer.addChild(quit)
    }

    private func updateMinigame(dt: TimeInterval) {
        guard !mgOver, let catcher = mgCatcher else { return }
        // Move catcher.
        let dx = joystick.vector.dx + keyboardVector().dx
        let halfW = size.width/2 - 50
        catcher.position.x = max(-halfW, min(halfW, catcher.position.x + dx * 460 * CGFloat(dt)))

        // Timer.
        mgTime -= dt
        (mgLayer.childNode(withName: "mgTimer") as? SKLabelNode)?.text = "\(max(0, Int(ceil(mgTime))))s"
        if mgTime <= 0 { endMinigame(); return }

        // Spawn falling crystals.
        mgSpawn += dt
        if mgSpawn > 0.62 {
            mgSpawn = 0
            let c = CharacterFactory.makeCrystal(); c.setScale(0.85)
            c.position = CGPoint(x: CGFloat.random(in: -halfW...halfW), y: size.height/2 - safeTop - 100)
            c.zPosition = 1; mgLayer.addChild(c); mgCrystals.append(c)
        }
        let fall: CGFloat = 320
        let catchY = catcher.position.y
        for c in mgCrystals where c.parent != nil {
            c.position.y -= fall * CGFloat(dt)
            c.zRotation += CGFloat(dt) * 3
            if c.position.y <= catchY + 18 && c.position.y >= catchY - 24 && abs(c.position.x - catcher.position.x) < 52 {
                c.removeFromParent(); mgScore += 1
                (mgLayer.childNode(withName: "mgScore") as? SKLabelNode)?.text = "\(mgScore) ★"
                SoundFX.shared.play("coin")
                blipMG(c.position, "+1", Palette.energy)
            } else if c.position.y < -size.height/2 - 30 {
                c.removeFromParent()
            }
        }
        mgCrystals.removeAll { $0.parent == nil }
    }

    private func blipMG(_ pos: CGPoint, _ text: String, _ color: SKColor) {
        let s = SKLabelNode(text: text); s.fontName = "AvenirNext-Heavy"; s.fontSize = 18; s.fontColor = color
        s.position = pos; s.zPosition = 5; mgLayer.addChild(s)
        s.run(.sequence([.group([.moveBy(x: 0, y: 40, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    private func endMinigame() {
        mgOver = true
        let newBest = Economy.recordCatch(mgScore)
        let bonus = newBest ? 5 : 0
        Economy.addCoins(mgScore + bonus)
        SoundFX.shared.play("clear")
        let card = roundedRect(size: CGSize(width: min(size.width - 60, 380), height: 220), corner: 20, color: Palette.hudPanel)
        card.strokeColor = Palette.energy; card.lineWidth = 3; card.zPosition = 10; mgLayer.addChild(card)
        let t = SKLabelNode(text: newBest ? "NEW BEST! 🎉" : "TIME'S UP!"); t.fontName = "AvenirNext-Heavy"
        t.fontSize = 26; t.fontColor = Palette.energy; t.position = CGPoint(x: 0, y: 70); card.addChild(t)
        let r = SKLabelNode(text: "Caught \(mgScore) crystals"); r.fontName = "AvenirNext-Bold"; r.fontSize = 17; r.fontColor = .white
        r.position = CGPoint(x: 0, y: 30); card.addChild(r)
        let bestL = SKLabelNode(text: "Best: \(Economy.bestCatch)"); bestL.fontName = "AvenirNext-Medium"; bestL.fontSize = 14
        bestL.fontColor = Palette.crystal; bestL.position = CGPoint(x: 0, y: 4); card.addChild(bestL)
        let c = SKLabelNode(text: newBest ? "+\(mgScore) ★  +5 bonus!" : "+\(mgScore) ★  coins")
        c.fontName = "AvenirNext-Heavy"; c.fontSize = 18; c.fontColor = Palette.crystal
        c.position = CGPoint(x: 0, y: -24); card.addChild(c)
        let go = SKLabelNode(text: "tap to continue ▸"); go.fontName = "AvenirNext-Bold"; go.fontSize = 13; go.fontColor = Palette.hudAccent
        go.position = CGPoint(x: 0, y: -68); card.addChild(go)
        dramatize(card, in: mgLayer, accent: Palette.energy, rays: false)
    }

    private func closeMinigame() {
        mgLayer.removeAllChildren(); mgLayer.removeFromParent()
        mgCrystals = []; mgCatcher = nil
        enterHub()   // back to town with updated coins
    }

    private func nearestNPC() -> NPC? {
        npcs.min(by: { $0.position.distance(to: player.position) < $1.position.distance(to: player.position) })
    }

    private func talkTo(_ npc: NPC) {
        if inHub {
            switch npc.id {
            case "tommy":
                talkTommy()
            case "mayor":
                if deliverActive {
                    showDialogue(speaker: "Mayor Mia", lines: [
                        "Ooh, Granny's famous pie — and still warm!",
                        "Thank you, Kaiditya! Here's 10 coins for your trouble. ★"
                    ]) { [weak self] in
                        guard let self else { return }
                        Economy.addCoins(10); self.hud.updateCoins(Economy.coins)
                        self.deliverActive = false; self.deliverDone = true
                        self.carriedItem?.removeFromParent(); self.carriedItem = nil
                        SoundFX.shared.play("powerup")
                        self.hud.showToast("Pie delivered! +10 coins 🥧", color: Palette.crystal)
                        self.updateQuestHUD()
                    }
                } else {
                    showDialogue(speaker: "Mayor Mia", lines: [
                        "Welcome to Hero City, Kaiditya!",
                        "Step into the glowing MISSIONS portal to choose a zone to save.",
                        "Spend the coins you collect at the SHOP for new gadgets!"
                    ])
                }
            case "gran":
                if deliverDone {
                    showDialogue(speaker: "Granny Gold", lines: ["Thank you again for delivering my pie, dearie!"])
                } else if deliverActive {
                    showDialogue(speaker: "Granny Gold", lines: ["Hurry now — take that pie to Mayor Mia before it gets cold!"])
                } else {
                    showDialogue(speaker: "Granny Gold", lines: [
                        "Dearie! I baked a pie for Mayor Mia.",
                        "Would you carry it over to her for me? I'll pay you!"
                    ]) { [weak self] in
                        guard let self else { return }
                        self.deliverActive = true
                        self.giveCarriedItem("🥧")
                        SoundFX.shared.play("coin")
                        self.hud.showToast("Carry the pie to Mayor Mia!", color: Palette.energy)
                        self.updateQuestHUD()
                    }
                }
            default:
                showDialogue(speaker: npc.displayName, lines: ["Stay super, Kaiditya!"])
            }
            return
        }
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
        SoundFX.shared.play("powerup"); shake(6, 0.25)
        core.run(.sequence([.scale(to: 1.3, duration: 0.2), .scale(to: 1.0, duration: 0.2)]))
        let burst = SKShapeNode(circleOfRadius: 40); burst.strokeColor = biome.accent; burst.lineWidth = 4; burst.fillColor = .clear
        burst.position = core.position; burst.zPosition = ZLayer.fx; worldNode.addChild(burst)
        burst.run(.sequence([.group([.scale(to: 4, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
        activateExit()
        hud.updateObjective(level: "Level \(level.index) · \(level.name)", title: level.objective, hint: objectiveHint(), progress: progressText())
    }

    private func fightVillain() {
        guard objective == .boss, !bossFightActive else { return }  // don't restart mid-fight
        objective = .done   // lock interaction during the intro dialogue
        showDialogue(speaker: "Lord Chow-Chow", lines: [
            "You?! A pint-sized hero?",
            "I'll zap you with my static powers!"
        ]) { [weak self] in
            self?.objective = .boss
            self?.hud.showToast("Chase him & tap HIT to attack! SHIELD blocks zaps.", color: Palette.energy)
            self?.beginBossFight()
        }
    }

    private func beginBossFight() {
        guard let v = villain else { return }
        bossFightActive = true
        hud.showBossBar(name: "LORD CHOW-CHOW", total: 3 * level.bossPhases)
        SoundFX.shared.playMusic("boss", volume: 0.55)
        v.run(.repeatForever(.sequence([.moveBy(x: 130, y: 0, duration: 0.95), .moveBy(x: -130, y: 0, duration: 0.95)])), withKey: "dodge")
        // Attack scheduler: patterns escalate with the phase.
        run(.repeatForever(.sequence([.wait(forDuration: 2.4), .run { [weak self] in self?.bossAttack() }])), withKey: "bossAttacks")
    }

    /// Land a hit on the boss by tapping HIT while near him (lunges in to connect).
    private func bossStrike() {
        guard objective == .boss, bossFightActive, let v = villain else { return }
        guard action(forKey: "hitCooldown") == nil else { return }   // brief swing cooldown
        let dx = v.position.x - player.position.x, dy = v.position.y - player.position.y
        let dist = max(hypot(dx, dy), 1)
        if dist > 120 {
            hud.showToast("Get closer to Lord Chow-Chow!", color: Palette.energy)
            run(.wait(forDuration: 0.3), withKey: "hitCooldown")
            return
        }
        // A quick punch spark toward the boss (the player stays under joystick control).
        let spark = SKLabelNode(text: "💥"); spark.fontSize = 26
        spark.position = CGPoint(x: (player.position.x + v.position.x)/2, y: (player.position.y + v.position.y)/2)
        spark.zPosition = ZLayer.fx; worldNode.addChild(spark)
        spark.run(.sequence([.group([.scale(to: 1.6, duration: 0.2), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        landBossHit(v)
    }

    /// Boss attack patterns — more variety as phases rise.
    private func bossAttack() {
        guard objective == .boss, let v = villain else { return }
        bossAttackCounter += 1
        // Telegraph flash before attacking.
        v.run(.sequence([.scale(to: 1.18, duration: 0.15), .scale(to: 1.0, duration: 0.15)]))
        switch bossPhase {
        case 1:
            if bossAttackCounter % 2 == 0 { boltVolley(from: v, count: 3, spread: 0.25) }
            else { groundStrikes(count: 3) }
        case 2:
            switch bossAttackCounter % 4 {
            case 0: ringBlast(from: v)
            case 1: boltVolley(from: v, count: 5, spread: 0.4)
            case 2: spiralBolts(from: v, arms: 2)
            default: groundStrikes(count: 4)
            }
        default:
            switch bossAttackCounter % 5 {
            case 0: chargeAttack(v)
            case 1: ringBlast(from: v)
            case 2: spiralBolts(from: v, arms: 3)
            case 3: dropMines(count: 5)
            default: groundStrikes(count: 5)
            }
        }
    }

    /// Rotating spiral spray of bolts (bullet-hell flavor).
    private func spiralBolts(from v: SKNode, arms: Int) {
        let shots = 9
        for k in 0..<shots {
            let baseDelay = Double(k) * 0.12
            run(.sequence([.wait(forDuration: baseDelay), .run { [weak self] in
                guard let self, self.objective == .boss, v.parent != nil else { return }
                for arm in 0..<arms {
                    let a = CGFloat(k) * 0.5 + CGFloat(arm) * (.pi * 2 / CGFloat(arms))
                    self.spawnBolt(from: v.position, angle: a)
                }
            }]))
        }
    }

    private func spawnBolt(from origin: CGPoint, angle a: CGFloat) {
        let bolt = SKShapeNode(circleOfRadius: 7)
        bolt.fillColor = Palette.energy; bolt.strokeColor = .white; bolt.lineWidth = 1; bolt.glowWidth = 4
        bolt.position = origin; bolt.zPosition = ZLayer.fx
        worldNode.addChild(bolt); bossProjectiles.append(bolt)
        let dest = CGPoint(x: origin.x + cos(a) * 900, y: origin.y + sin(a) * 900)
        bolt.run(.sequence([.move(to: dest, duration: 2.0), .removeFromParent()]))
    }

    /// Telegraphed ground strikes: warning rings that detonate where you stand.
    private func groundStrikes(count: Int) {
        for i in 0..<count {
            let jitter = CGFloat((i * 53) % 200 - 100)
            let target = CGPoint(x: max(60, min(worldSize.width - 60, player.position.x + jitter)),
                                 y: max(60, min(worldSize.height - 60, player.position.y + CGFloat((i*89)%200 - 100))))
            let warn = SKShapeNode(circleOfRadius: 56)
            warn.strokeColor = Palette.heroRed; warn.lineWidth = 3; warn.fillColor = Palette.heroRed.withAlphaComponent(0.12)
            warn.position = target; warn.zPosition = ZLayer.decals + 0.5
            worldNode.addChild(warn)
            warn.run(.sequence([
                .repeat(.sequence([.fadeAlpha(to: 0.4, duration: 0.2), .fadeAlpha(to: 1, duration: 0.2)]), count: 2),
                .run { [weak self] in
                    guard let self else { return }
                    let blast = SKShapeNode(circleOfRadius: 56)
                    blast.fillColor = Palette.heroRed.withAlphaComponent(0.5); blast.strokeColor = Palette.energy; blast.lineWidth = 3
                    blast.position = target; blast.zPosition = ZLayer.fx
                    self.worldNode.addChild(blast)
                    blast.run(.sequence([.group([.scale(to: 1.25, duration: 0.18), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
                    SoundFX.shared.play("hit")
                    if target.distance(to: self.player.position) < 150 { self.shake(6, 0.18) }
                    if self.objective == .boss, self.starTimer <= 0, !self.player.isShielded,
                       target.distance(to: self.player.position) < 60 {
                        self.handleCaught()
                    }
                },
                .removeFromParent()
            ]))
        }
    }

    /// Drop lingering static mines around the arena.
    private func dropMines(count: Int) {
        guard let v = villain else { return }
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * .pi * 2
            let pos = CGPoint(x: v.position.x + cos(a) * 180, y: v.position.y + sin(a) * 180)
            let mine = SKShapeNode(circleOfRadius: 11)
            mine.fillColor = Palette.villain.darker; mine.strokeColor = Palette.heroRed; mine.lineWidth = 2; mine.glowWidth = 3
            mine.position = pos; mine.zPosition = ZLayer.items; mine.name = "mine"
            let spike = SKShapeNode(path: starBurst(points: 8, outer: 14, inner: 8))
            spike.fillColor = .clear; spike.strokeColor = Palette.heroRed; spike.lineWidth = 1.5; mine.addChild(spike)
            mine.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.4), .fadeAlpha(to: 1, duration: 0.4)])))
            mine.run(.sequence([.wait(forDuration: 6), .fadeOut(withDuration: 0.3), .removeFromParent()]))
            worldNode.addChild(mine); bossProjectiles.append(mine)
        }
    }

    private func starBurst(points: Int, outer: CGFloat, inner: CGFloat) -> CGPath {
        let p = CGMutablePath(); let total = points * 2
        for i in 0...total {
            let r = i % 2 == 0 ? outer : inner
            let a = CGFloat(i) / CGFloat(total) * .pi * 2
            let pt = CGPoint(x: cos(a) * r, y: sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath(); return p
    }

    /// Fan of static bolts aimed at the hero.
    private func boltVolley(from v: SKNode, count: Int, spread: CGFloat) {
        let base = atan2(player.position.y - v.position.y, player.position.x - v.position.x)
        for i in 0..<count {
            let t = count == 1 ? 0 : (CGFloat(i)/CGFloat(count - 1) - 0.5)
            let a = base + t * spread * 2
            let bolt = SKShapeNode(path: {
                let p = CGMutablePath(); p.move(to: CGPoint(x: -3, y: 9)); p.addLine(to: CGPoint(x: 2, y: 1))
                p.addLine(to: CGPoint(x: -1, y: 1)); p.addLine(to: CGPoint(x: 3, y: -9)); p.addLine(to: CGPoint(x: -2, y: -1))
                p.addLine(to: CGPoint(x: 1, y: -1)); p.closeSubpath(); return p
            }())
            bolt.fillColor = Palette.energy; bolt.strokeColor = .white; bolt.lineWidth = 1; bolt.glowWidth = 4
            bolt.setScale(1.6); bolt.zRotation = a - .pi/2
            bolt.position = v.position; bolt.zPosition = ZLayer.fx
            worldNode.addChild(bolt); bossProjectiles.append(bolt)
            let dest = CGPoint(x: v.position.x + cos(a) * 900, y: v.position.y + sin(a) * 900)
            bolt.run(.sequence([.move(to: dest, duration: 1.6), .removeFromParent()]))
        }
    }

    /// Expanding shockwave ring; clip it at the right moment to avoid it.
    private func ringBlast(from v: SKNode) {
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.strokeColor = Palette.heroRed; ring.lineWidth = 8; ring.fillColor = .clear; ring.glowWidth = 4
        ring.position = v.position; ring.zPosition = ZLayer.fx; ring.name = "ringBlast"
        worldNode.addChild(ring); bossProjectiles.append(ring)
        ring.run(.sequence([.group([.scale(to: 12, duration: 1.1), .fadeOut(withDuration: 1.1)]), .removeFromParent()]))
    }

    /// Villain lunges at the hero, then retreats.
    private func chargeAttack(_ v: SKNode) {
        bossCharging = true
        v.removeAction(forKey: "dodge")
        let target = CGPoint(x: player.position.x, y: player.position.y)
        let home = v.position
        let lunge = SKAction.move(to: target, duration: 0.5); lunge.timingMode = .easeIn
        v.run(.sequence([lunge, .wait(forDuration: 0.2),
                         .move(to: home, duration: 0.6),
                         .run { [weak self] in
                             self?.bossCharging = false
                             let d = max(0.4, 0.85 - CGFloat(self?.bossPhase ?? 1) * 0.15)
                             v.run(.repeatForever(.sequence([.moveBy(x: 170, y: 0, duration: d), .moveBy(x: -170, y: 0, duration: d)])), withKey: "dodge")
                         }]))
    }

    private func updateBossProjectiles() {
        guard objective == .boss else { return }
        bossProjectiles.removeAll { $0.parent == nil }
        let safe = (starTimer > 0 || player.isShielded || grappling)
        if safe { return }
        for proj in bossProjectiles where proj.parent != nil {
            if proj.name == "ringBlast" {
                let radius = 30 * proj.xScale
                let d = proj.position.distance(to: player.position)
                if abs(d - radius) < 24 { hud.showToast("Zapped! 💥", color: Palette.heroRed); handleCaught() }
            } else if proj.position.distance(to: player.position) < 26 {
                proj.removeFromParent(); handleCaught()
            }
        }
        if bossCharging, let v = villain, v.position.distance(to: player.position) < 50 {
            handleCaught()
        }
    }

    /// Apply one hit to the boss (POW, health, phase/defeat). Called from bossStrike.
    private func landBossHit(_ v: SKNode) {
        let hitsPerPhase = 3
        let totalNeeded = hitsPerPhase * level.bossPhases
        bossHits += 1
        run(.wait(forDuration: 0.45), withKey: "hitCooldown")
        v.run(.sequence([.scale(to: 0.8, duration: 0.1), .scale(to: 1.0, duration: 0.1)]))
        let pow = SKLabelNode(text: "POW!"); pow.fontName = "AvenirNext-Heavy"; pow.fontSize = 30; pow.fontColor = Palette.heroRed
        pow.position = CGPoint(x: v.position.x, y: v.position.y + 50); pow.zPosition = ZLayer.fx; worldNode.addChild(pow)
        pow.run(.sequence([.group([.moveBy(x:0,y:30,duration:0.4), .fadeOut(withDuration:0.4)]), .removeFromParent()]))
        SoundFX.shared.play("hit"); shake(8, 0.18)
        hud.updateBossHealth(remaining: totalNeeded - bossHits, total: totalNeeded)
        hud.showToast("Hit \(bossHits)/\(totalNeeded)!", color: Palette.energy)
        if bossHits < totalNeeded && bossHits % hitsPerPhase == 0 {
            bossPhase += 1
            startBossPhase()
        }
        if bossHits >= totalNeeded { defeatVillain() }
    }

    private func startBossPhase() {
        guard let v = villain else { return }
        hud.showToast("Lord Chow-Chow is FURIOUS! Phase \(bossPhase)!", color: Palette.heroRed)
        SoundFX.shared.play("caught"); shake(12, 0.4)
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
        bossFightActive = false
        removeAction(forKey: "bossAttacks")
        bossProjectiles.forEach { $0.removeFromParent() }
        bossProjectiles = []
        objective = .done
        hud.hideBossBar()
        SoundFX.shared.play("hit"); shake(16, 0.6)
        villain?.removeAction(forKey: "dodge")
        villain?.run(.sequence([
            .group([.rotate(byAngle: .pi*4, duration: 0.8), .scale(to: 0.1, duration: 0.8), .fadeOut(withDuration: 0.8)]),
            .removeFromParent()
        ]))
        run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in self?.completeLevel() }]))
    }

    private func refreshQuestMarkers() {
        for npc in npcs {
            if inHub {
                let mark: Bool
                switch npc.id {
                case "tommy": mark = (!questActive && !questDone) || (questActive && questProgress >= questTarget)
                case "gran":  mark = !deliverActive && !deliverDone
                case "mayor": mark = deliverActive
                default:      mark = false
                }
                npc.setQuestMarker(mark)
            } else {
                npc.setQuestMarker(npc.id == "mayor" && levelIndex == 0)
            }
        }
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
        case .map: if tap(1.0) { cam.childNode(withName: "mapOverlay")?.removeFromParent(); loadLevel(min(maxUnlocked, Levels.all.count - 1)) }; return
        case .shop: if tap(1.0) { exitShop() }; return
        case .intro: if tap(1.2) { dismissIntro() }; return
        case .tour: if tap(1.0) { advanceTour() }; return
        case .complete: if tap(1.5) { cam.childNode(withName: "completeOverlay")?.removeFromParent(); loadLevel(levelIndex + 1) }; return
        case .dialogue: if tap(0.7) { advanceDialogue() }; return
        case .won: return
        case .minigame: if mgOver, tap(1.0) { closeMinigame() }; return
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
