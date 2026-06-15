import Foundation

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
}
