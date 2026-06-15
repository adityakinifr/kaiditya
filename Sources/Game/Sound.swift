import AVFoundation

/// Tiny self-contained sound engine: synthesizes short effects into WAV files
/// at launch (no audio assets needed) and plays them via pooled AVAudioPlayers.
final class SoundFX {
    static let shared = SoundFX()

    private let sr = 22050.0
    private var pools: [String: [AVAudioPlayer]] = [:]
    private var cursor: [String: Int] = [:]
    private var seed: UInt64 = 0x2545F4914F6CDD1D
    var enabled = true

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        buildAll()
    }

    func warmUp() {}   // touching .shared triggers init/synthesis

    // MARK: - Playback

    func play(_ name: String, volume: Float = 1.0) {
        guard enabled, let pool = pools[name], !pool.isEmpty else { return }
        let i = (cursor[name] ?? 0) % pool.count
        cursor[name] = i + 1
        let p = pool[i]
        p.volume = volume
        p.currentTime = 0
        p.play()
    }

    // MARK: - Synthesis

    private func noise() -> Float {
        seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
        return Float(Int64(bitPattern: seed) % 20001 - 10000) / 10000.0
    }
    private func tone(_ t: Double, _ f: Double) -> Float { sinf(Float(2 * Double.pi * f * t)) }
    private func square(_ t: Double, _ f: Double) -> Float { tone(t, f) >= 0 ? 1 : -1 }
    private func env(_ t: Double, _ dur: Double, atk: Double = 0.006) -> Float {
        if t < atk { return Float(t / atk) }
        return Float(max(0, (dur - t) / (dur - atk)))
    }

    private func buildAll() {
        // Rising two-note pickup
        generate("collect", 0.18) { t in self.env(t, 0.18) * 0.4 * (self.tone(t, t < 0.08 ? 880 : 1320)) }
        // Bright coin ding
        generate("coin", 0.16) { t in self.env(t, 0.16) * 0.35 * (self.tone(t, 1568) + 0.5 * self.tone(t, 2349)) }
        // Whooshy dash (filtered noise sweeping down)
        generate("dash", 0.22) { t in self.env(t, 0.22) * 0.3 * (self.noise() * 0.6 + self.tone(t, 600 - 1400 * t)) }
        // Soft shield chord
        generate("shield", 0.3) { t in self.env(t, 0.3, atk: 0.02) * 0.3 * (self.tone(t, 523) + self.tone(t, 659) + self.tone(t, 784)) / 2 }
        // Punchy hit
        generate("hit", 0.14) { t in self.env(t, 0.14) * 0.45 * (self.square(t, 160 - 200 * t) * 0.6 + self.noise() * 0.4) }
        // Crash burst
        generate("crash", 0.3) { t in self.env(t, 0.3) * 0.45 * (self.noise() * 0.8 + self.square(t, 90) * 0.3) }
        // Power-up sparkle (rising arpeggio)
        generate("powerup", 0.34) { t in
            let f: Double = t < 0.11 ? 660 : (t < 0.22 ? 880 : 1320)
            return self.env(t, 0.34) * 0.34 * self.tone(t, f)
        }
        // Caught / zap buzz (descending)
        generate("caught", 0.3) { t in self.env(t, 0.3) * 0.4 * (self.square(t, 300 - 200 * t) * 0.5 + self.noise() * 0.3) }
        // Victory jingle C-E-G-C
        generate("win", 0.7) { t in
            let notes: [Double] = [523, 659, 784, 1046]
            let f = notes[min(3, Int(t / 0.17))]
            return self.env(t, 0.7, atk: 0.01) * 0.35 * (self.tone(t, f) + 0.4 * self.tone(t, f * 2))
        }
        // Level-clear chime
        generate("clear", 0.5) { t in
            let notes: [Double] = [784, 1046, 1318]
            let f = notes[min(2, Int(t / 0.17))]
            return self.env(t, 0.5) * 0.34 * self.tone(t, f)
        }
        // UI tap
        generate("tap", 0.08) { t in self.env(t, 0.08) * 0.25 * self.tone(t, 1200) }
    }

    private func generate(_ name: String, _ dur: Double, _ f: (Double) -> Float) {
        let count = Int(sr * dur)
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count { samples[i] = f(Double(i) / sr) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kfx_\(name).wav")
        guard (try? wav(samples).write(to: url)) != nil else { return }
        var pool: [AVAudioPlayer] = []
        for _ in 0..<3 {
            if let p = try? AVAudioPlayer(contentsOf: url) { p.prepareToPlay(); pool.append(p) }
        }
        pools[name] = pool
        cursor[name] = 0
    }

    private func wav(_ samples: [Float]) -> Data {
        var data = Data()
        let n = samples.count
        func app<T: FixedWidthInteger>(_ v: T) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        data.append("RIFF".data(using: .ascii)!); app(UInt32(36 + n * 2)); data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!); app(UInt32(16)); app(UInt16(1)); app(UInt16(1))
        app(UInt32(sr)); app(UInt32(UInt32(sr) * 2)); app(UInt16(2)); app(UInt16(16))
        data.append("data".data(using: .ascii)!); app(UInt32(n * 2))
        for s in samples { app(Int16(max(-1, min(1, s)) * 32000)) }
        return data
    }
}
