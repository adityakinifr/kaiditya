import SpriteKit

/// Cosmetic hero costumes (suit + cape colors).
enum Costume: String, CaseIterable {
    case classic, crimson, emerald, shadow, gold

    var name: String {
        switch self {
        case .classic: return "Classic"
        case .crimson: return "Crimson"
        case .emerald: return "Emerald"
        case .shadow:  return "Shadow"
        case .gold:    return "Golden"
        }
    }
    var price: Int {
        switch self {
        case .classic: return 0
        case .crimson: return 10
        case .emerald: return 12
        case .shadow:  return 18
        case .gold:    return 25
        }
    }
    var suit: SKColor {
        switch self {
        case .classic: return Palette.heroBlue
        case .crimson: return SKColor(red: 0.86, green: 0.22, blue: 0.26, alpha: 1)
        case .emerald: return SKColor(red: 0.20, green: 0.66, blue: 0.42, alpha: 1)
        case .shadow:  return SKColor(red: 0.26, green: 0.24, blue: 0.34, alpha: 1)
        case .gold:    return SKColor(red: 0.90, green: 0.72, blue: 0.20, alpha: 1)
        }
    }
    var cape: SKColor {
        switch self {
        case .classic: return Palette.heroRed
        case .crimson: return SKColor(red: 0.55, green: 0.12, blue: 0.15, alpha: 1)
        case .emerald: return SKColor(red: 0.12, green: 0.42, blue: 0.26, alpha: 1)
        case .shadow:  return SKColor(red: 0.12, green: 0.11, blue: 0.18, alpha: 1)
        case .gold:    return Palette.heroBlue
        }
    }
}

/// Persistent coin bank + purchasable hero upgrades (the start of a
/// Sneaky-Sasquatch-style economy).
enum Upgrade: String, CaseIterable {
    case boots, dash, shield, energy

    var title: String {
        switch self {
        case .boots:  return "Swift Boots"
        case .dash:   return "Turbo Dash"
        case .shield: return "Mega Shield"
        case .energy: return "Power Cell"
        }
    }
    var desc: String {
        switch self {
        case .boots:  return "Run noticeably faster."
        case .dash:   return "Dash farther and faster."
        case .shield: return "Shield lasts much longer."
        case .energy: return "Bigger power meter."
        }
    }
    var price: Int {
        switch self {
        case .boots:  return 12
        case .dash:   return 16
        case .shield: return 20
        case .energy: return 14
        }
    }
    var glyph: String {
        switch self {
        case .boots:  return "👟"
        case .dash:   return "💨"
        case .shield: return "🛡"
        case .energy: return "🔋"
        }
    }
}

enum Economy {
    private static let coinKey = "kaiditya.coins"
    private static func upKey(_ u: Upgrade) -> String { "kaiditya.up.\(u.rawValue)" }

    static var coins: Int { UserDefaults.standard.integer(forKey: coinKey) }

    static func addCoins(_ n: Int) {
        UserDefaults.standard.set(coins + n, forKey: coinKey)
    }

    static func owned(_ u: Upgrade) -> Bool { UserDefaults.standard.bool(forKey: upKey(u)) }

    /// Attempt to buy. Returns true on success.
    @discardableResult
    static func buy(_ u: Upgrade) -> Bool {
        guard !owned(u), coins >= u.price else { return false }
        UserDefaults.standard.set(coins - u.price, forKey: coinKey)
        UserDefaults.standard.set(true, forKey: upKey(u))
        return true
    }

    // MARK: Costumes

    static func ownedCostume(_ c: Costume) -> Bool {
        c == .classic || UserDefaults.standard.bool(forKey: "kaiditya.cos.\(c.rawValue)")
    }
    static var equippedCostume: Costume {
        Costume(rawValue: UserDefaults.standard.string(forKey: "kaiditya.costume") ?? "") ?? .classic
    }
    static func equip(_ c: Costume) { UserDefaults.standard.set(c.rawValue, forKey: "kaiditya.costume") }

    /// Buy (and auto-equip) a costume, or just equip if already owned.
    @discardableResult
    static func selectCostume(_ c: Costume) -> Bool {
        if ownedCostume(c) { equip(c); return true }
        guard coins >= c.price else { return false }
        UserDefaults.standard.set(coins - c.price, forKey: coinKey)
        UserDefaults.standard.set(true, forKey: "kaiditya.cos.\(c.rawValue)")
        equip(c)
        return true
    }
}
