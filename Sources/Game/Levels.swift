import SpriteKit

/// Visual + gameplay theme for a level.
enum CoverShape { case bush, crate, pillar }
/// What the "collect" phase of a level asks for. All three feed the same N/required counter.
enum MissionKind { case crystals, rescue, sabotage }
enum AmbientFX { case none, fireflies, embers, sparks }

struct Biome {
    let groundA: SKColor
    let groundB: SKColor
    let pathColor: SKColor
    let borderColor: SKColor
    let coverFill: SKColor
    let coverDetail: SKColor
    let treeFill: SKColor
    let buildingWall: SKColor
    let signColor: SKColor
    let ambientColor: SKColor    // full-screen overlay tint (time of day)
    let ambientAlpha: CGFloat
    let accent: SKColor          // portals / neon highlights
    let coverShape: CoverShape
    let ambientFX: AmbientFX
    let vignette: CGFloat        // 0..1 edge darkening strength
}

struct BuildingSpec {
    let pos: CGPoint
    let size: CGSize
    let roof: SKColor
    let label: String?
}

struct NPCSpec {
    let id: String
    let name: String
    let pos: CGPoint
    let tint: SKColor
}

struct LevelData {
    let index: Int
    let name: String
    let subtitle: String
    let biome: Biome
    let worldSize: CGSize
    let heroSpawn: CGPoint
    let corePos: CGPoint?          // charge target (level 1)
    let exitPos: CGPoint           // exit portal / boss arena
    let crystalsRequired: Int
    let crystalSpots: [CGPoint]
    let minionPatrols: [[CGPoint]]
    let minionSpeed: CGFloat
    let minionRange: CGFloat
    let coverSpots: [CGPoint]
    let treeSpots: [CGPoint]
    let buildings: [BuildingSpec]
    let signs: [(text: String, pos: CGPoint)]
    let npcs: [NPCSpec]
    let hasBoss: Bool
    let objective: String
    let exitLabel: String
    var isDriving: Bool = false

    // --- Expansion mechanics (all optional) ---
    var coinSpots: [CGPoint] = []          // bonus currency
    var searchlights: [CGPoint] = []       // rotating vision cones (stationary)
    var laserGates: [CGPoint] = []         // toggling horizontal beams
    var speedPads: [CGPoint] = []          // step-on speed boost
    var magnetSpots: [CGPoint] = []        // crystal-magnet power-up
    var starSpots: [CGPoint] = []          // invincibility power-up
    var waterRects: [CGRect] = []          // slow-you-down water
    var keycardPos: CGPoint? = nil         // exit locked until grabbed
    var dronesStyle: Bool = false          // minions drawn/behave as drones
    var bossPhases: Int = 1                // multi-phase boss
    var isBoat: Bool = false               // boat chase variant
    var grappleAnchors: [CGPoint] = []     // zip-to grapple points
    var hazardSpots: [CGPoint] = []        // stationary electric traps (cost a life)
    var isHub: Bool = false                // free-roam home town
    var mission: MissionKind = .crystals   // rescue: free caged citizens · sabotage: shut down generators/pumps
    var siteSpots: [CGPoint] = []          // cages / generators (hold to complete)
}

