import AppKit

/// The three winmine sounds (tick, win, explosion), synthesized at launch
/// so the app ships no audio files.
final class Sounds {
    var enabled = false
    private let tickSound: NSSound?
    private let winSound: NSSound?
    private let loseSound: NSSound?

    init() {
        tickSound = NSSound(data: Synth.wav(Synth.tick()))
        winSound = NSSound(data: Synth.wav(Synth.win()))
        loseSound = NSSound(data: Synth.wav(Synth.explosion()))
    }

    func tick() { play(tickSound) }
    func win() { play(winSound) }
    func lose() { play(loseSound) }

    private func play(_ s: NSSound?) {
        guard enabled, let s else { return }
        s.stop()
        s.play()
    }
}

enum Synth {
    static let rate = 22050.0

    static func wav(_ samples: [Float]) -> Data {
        var d = Data()
        func str(_ s: String) { d.append(s.data(using: .ascii)!) }
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let dataSize = UInt32(samples.count * 2)
        str("RIFF"); u32(36 + dataSize); str("WAVE")
        str("fmt "); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate) * 2); u16(2); u16(16)
        str("data"); u32(dataSize)
        for s in samples {
            u16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32767)))
        }
        return d
    }

    /// Deterministic white noise in -1...1.
    private struct Noise {
        var state: UInt32 = 0x1234_5678
        mutating func next() -> Float {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(state >> 8) / Float(1 << 23) - 1
        }
    }

    static func tick() -> [Float] {
        var noise = Noise()
        let n = Int(0.03 * rate)
        return (0..<n).map { i in
            let t = Double(i) / rate
            let env = Float(exp(-t * 220))
            return (Float(sin(2 * .pi * 1900 * t)) * 0.6 + noise.next() * 0.35) * env * 0.7
        }
    }

    static func explosion() -> [Float] {
        var noise = Noise()
        let n = Int(1.1 * rate)
        var y: Float = 0
        return (0..<n).map { i in
            let t = Double(i) / rate
            // Noise through a low-pass filter that closes over time, plus a thump.
            let k = Float(0.5 * exp(-t * 3) + 0.03)
            y += (noise.next() - y) * k
            let rumble = Float(sin(2 * .pi * 55 * t) * exp(-t * 6))
            return (y * 1.6 + rumble * 0.6) * Float(exp(-t * 3.2))
        }
    }

    static func win() -> [Float] {
        let notes: [(Double, Double)] = [(523.25, 0.11), (659.25, 0.11), (783.99, 0.11), (1046.5, 0.4)]
        var out: [Float] = []
        for (freq, dur) in notes {
            let n = Int(dur * rate)
            for i in 0..<n {
                let t = Double(i) / rate
                let attack = min(1, t / 0.005)
                let release = min(1, (dur - t) / 0.03)
                let s = sin(2 * .pi * freq * t)
                let square = s >= 0 ? 1.0 : -1.0
                out.append(Float((square * 0.18 + s * 0.25) * attack * release))
            }
        }
        return out
    }
}
