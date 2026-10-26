import AppKit
import MinesweeperCore

struct BestTime: Codable {
    var seconds: Int
    var name: String
    static let empty = BestTime(seconds: 999, name: "Anonymous")
}

/// Everything winmine remembered between runs, stored in UserDefaults.
final class Settings {
    private let d = UserDefaults.standard

    init() {
        d.register(defaults: [
            "difficulty": Difficulty.beginner.rawValue,
            "marks": true,
            "color": true,
            "sound": false,
            "zoom": 1.5,
        ])
    }

    var difficulty: Difficulty {
        get { Difficulty(rawValue: d.string(forKey: "difficulty") ?? "") ?? .beginner }
        set { d.set(newValue.rawValue, forKey: "difficulty") }
    }

    var custom: BoardConfig {
        get { decode("custom") ?? BoardConfig(rows: 16, cols: 30, mines: 99) }
        set { encode(newValue, "custom") }
    }

    var config: BoardConfig { difficulty.preset ?? custom }

    var marks: Bool {
        get { d.bool(forKey: "marks") }
        set { d.set(newValue, forKey: "marks") }
    }

    var color: Bool {
        get { d.bool(forKey: "color") }
        set { d.set(newValue, forKey: "color") }
    }

    var sound: Bool {
        get { d.bool(forKey: "sound") }
        set { d.set(newValue, forKey: "sound") }
    }

    var zoom: Double {
        get { d.double(forKey: "zoom") }
        set { d.set(newValue, forKey: "zoom") }
    }

    var windowTopLeft: NSPoint? {
        get {
            guard let s = d.string(forKey: "windowTopLeft") else { return nil }
            let p = NSPointFromString(s)
            return p == .zero ? nil : p
        }
        set { d.set(newValue.map { NSStringFromPoint($0) }, forKey: "windowTopLeft") }
    }

    var lastName: String {
        get { d.string(forKey: "lastName") ?? "Anonymous" }
        set { d.set(newValue, forKey: "lastName") }
    }

    func bestTime(_ level: Difficulty) -> BestTime {
        decode("best.\(level.rawValue)") ?? .empty
    }

    func setBestTime(_ t: BestTime, for level: Difficulty) {
        encode(t, "best.\(level.rawValue)")
    }

    func resetBestTimes() {
        for level in [Difficulty.beginner, .intermediate, .expert] {
            d.removeObject(forKey: "best.\(level.rawValue)")
        }
    }

    private func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, _ key: String) {
        d.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