enum Biomes {
    static let park = Biome(
        groundA: SKColor(red: 0.46, green: 0.75, blue: 0.43, alpha: 1),
        groundB: SKColor(red: 0.40, green: 0.69, blue: 0.39, alpha: 1),
        pathColor: SKColor(red: 0.87, green: 0.79, blue: 0.59, alpha: 1),
        borderColor: SKColor(red: 0.30, green: 0.52, blue: 0.30, alpha: 1),
        coverFill: SKColor(red: 0.27, green: 0.55, blue: 0.30, alpha: 1),
        coverDetail: SKColor(red: 0.36, green: 0.66, blue: 0.38, alpha: 1),
        treeFill: SKColor(red: 0.22, green: 0.48, blue: 0.27, alpha: 1),
        buildingWall: SKColor(red: 0.95, green: 0.92, blue: 0.86, alpha: 1),
        signColor: SKColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1),
        ambientColor: SKColor(red: 1.0, green: 0.95, blue: 0.7, alpha: 1),
        ambientAlpha: 0.0,
        accent: Palette.crystal,
        coverShape: .bush,
        ambientFX: .none,
        vignette: 0.16)

    static let docks = Biome(
        groundA: SKColor(red: 0.34, green: 0.40, blue: 0.50, alpha: 1),
        groundB: SKColor(red: 0.29, green: 0.35, blue: 0.45, alpha: 1),
        pathColor: SKColor(red: 0.52, green: 0.53, blue: 0.57, alpha: 1),
        borderColor: SKColor(red: 0.20, green: 0.24, blue: 0.32, alpha: 1),
        coverFill: SKColor(red: 0.55, green: 0.40, blue: 0.24, alpha: 1),
        coverDetail: SKColor(red: 0.66, green: 0.49, blue: 0.30, alpha: 1),
        treeFill: SKColor(red: 0.20, green: 0.36, blue: 0.34, alpha: 1),
        buildingWall: SKColor(red: 0.46, green: 0.50, blue: 0.56, alpha: 1),
        signColor: SKColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1),
        ambientColor: SKColor(red: 0.45, green: 0.28, blue: 0.42, alpha: 1),
        ambientAlpha: 0.30,
        accent: SKColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1),
        coverShape: .crate,
        ambientFX: .fireflies,
        vignette: 0.34)

    static let highway = Biome(
        groundA: SKColor(red: 0.28, green: 0.30, blue: 0.34, alpha: 1),
        groundB: SKColor(red: 0.25, green: 0.27, blue: 0.31, alpha: 1),
        pathColor: SKColor(red: 0.20, green: 0.21, blue: 0.24, alpha: 1),
        borderColor: SKColor(red: 0.40, green: 0.62, blue: 0.40, alpha: 1),
        coverFill: SKColor(red: 0.30, green: 0.55, blue: 0.32, alpha: 1),
        coverDetail: SKColor(red: 0.40, green: 0.66, blue: 0.42, alpha: 1),
        treeFill: SKColor(red: 0.24, green: 0.50, blue: 0.28, alpha: 1),
        buildingWall: SKColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1),
        signColor: SKColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1),
        ambientColor: SKColor(red: 0.5, green: 0.7, blue: 1.0, alpha: 1),
        ambientAlpha: 0.0,
        accent: SKColor(red: 1.0, green: 0.78, blue: 0.2, alpha: 1),
        coverShape: .bush,
        ambientFX: .none,
        vignette: 0.22)

    static let rooftops = Biome(
        groundA: SKColor(red: 0.26, green: 0.28, blue: 0.36, alpha: 1),
        groundB: SKColor(red: 0.22, green: 0.24, blue: 0.32, alpha: 1),
        pathColor: SKColor(red: 0.32, green: 0.34, blue: 0.44, alpha: 1),
        borderColor: SKColor(red: 0.12, green: 0.13, blue: 0.20, alpha: 1),
        coverFill: SKColor(red: 0.40, green: 0.42, blue: 0.50, alpha: 1),
        coverDetail: SKColor(red: 0.52, green: 0.54, blue: 0.62, alpha: 1),
        treeFill: SKColor(red: 0.30, green: 0.34, blue: 0.30, alpha: 1),
        buildingWall: SKColor(red: 0.34, green: 0.36, blue: 0.46, alpha: 1),
        signColor: SKColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 1),
        ambientColor: SKColor(red: 0.10, green: 0.10, blue: 0.26, alpha: 1),
        ambientAlpha: 0.40,
        accent: SKColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 1),
        coverShape: .crate,
        ambientFX: .fireflies,
        vignette: 0.4)

    static let lab = Biome(
        groundA: SKColor(red: 0.86, green: 0.90, blue: 0.92, alpha: 1),
        groundB: SKColor(red: 0.80, green: 0.85, blue: 0.88, alpha: 1),
        pathColor: SKColor(red: 0.72, green: 0.82, blue: 0.86, alpha: 1),
        borderColor: SKColor(red: 0.30, green: 0.55, blue: 0.62, alpha: 1),
        coverFill: SKColor(red: 0.62, green: 0.72, blue: 0.80, alpha: 1),
        coverDetail: SKColor(red: 0.40, green: 0.80, blue: 0.85, alpha: 1),
        treeFill: SKColor(red: 0.55, green: 0.72, blue: 0.70, alpha: 1),
        buildingWall: SKColor(red: 0.92, green: 0.95, blue: 0.97, alpha: 1),
        signColor: SKColor(red: 0.20, green: 0.62, blue: 0.72, alpha: 1),
        ambientColor: SKColor(red: 0.7, green: 0.95, blue: 1.0, alpha: 1),
        ambientAlpha: 0.0,
        accent: SKColor(red: 0.10, green: 0.70, blue: 0.78, alpha: 1),
        coverShape: .pillar,
        ambientFX: .none,
        vignette: 0.18)

    static let sewers = Biome(
        groundA: SKColor(red: 0.22, green: 0.28, blue: 0.24, alpha: 1),
        groundB: SKColor(red: 0.18, green: 0.24, blue: 0.20, alpha: 1),
        pathColor: SKColor(red: 0.26, green: 0.30, blue: 0.26, alpha: 1),
        borderColor: SKColor(red: 0.10, green: 0.14, blue: 0.12, alpha: 1),
        coverFill: SKColor(red: 0.36, green: 0.34, blue: 0.28, alpha: 1),
        coverDetail: SKColor(red: 0.46, green: 0.44, blue: 0.36, alpha: 1),
        treeFill: SKColor(red: 0.24, green: 0.32, blue: 0.26, alpha: 1),
        buildingWall: SKColor(red: 0.32, green: 0.34, blue: 0.30, alpha: 1),
        signColor: SKColor(red: 0.55, green: 0.85, blue: 0.40, alpha: 1),
        ambientColor: SKColor(red: 0.06, green: 0.14, blue: 0.10, alpha: 1),
        ambientAlpha: 0.42,
        accent: SKColor(red: 0.55, green: 0.90, blue: 0.45, alpha: 1),
        coverShape: .crate,
        ambientFX: .none,
        vignette: 0.46)

    static let harbor = Biome(
        groundA: SKColor(red: 0.30, green: 0.50, blue: 0.66, alpha: 1),
        groundB: SKColor(red: 0.26, green: 0.45, blue: 0.60, alpha: 1),
        pathColor: SKColor(red: 0.38, green: 0.60, blue: 0.78, alpha: 1),
        borderColor: SKColor(red: 0.18, green: 0.30, blue: 0.42, alpha: 1),
        coverFill: SKColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 1),
        coverDetail: SKColor(red: 0.66, green: 0.50, blue: 0.32, alpha: 1),
        treeFill: SKColor(red: 0.22, green: 0.40, blue: 0.40, alpha: 1),
        buildingWall: SKColor(red: 0.50, green: 0.55, blue: 0.60, alpha: 1),
        signColor: SKColor(red: 1.0, green: 0.62, blue: 0.25, alpha: 1),
        ambientColor: SKColor(red: 0.55, green: 0.35, blue: 0.45, alpha: 1),
        ambientAlpha: 0.22,
        accent: SKColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 1),
        coverShape: .crate,
        ambientFX: .none,
        vignette: 0.3)

    static let fortress = Biome(
        groundA: SKColor(red: 0.24, green: 0.14, blue: 0.20, alpha: 1),
        groundB: SKColor(red: 0.19, green: 0.11, blue: 0.16, alpha: 1),
        pathColor: SKColor(red: 0.34, green: 0.18, blue: 0.26, alpha: 1),
        borderColor: SKColor(red: 0.12, green: 0.06, blue: 0.10, alpha: 1),
        coverFill: SKColor(red: 0.32, green: 0.18, blue: 0.28, alpha: 1),
        coverDetail: SKColor(red: 0.85, green: 0.30, blue: 0.55, alpha: 1),
        treeFill: SKColor(red: 0.26, green: 0.14, blue: 0.22, alpha: 1),
        buildingWall: SKColor(red: 0.30, green: 0.16, blue: 0.26, alpha: 1),
        signColor: SKColor(red: 1.0, green: 0.35, blue: 0.55, alpha: 1),
        ambientColor: SKColor(red: 0.12, green: 0.02, blue: 0.10, alpha: 1),
        ambientAlpha: 0.22,
        accent: SKColor(red: 1.0, green: 0.40, blue: 0.70, alpha: 1),
        coverShape: .pillar,
        ambientFX: .sparks,
        vignette: 0.28)

    static let tower = Biome(
        groundA: SKColor(red: 0.21, green: 0.18, blue: 0.32, alpha: 1),
        groundB: SKColor(red: 0.16, green: 0.14, blue: 0.27, alpha: 1),
        pathColor: SKColor(red: 0.33, green: 0.26, blue: 0.48, alpha: 1),
        borderColor: SKColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1),
        coverFill: SKColor(red: 0.26, green: 0.23, blue: 0.42, alpha: 1),
        coverDetail: SKColor(red: 0.40, green: 0.32, blue: 0.62, alpha: 1),
        treeFill: SKColor(red: 0.22, green: 0.18, blue: 0.36, alpha: 1),
        buildingWall: SKColor(red: 0.24, green: 0.21, blue: 0.36, alpha: 1),
        signColor: SKColor(red: 0.85, green: 0.30, blue: 0.85, alpha: 1),
        ambientColor: SKColor(red: 0.05, green: 0.04, blue: 0.16, alpha: 1),
        ambientAlpha: 0.46,
        accent: SKColor(red: 0.30, green: 0.95, blue: 1.0, alpha: 1),
        coverShape: .pillar,
        ambientFX: .sparks,
        vignette: 0.5)
}

