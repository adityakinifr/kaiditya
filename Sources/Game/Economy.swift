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
    static var coinsEarned: Int { UserDefaults.standard.integer(forKey: "kaiditya.earned") }
    static var costumesOwned: Int { Costume.allCases.filter { ownedCostume($0) }.count }

    static func addCoins(_ n: Int) {
        UserDefaults.standard.set(coins + n, forKey: coinKey)
        UserDefaults.standard.set(coinsEarned + n, forKey: "kaiditya.earned")
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

    // MARK: Arcade high score

    static var bestCatch: Int { UserDefaults.standard.integer(forKey: "kaiditya.mgBest") }

    /// Record a Crystal-Catch score; returns true if it's a new best.
    static func recordCatch(_ score: Int) -> Bool {
        guard score > bestCatch else { return false }
        UserDefaults.standard.set(score, forKey: "kaiditya.mgBest")
        return true
    }

    // MARK: Daily bonus

    private static var today: Int { Int(Date().timeIntervalSince1970 / 86400) }
    static var canClaimDaily: Bool { UserDefaults.standard.integer(forKey: "kaiditya.daily") != today }
    static var dailyStreak: Int { UserDefaults.standard.integer(forKey: "kaiditya.streak") }

    /// Claim the once-per-day chest. Reward grows with the consecutive-day streak.
    /// Returns the reward and the new streak (reward 0 if already claimed today).
    @discardableResult
    static func claimDaily() -> (reward: Int, streak: Int) {
        guard canClaimDaily else { return (0, dailyStreak) }
        let last = UserDefaults.standard.integer(forKey: "kaiditya.daily")  // 0 if never claimed
        let streak = (last == today - 1) ? dailyStreak + 1 : 1
        UserDefaults.standard.set(today, forKey: "kaiditya.daily")
        UserDefaults.standard.set(streak, forKey: "kaiditya.streak")
        let reward = min(10 + streak * 5, 50)
        addCoins(reward)
        return (reward, streak)
    }

    // MARK: Wishing fountain (once-per-day fortune)

    static var canWishToday: Bool { UserDefaults.standard.integer(forKey: "kaiditya.wishday") != today }

    private static let fortunes = [
        "A brave heart shines brightest.",
        "Adventure favours the curious.",
        "Today, luck is on your side.",
        "Even small heroes save the day.",
        "Kindness is your secret power.",
        "Great things are coming your way."
    ]

    /// Make a wish (once per day). Returns a fortune and any bonus coins won.
    @discardableResult
    static func wish() -> (fortune: String, bonus: Int) {
        guard canWishToday else { return ("You already wished today — come back tomorrow!", 0) }
        UserDefaults.standard.set(today, forKey: "kaiditya.wishday")
        // 50% chance of a lucky bonus.
        let bonus = Bool.random() ? [3, 5, 8].randomElement()! : 0
        if bonus > 0 { addCoins(bonus) }
        return (fortunes.randomElement()!, bonus)
    }

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
