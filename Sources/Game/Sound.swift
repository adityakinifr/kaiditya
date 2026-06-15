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

    // Music
    private var music: [String: AVAudioPlayer] = [:]
    private var currentMusic = ""
    var musicEnabled = true

    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        buildAll()
        buildMusicAll()
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

    // MARK: - Music

    func playMusic(_ name: String, volume: Float = 0.5) {
        guard musicEnabled else { return }
        if currentMusic == name, music[name]?.isPlaying == true { return }
        if let cur = music[currentMusic] { cur.setVolume(0, fadeDuration: 0.4); cur.stop() }
        guard let p = music[name] else { return }
        currentMusic = name
        p.numberOfLoops = -1
        p.volume = volume
        p.currentTime = 0
        p.play()
    }

    func stopMusic() {
        if let cur = music[currentMusic] { cur.stop() }
        currentMusic = ""
    }

    /// note(0) == C4. Frequency for a semitone offset.
    private func note(_ semis: Int) -> Double { 261.63 * pow(2.0, Double(semis) / 12.0) }

    private enum Wave { case sine, square, triangle }
    private func osc(_ t: Double, _ f: Double, _ w: Wave) -> Float {
        let ph = (t * f).truncatingRemainder(dividingBy: 1.0)
        switch w {
        case .sine: return sinf(Float(2 * Double.pi * ph))
        case .square: return ph < 0.5 ? 1 : -1
        case .triangle: return Float(4 * abs(ph - 0.5) - 1)
        }
    }

    private func add(_ buf: inout [Float], at startT: Double, dur: Double, freq: Double, wave: Wave, vol: Float) {
        let start = Int(startT * sr), n = Int(dur * sr)
        for i in 0..<n {
            let idx = start + i
            if idx < 0 || idx >= buf.count { continue }
            let t = Double(i) / sr
            let e = (t < 0.01 ? Float(t / 0.01) : Float(max(0, (dur - t) / dur)))   // pluck envelope
            buf[idx] += osc(Double(idx) / sr, freq, wave) * e * vol
        }
    }
    private func addKick(_ buf: inout [Float], at startT: Double) {
        let start = Int(startT * sr), n = Int(0.12 * sr)
        for i in 0..<n {
            let idx = start + i; if idx < 0 || idx >= buf.count { continue }
            let t = Double(i) / sr
            let f = 120.0 - 80.0 * (t / 0.12)
            buf[idx] += sinf(Float(2 * Double.pi * f * t)) * Float(max(0, 1 - t / 0.12)) * 0.22
        }
    }
    private func addHat(_ buf: inout [Float], at startT: Double) {
        let start = Int(startT * sr), n = Int(0.04 * sr)
        for i in 0..<n {
            let idx = start + i; if idx < 0 || idx >= buf.count { continue }
            buf[idx] += noise() * Float(max(0, 1 - Double(i) / Double(n))) * 0.06
        }
    }

    private func buildMusic(_ name: String, roots: [Int], minor: [Bool], bpm: Double, lead: Bool, leadWave: Wave = .triangle) {
        let beat = 60.0 / bpm
        let step = beat / 2.0           // eighth notes
        let stepsPerChord = 4
        let totalSteps = roots.count * stepsPerChord
        let count = Int(sr * Double(totalSteps) * step) + 8
        var buf = [Float](repeating: 0, count: count)
        for s in 0..<totalSteps {
            let ci = (s / stepsPerChord) % roots.count
            let root = roots[ci], isMin = minor[ci]
            let third = root + (isMin ? 3 : 4), fifth = root + 7
            let arp = [root, third, fifth, third][s % 4]
            let t = Double(s) * step
            add(&buf, at: t, dur: step * 0.95, freq: note(root - 12), wave: .square, vol: 0.09)   // bass
            if lead { add(&buf, at: t, dur: step * 0.55, freq: note(arp + 12), wave: leadWave, vol: 0.07) }  // arp
            if s % 2 == 0 { addKick(&buf, at: t) } else { addHat(&buf, at: t) }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kmus_\(name).wav")
        guard (try? wav(buf).write(to: url)) != nil, let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.numberOfLoops = -1; p.prepareToPlay()
        music[name] = p
    }

    private func buildMusicAll() {
        // Upbeat major adventure (C G Am F)
        buildMusic("explore", roots: [0, 7, 9, 5], minor: [false, false, true, false], bpm: 112, lead: true)
        // Tense minor stealth (Am F C G)
        buildMusic("stealth", roots: [9, 5, 0, 7], minor: [true, false, false, false], bpm: 92, lead: true, leadWave: .sine)
        // Driving chase (fast)
        buildMusic("chase", roots: [0, 0, 5, 7], minor: [false, false, false, false], bpm: 144, lead: true, leadWave: .square)
        // Intense boss (descending minor)
        buildMusic("boss", roots: [9, 8, 7, 5], minor: [true, false, false, true], bpm: 132, lead: true, leadWave: .square)
        // Calm menu/map
        buildMusic("menu", roots: [5, 0, 7, 9], minor: [false, false, false, true], bpm: 96, lead: true, leadWave: .sine)
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