enum Levels {
    // Ordered so difficulty only climbs: enemy speed/range, patrol count and crystal targets rise
    // monotonically, and each level introduces at most one or two new mechanics.
    static let all: [LevelData] = [level1, chase, level2, lab, sewers, rooftops, harbor, level3, gauntlet, powerplant, fortress]

    /// Free-roam home town (not part of the playable progression).
    static let hub = LevelData(
        index: 0,
        name: "Hero City",
        subtitle: "Your home base.",
        biome: Biomes.park,
        worldSize: CGSize(width: 1900, height: 1500),
        heroSpawn: CGPoint(x: 950, y: 880),
        corePos: nil,
        exitPos: CGPoint(x: 950, y: 1150),
        crystalsRequired: 0,
        crystalSpots: [],
        minionPatrols: [],
        minionSpeed: 0, minionRange: 0,
        coverSpots: [],
        treeSpots: [CGPoint(x: 300, y: 500), CGPoint(x: 1600, y: 500), CGPoint(x: 250, y: 1100),
                    CGPoint(x: 1650, y: 1150), CGPoint(x: 700, y: 300), CGPoint(x: 1200, y: 320)],
        buildings: [],
        signs: [("WELCOME TO HERO CITY", CGPoint(x: 950, y: 380))],
        npcs: [
            NPCSpec(id: "mayor", name: "Mayor Mia", pos: CGPoint(x: 700, y: 700), tint: Palette.heroRed),
            NPCSpec(id: "gran", name: "Granny Gold", pos: CGPoint(x: 1250, y: 760),
                    tint: SKColor(red: 0.8, green: 0.6, blue: 0.85, alpha: 1)),
            NPCSpec(id: "tommy", name: "Tommy", pos: CGPoint(x: 950, y: 1000),
                    tint: SKColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1))
        ],
        hasBoss: false,
        objective: "",
        exitLabel: "MISSIONS",
        coinSpots: [CGPoint(x: 400, y: 600), CGPoint(x: 1500, y: 620), CGPoint(x: 350, y: 950),
                    CGPoint(x: 1550, y: 980), CGPoint(x: 700, y: 1050), CGPoint(x: 1200, y: 1080),
                    CGPoint(x: 600, y: 450), CGPoint(x: 1300, y: 470)],
        isHub: true)

    static let level1 = LevelData(
        index: 1,
        name: "Sunnyside Park",
        subtitle: "Lord Chow-Chow stole the city's Energy Crystals!",
        biome: Biomes.park,
        worldSize: CGSize(width: 2600, height: 1800),
        heroSpawn: CGPoint(x: 460, y: 900),
        corePos: CGPoint(x: 2300, y: 520),     // near the exit: no cross-map backtrack
        exitPos: CGPoint(x: 2420, y: 900),
        crystalsRequired: 4,
        crystalSpots: [
            CGPoint(x: 1650, y: 1050), CGPoint(x: 1950, y: 1320),
            CGPoint(x: 2250, y: 1000), CGPoint(x: 2080, y: 680),
            CGPoint(x: 1800, y: 1500), CGPoint(x: 2380, y: 1380)
        ],
        minionPatrols: [
            [CGPoint(x: 1600, y: 950), CGPoint(x: 1600, y: 1400)],
            [CGPoint(x: 1950, y: 1150), CGPoint(x: 2300, y: 1150)],
            [CGPoint(x: 2200, y: 760), CGPoint(x: 2200, y: 1250)]
        ],
        minionSpeed: 65, minionRange: 145,
        coverSpots: [
            CGPoint(x: 1750, y: 1150), CGPoint(x: 2020, y: 1220), CGPoint(x: 2180, y: 920),
            CGPoint(x: 1900, y: 760), CGPoint(x: 2300, y: 1320), CGPoint(x: 1680, y: 1350)
        ],
        treeSpots: [
            CGPoint(x: 300, y: 1400), CGPoint(x: 700, y: 650), CGPoint(x: 950, y: 1500),
            CGPoint(x: 1200, y: 560), CGPoint(x: 1350, y: 1300), CGPoint(x: 560, y: 1150)
        ],
        buildings: [
            BuildingSpec(pos: CGPoint(x: 320, y: 1120), size: CGSize(width: 200, height: 150),
                         roof: SKColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1), label: "HQ"),
            BuildingSpec(pos: CGPoint(x: 720, y: 1440), size: CGSize(width: 150, height: 120),
                         roof: SKColor(red: 0.80, green: 0.45, blue: 0.40, alpha: 1), label: nil),
            BuildingSpec(pos: CGPoint(x: 980, y: 1440), size: CGSize(width: 150, height: 120),
                         roof: SKColor(red: 0.55, green: 0.70, blue: 0.40, alpha: 1), label: nil)
        ],
        signs: [("TOWN SQUARE", CGPoint(x: 760, y: 1230)), ("⚡ STATIC ZONE ⚡", CGPoint(x: 2000, y: 1620))],
        npcs: [
            NPCSpec(id: "mayor", name: "Mayor Mia", pos: CGPoint(x: 720, y: 1160), tint: Palette.heroRed),
            NPCSpec(id: "kid", name: "Tommy", pos: CGPoint(x: 980, y: 1060),
                    tint: SKColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1)),
            NPCSpec(id: "gran", name: "Granny Gold", pos: CGPoint(x: 560, y: 1300),
                    tint: SKColor(red: 0.8, green: 0.6, blue: 0.85, alpha: 1))
        ],
        hasBoss: false,
        objective: "Recover 4 Crystals, then charge the Core",
        exitLabel: "EXIT",
        coinSpots: [CGPoint(x: 800, y: 900), CGPoint(x: 1100, y: 980), CGPoint(x: 1380, y: 880)])

    static let chase = LevelData(
        index: 2,
        name: "Highway Chase",
        subtitle: "Lord Chow-Chow is escaping by truck — chase him down!",
        biome: Biomes.highway,
        worldSize: CGSize(width: 760, height: 11000),
        heroSpawn: CGPoint(x: 380, y: 320),
        corePos: nil,
        exitPos: CGPoint(x: 380, y: 1040),   // truck's starting lead
        crystalsRequired: 0,
        crystalSpots: [],
        minionPatrols: [],
        minionSpeed: 0, minionRange: 0,
        coverSpots: [],
        treeSpots: [],
        buildings: [],
        signs: [],
        npcs: [],
        hasBoss: false,
        objective: "Catch the truck — dodge traffic!",
        exitLabel: "CATCH",
        isDriving: true)

    static let level2 = LevelData(
        index: 3,
        name: "Static Docks",
        subtitle: "Chow-Chow locked up the dock crew — sneak in and free them.",
        biome: Biomes.docks,
        worldSize: CGSize(width: 2800, height: 1900),
        heroSpawn: CGPoint(x: 360, y: 950),
        corePos: nil,
        exitPos: CGPoint(x: 2600, y: 1500),
        crystalsRequired: 4,
        crystalSpots: [],
        minionPatrols: [
            [CGPoint(x: 1100, y: 600), CGPoint(x: 1100, y: 1300)],
            [CGPoint(x: 1450, y: 900), CGPoint(x: 1900, y: 900)],
            [CGPoint(x: 2000, y: 1200), CGPoint(x: 2000, y: 1600)],
            [CGPoint(x: 2300, y: 800), CGPoint(x: 2600, y: 800), CGPoint(x: 2600, y: 1300)]
        ],
        minionSpeed: 80, minionRange: 155,
        coverSpots: [
            CGPoint(x: 1150, y: 850), CGPoint(x: 1400, y: 1150), CGPoint(x: 1700, y: 700),
            CGPoint(x: 1950, y: 1000), CGPoint(x: 2150, y: 1300), CGPoint(x: 2400, y: 850),
            CGPoint(x: 2250, y: 1550), CGPoint(x: 1600, y: 1250), CGPoint(x: 1900, y: 1500)
        ],
        treeSpots: [CGPoint(x: 500, y: 700), CGPoint(x: 650, y: 1300), CGPoint(x: 850, y: 600)],
        buildings: [
            BuildingSpec(pos: CGPoint(x: 300, y: 1180), size: CGSize(width: 220, height: 170),
                         roof: SKColor(red: 0.40, green: 0.44, blue: 0.50, alpha: 1), label: "DEPOT"),
            BuildingSpec(pos: CGPoint(x: 1500, y: 500), size: CGSize(width: 260, height: 150),
                         roof: SKColor(red: 0.46, green: 0.40, blue: 0.36, alpha: 1), label: nil),
            BuildingSpec(pos: CGPoint(x: 2500, y: 1750), size: CGSize(width: 240, height: 150),
                         roof: SKColor(red: 0.42, green: 0.46, blue: 0.52, alpha: 1), label: nil)
        ],
        signs: [("⚓ STATIC DOCKS", CGPoint(x: 760, y: 760)), ("DANGER", CGPoint(x: 2000, y: 1720))],
        npcs: [],
        hasBoss: false,
        objective: "Free 4 dock workers from the cages",
        exitLabel: "FERRY",
        coinSpots: [CGPoint(x: 700, y: 1250), CGPoint(x: 1350, y: 1550), CGPoint(x: 2350, y: 1100)],
        mission: .rescue,
        siteSpots: [CGPoint(x: 1200, y: 700), CGPoint(x: 1850, y: 800), CGPoint(x: 2050, y: 1450), CGPoint(x: 2500, y: 700)])

    static let level3 = LevelData(
        index: 8,
        name: "Static Tower",
        subtitle: "Climb his tower — but Chow-Chow slips away downtown!",
        biome: Biomes.tower,
        worldSize: CGSize(width: 2500, height: 2000),
        heroSpawn: CGPoint(x: 1250, y: 320),
        corePos: nil,
        exitPos: CGPoint(x: 1250, y: 1700),
        crystalsRequired: 3,
        crystalSpots: [],
        minionPatrols: [
            [CGPoint(x: 700, y: 700), CGPoint(x: 700, y: 1400)],
            [CGPoint(x: 1800, y: 700), CGPoint(x: 1800, y: 1400)],
            [CGPoint(x: 900, y: 1050), CGPoint(x: 1600, y: 1050)],
            [CGPoint(x: 1250, y: 600), CGPoint(x: 1250, y: 1300)]
        ],
        minionSpeed: 100, minionRange: 180,
        coverSpots: [
            CGPoint(x: 750, y: 950), CGPoint(x: 1750, y: 950), CGPoint(x: 750, y: 1200),
            CGPoint(x: 1750, y: 1200), CGPoint(x: 1050, y: 800), CGPoint(x: 1450, y: 800),
            CGPoint(x: 1050, y: 1300), CGPoint(x: 1450, y: 1300)
        ],
        treeSpots: [],
        buildings: [
            BuildingSpec(pos: CGPoint(x: 1250, y: 1820), size: CGSize(width: 360, height: 200),
                         roof: SKColor(red: 0.32, green: 0.22, blue: 0.45, alpha: 1), label: "LAIR")
        ],
        signs: [("⚡ STATIC TOWER ⚡", CGPoint(x: 1250, y: 200))],
        npcs: [],
        hasBoss: false,
        objective: "Rescue Mia, Granny Gold & Tommy",
        exitLabel: "TOP",
        coinSpots: [CGPoint(x: 800, y: 1050), CGPoint(x: 1700, y: 1050), CGPoint(x: 1250, y: 700)],
        searchlights: [CGPoint(x: 1000, y: 700), CGPoint(x: 1500, y: 1400)],
        starSpots: [CGPoint(x: 1250, y: 1300)],
        hazardSpots: [CGPoint(x: 1100, y: 1000), CGPoint(x: 1650, y: 1300)],
        mission: .rescue,
        siteSpots: [CGPoint(x: 600, y: 800), CGPoint(x: 1900, y: 800), CGPoint(x: 1250, y: 1050)])

    // MARK: Expansion levels

    static let rooftops = LevelData(
        index: 6,
        name: "City Rooftops",
        subtitle: "Chase the trail across the neon skyline — drones are watching.",
        biome: Biomes.rooftops,
        worldSize: CGSize(width: 2600, height: 1900),
        heroSpawn: CGPoint(x: 320, y: 950),
        corePos: nil,
        exitPos: CGPoint(x: 2420, y: 950),
        crystalsRequired: 4,
        crystalSpots: [CGPoint(x: 1100, y: 700), CGPoint(x: 1500, y: 1300), CGPoint(x: 1900, y: 800),
                       CGPoint(x: 2150, y: 1350), CGPoint(x: 1700, y: 1050)],
        minionPatrols: [[CGPoint(x: 1200, y: 600), CGPoint(x: 1200, y: 1350)],
                        [CGPoint(x: 1700, y: 700), CGPoint(x: 2100, y: 700)],
                        [CGPoint(x: 1900, y: 1300), CGPoint(x: 2300, y: 1300)]],
        minionSpeed: 95, minionRange: 175,
        coverSpots: [CGPoint(x: 1150, y: 900), CGPoint(x: 1450, y: 1050), CGPoint(x: 1750, y: 900),
                     CGPoint(x: 2000, y: 1100), CGPoint(x: 1300, y: 700), CGPoint(x: 2200, y: 1000)],
        treeSpots: [],
        buildings: [BuildingSpec(pos: CGPoint(x: 320, y: 1180), size: CGSize(width: 200, height: 150),
                                 roof: SKColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 1), label: "ROOF")],
        signs: [("🏙 ROOFTOPS", CGPoint(x: 700, y: 1250))],
        npcs: [],
        hasBoss: false,
        objective: "Find 4 Crystals + a keycard to ESCAPE",
        exitLabel: "ESCAPE",
        coinSpots: [CGPoint(x: 900, y: 800), CGPoint(x: 1300, y: 1200), CGPoint(x: 1650, y: 700),
                    CGPoint(x: 2050, y: 1250), CGPoint(x: 2250, y: 800), CGPoint(x: 1500, y: 950)],
        searchlights: [CGPoint(x: 1400, y: 1500), CGPoint(x: 2000, y: 600), CGPoint(x: 1750, y: 1450)],
        keycardPos: CGPoint(x: 1950, y: 1550),
        dronesStyle: true,
        grappleAnchors: [CGPoint(x: 1400, y: 1100), CGPoint(x: 2000, y: 1000), CGPoint(x: 1700, y: 1500)])

    static let lab = LevelData(
        index: 4,
        name: "Secret Lab",
        subtitle: "Slip past the laser grid to the crystal vault.",
        biome: Biomes.lab,
        worldSize: CGSize(width: 2600, height: 1800),
        heroSpawn: CGPoint(x: 300, y: 900),
        corePos: nil,
        exitPos: CGPoint(x: 2420, y: 900),
        crystalsRequired: 5,
        crystalSpots: [CGPoint(x: 900, y: 650), CGPoint(x: 1300, y: 1150), CGPoint(x: 1700, y: 700),
                       CGPoint(x: 2050, y: 1200), CGPoint(x: 1500, y: 900), CGPoint(x: 2200, y: 750)],
        minionPatrols: [[CGPoint(x: 1100, y: 600), CGPoint(x: 1100, y: 1250)],
                        [CGPoint(x: 1900, y: 700), CGPoint(x: 1900, y: 1250)]],
        minionSpeed: 85, minionRange: 160,
        coverSpots: [CGPoint(x: 1000, y: 900), CGPoint(x: 1400, y: 750), CGPoint(x: 1750, y: 1050),
                     CGPoint(x: 2100, y: 950), CGPoint(x: 1300, y: 1300)],
        treeSpots: [],
        buildings: [BuildingSpec(pos: CGPoint(x: 300, y: 1150), size: CGSize(width: 210, height: 160),
                                 roof: SKColor(red: 0.20, green: 0.62, blue: 0.72, alpha: 1), label: "LAB")],
        signs: [("🔬 SECRET LAB", CGPoint(x: 700, y: 1200))],
        npcs: [],
        hasBoss: false,
        objective: "Get 5 Crystals past the lasers",
        exitLabel: "VAULT",
        coinSpots: [CGPoint(x: 650, y: 1250), CGPoint(x: 1250, y: 450), CGPoint(x: 2300, y: 1400)],
        laserGates: [CGPoint(x: 1200, y: 1000), CGPoint(x: 1600, y: 1300), CGPoint(x: 1900, y: 700),
                     CGPoint(x: 2200, y: 1100)],
        // Introduces lasers (+ a magnet helper). Water, grapple and traps come later.
        speedPads: [CGPoint(x: 800, y: 900), CGPoint(x: 1600, y: 600), CGPoint(x: 2000, y: 1300)],
        magnetSpots: [CGPoint(x: 1250, y: 600)])

    static let sewers = LevelData(
        index: 5,
        name: "Flooded Sewers",
        subtitle: "Every pump you shut off drains a flooded tunnel.",
        biome: Biomes.sewers,
        worldSize: CGSize(width: 2600, height: 1900),
        heroSpawn: CGPoint(x: 300, y: 950),
        corePos: nil,
        exitPos: CGPoint(x: 2420, y: 950),
        crystalsRequired: 3,
        crystalSpots: [],
        minionPatrols: [[CGPoint(x: 1100, y: 650), CGPoint(x: 1100, y: 1300)],
                        [CGPoint(x: 1550, y: 800), CGPoint(x: 2000, y: 800)],
                        [CGPoint(x: 1900, y: 1300), CGPoint(x: 2300, y: 1300)]],
        minionSpeed: 90, minionRange: 165,
        coverSpots: [CGPoint(x: 1050, y: 950), CGPoint(x: 1450, y: 1050), CGPoint(x: 1800, y: 1050),
                     CGPoint(x: 2150, y: 1000), CGPoint(x: 1300, y: 750)],
        treeSpots: [],
        buildings: [BuildingSpec(pos: CGPoint(x: 300, y: 1180), size: CGSize(width: 200, height: 150),
                                 roof: SKColor(red: 0.30, green: 0.45, blue: 0.30, alpha: 1), label: "PUMP")],
        signs: [("🕳 SEWERS", CGPoint(x: 700, y: 1250))],
        npcs: [],
        hasBoss: false,
        objective: "Shut off 3 pumps to drain the sewers",
        exitLabel: "GRATE",
        coinSpots: [CGPoint(x: 900, y: 1100), CGPoint(x: 1500, y: 700), CGPoint(x: 1950, y: 1150),
                    CGPoint(x: 2250, y: 1100)],
        starSpots: [CGPoint(x: 1300, y: 1350)],
        waterRects: [CGRect(x: 700, y: 800, width: 500, height: 280),
                     CGRect(x: 1700, y: 1050, width: 520, height: 300)],
        dronesStyle: true,
        grappleAnchors: [CGPoint(x: 950, y: 1250), CGPoint(x: 1500, y: 700), CGPoint(x: 1960, y: 1450)],
        mission: .sabotage,
        siteSpots: [CGPoint(x: 1000, y: 700), CGPoint(x: 1800, y: 750), CGPoint(x: 2100, y: 1300)])

    static let harbor = LevelData(
        index: 7,
        name: "Harbor Boat Chase",
        subtitle: "He's switched to a speedboat — give chase across the bay!",
        biome: Biomes.harbor,
        worldSize: CGSize(width: 760, height: 11000),
        heroSpawn: CGPoint(x: 380, y: 320),
        corePos: nil,
        exitPos: CGPoint(x: 380, y: 1040),
        crystalsRequired: 0,
        crystalSpots: [],
        minionPatrols: [],
        minionSpeed: 0, minionRange: 0,
        coverSpots: [],
        treeSpots: [],
        buildings: [],
        signs: [],
        npcs: [],
        hasBoss: false,
        objective: "Chase the speedboat — dodge barges!",
        exitLabel: "CATCH",
        isDriving: true,
        isBoat: true)

    static let fortress = LevelData(
        index: 11,
        name: "Chow-Chow's Fortress",
        subtitle: "The final battle. Power up and end this!",
        biome: Biomes.fortress,
        worldSize: CGSize(width: 2600, height: 2100),
        heroSpawn: CGPoint(x: 1300, y: 320),
        corePos: nil,
        exitPos: CGPoint(x: 1300, y: 1750),
        crystalsRequired: 4,
        crystalSpots: [CGPoint(x: 600, y: 800), CGPoint(x: 2000, y: 800), CGPoint(x: 600, y: 1350),
                       CGPoint(x: 2000, y: 1350), CGPoint(x: 1300, y: 1050)],
        minionPatrols: [[CGPoint(x: 750, y: 700), CGPoint(x: 750, y: 1450)],
                        [CGPoint(x: 1850, y: 700), CGPoint(x: 1850, y: 1450)],
                        [CGPoint(x: 950, y: 1050), CGPoint(x: 1650, y: 1050)],
                        [CGPoint(x: 1300, y: 600), CGPoint(x: 1300, y: 1350)]],
        minionSpeed: 120, minionRange: 195,
        coverSpots: [CGPoint(x: 800, y: 950), CGPoint(x: 1800, y: 950), CGPoint(x: 800, y: 1250),
                     CGPoint(x: 1800, y: 1250), CGPoint(x: 1100, y: 800), CGPoint(x: 1500, y: 800)],
        treeSpots: [],
        buildings: [BuildingSpec(pos: CGPoint(x: 1300, y: 1920), size: CGSize(width: 400, height: 220),
                                 roof: SKColor(red: 0.40, green: 0.16, blue: 0.30, alpha: 1), label: "FORTRESS")],
        signs: [("⚡ THE FORTRESS ⚡", CGPoint(x: 1300, y: 200))],
        npcs: [],
        hasBoss: true,
        objective: "Get 4 Crystals, then beat Chow-Chow!",
        exitLabel: "BOSS",
        coinSpots: [CGPoint(x: 750, y: 1050), CGPoint(x: 1850, y: 1050), CGPoint(x: 1100, y: 1300),
                    CGPoint(x: 1500, y: 1300)],
        starSpots: [CGPoint(x: 1300, y: 1450)],
        bossPhases: 3)

    // MARK: Big complex scenarios

    static let gauntlet = LevelData(
        index: 9,
        name: "Downtown Gauntlet",
        subtitle: "A sprawling night-city run: lasers, drones, searchlights — find the keycard!",
        biome: Biomes.rooftops,
        worldSize: CGSize(width: 3400, height: 2400),
        heroSpawn: CGPoint(x: 300, y: 1200),
        corePos: nil,
        exitPos: CGPoint(x: 3120, y: 1200),
        crystalsRequired: 7,
        crystalSpots: [CGPoint(x: 900, y: 700), CGPoint(x: 1300, y: 1700), CGPoint(x: 1700, y: 600),
                       CGPoint(x: 1900, y: 1900), CGPoint(x: 2300, y: 900), CGPoint(x: 2600, y: 1700),
                       CGPoint(x: 2900, y: 600), CGPoint(x: 1500, y: 1100)],
        minionPatrols: [[CGPoint(x: 1000, y: 500), CGPoint(x: 1000, y: 1900)],
                        [CGPoint(x: 1400, y: 900), CGPoint(x: 2000, y: 900)],
                        [CGPoint(x: 1800, y: 1400), CGPoint(x: 1800, y: 2000)],
                        [CGPoint(x: 2200, y: 600), CGPoint(x: 2800, y: 600)],
                        [CGPoint(x: 2500, y: 1300), CGPoint(x: 2500, y: 1900)],
                        [CGPoint(x: 2900, y: 900), CGPoint(x: 2900, y: 1700)]],
        minionSpeed: 110, minionRange: 185,
        coverSpots: [CGPoint(x: 950, y: 950), CGPoint(x: 1350, y: 1300), CGPoint(x: 1700, y: 900),
                     CGPoint(x: 2050, y: 1500), CGPoint(x: 2350, y: 1150), CGPoint(x: 2650, y: 1400),
                     CGPoint(x: 1550, y: 1850), CGPoint(x: 2850, y: 1000), CGPoint(x: 1200, y: 600)],
        treeSpots: [],
        buildings: [BuildingSpec(pos: CGPoint(x: 300, y: 1480), size: CGSize(width: 220, height: 170),
                                 roof: SKColor(red: 0.30, green: 0.85, blue: 0.95, alpha: 1), label: "START")],
        signs: [("🏙 DOWNTOWN", CGPoint(x: 700, y: 1500)), ("DANGER ZONE", CGPoint(x: 2600, y: 2100))],
        npcs: [],
        hasBoss: false,
        objective: "Recover 7 Crystals + keycard, reach the EXIT",
        exitLabel: "EXIT",
        coinSpots: [CGPoint(x: 1100, y: 1500), CGPoint(x: 1600, y: 800), CGPoint(x: 2100, y: 1100),
                    CGPoint(x: 2400, y: 1700), CGPoint(x: 2750, y: 800), CGPoint(x: 1900, y: 1300),
                    CGPoint(x: 1350, y: 600), CGPoint(x: 3000, y: 1400)],
        searchlights: [CGPoint(x: 1500, y: 1500), CGPoint(x: 2100, y: 700), CGPoint(x: 2700, y: 1300),
                       CGPoint(x: 1900, y: 1000)],
        laserGates: [CGPoint(x: 1600, y: 1200), CGPoint(x: 2200, y: 1500), CGPoint(x: 2800, y: 1000)],
        speedPads: [CGPoint(x: 800, y: 1200), CGPoint(x: 2000, y: 1700)],
        waterRects: [CGRect(x: 1250, y: 850, width: 320, height: 240)],
        keycardPos: CGPoint(x: 2950, y: 1950),
        dronesStyle: true,
        grappleAnchors: [CGPoint(x: 1200, y: 1100), CGPoint(x: 1900, y: 1100),
                         CGPoint(x: 2500, y: 1100), CGPoint(x: 2900, y: 1100)],
        hazardSpots: [CGPoint(x: 1300, y: 1000), CGPoint(x: 2100, y: 900), CGPoint(x: 2600, y: 1560)])

    static let powerplant = LevelData(
        index: 10,
        name: "The Power Plant",
        subtitle: "The reactor powering his fortress. Each generator you cut kills nearby lasers.",
        biome: Biomes.tower,
        worldSize: CGSize(width: 3200, height: 2400),
        heroSpawn: CGPoint(x: 300, y: 1200),
        corePos: nil,
        exitPos: CGPoint(x: 2950, y: 1200),
        crystalsRequired: 4,
        crystalSpots: [],
        minionPatrols: [[CGPoint(x: 900, y: 500), CGPoint(x: 900, y: 1900)],
                        [CGPoint(x: 1400, y: 1000), CGPoint(x: 1900, y: 1000)],
                        [CGPoint(x: 1700, y: 1400), CGPoint(x: 1700, y: 2000)],
                        [CGPoint(x: 2100, y: 600), CGPoint(x: 2100, y: 1500)],
                        [CGPoint(x: 2500, y: 900), CGPoint(x: 2900, y: 900)],
                        [CGPoint(x: 2600, y: 1500), CGPoint(x: 2600, y: 2000)]],
        minionSpeed: 115, minionRange: 190,
        coverSpots: [CGPoint(x: 900, y: 950), CGPoint(x: 1300, y: 1300), CGPoint(x: 1650, y: 1000),
                     CGPoint(x: 2000, y: 1450), CGPoint(x: 2350, y: 1100), CGPoint(x: 2650, y: 1450),
                     CGPoint(x: 1500, y: 1850), CGPoint(x: 2800, y: 950), CGPoint(x: 1150, y: 650)],
        treeSpots: [],
        buildings: [BuildingSpec(pos: CGPoint(x: 300, y: 1480), size: CGSize(width: 220, height: 170),
                                 roof: SKColor(red: 0.30, green: 0.95, blue: 1.0, alpha: 1), label: "ENTRY")],
        signs: [("⚛ POWER PLANT", CGPoint(x: 700, y: 1500)), ("HIGH VOLTAGE", CGPoint(x: 2400, y: 2100))],
        npcs: [],
        hasBoss: false,
        objective: "Shut down 4 generators to kill the lasers",
        exitLabel: "CORE",
        coinSpots: [CGPoint(x: 1100, y: 900), CGPoint(x: 1500, y: 1500), CGPoint(x: 1900, y: 700),
                    CGPoint(x: 2200, y: 1400), CGPoint(x: 2500, y: 800), CGPoint(x: 2750, y: 1600)],
        laserGates: [CGPoint(x: 1300, y: 900), CGPoint(x: 1300, y: 1500), CGPoint(x: 1900, y: 1200),
                     CGPoint(x: 2300, y: 900), CGPoint(x: 2300, y: 1500), CGPoint(x: 2700, y: 1200)],
        magnetSpots: [CGPoint(x: 1000, y: 1700)],
        starSpots: [CGPoint(x: 2300, y: 1150)],
        hazardSpots: [CGPoint(x: 1000, y: 1150), CGPoint(x: 1700, y: 1000), CGPoint(x: 2400, y: 1500)],
        mission: .sabotage,
        siteSpots: [CGPoint(x: 1600, y: 650), CGPoint(x: 1600, y: 1750), CGPoint(x: 2300, y: 700), CGPoint(x: 2300, y: 1700)])
}
