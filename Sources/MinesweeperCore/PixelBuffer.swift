public struct RGBA: Equatable, Sendable {
    public var r: UInt8, g: UInt8, b: UInt8, a: UInt8

    public init(_ hex: UInt32, alpha: UInt8 = 255) {
        r = UInt8((hex >> 16) & 0xFF)
        g = UInt8((hex >> 8) & 0xFF)
        b = UInt8(hex & 0xFF)
        a = alpha
    }

    public static let clear = RGBA(0, alpha: 0)
}

/// A simple RGBA bitmap, origin at the top-left, rows top to bottom.
public struct PixelBuffer: Sendable {
    public let width: Int
    public let height: Int
    public var pixels: [RGBA]

    public init(width: Int, height: Int, fill: RGBA = .clear) {
        self.width = width
        self.height = height
        pixels = Array(repeating: fill, count: width * height)
    }

    /// Build from ASCII art. Characters missing from `palette` are transparent.
    public init(pattern rows: [String], palette: [Character: RGBA]) {
        let w = rows.first?.count ?? 0
        precondition(rows.allSatisfy { $0.count == w }, "pattern rows must have equal width")
        self.init(width: w, height: rows.count)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                if let c = palette[ch] { pixels[y * w + x] = c }
            }
        }
    }

    public subscript(x: Int, y: Int) -> RGBA {
        get { pixels[y * width + x] }
        set {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            pixels[y * width + x] = newValue
        }
    }

    public mutating func fill(x: Int, y: Int, w: Int, h: Int, _ color: RGBA) {
        for yy in max(0, y)..<min(height, y + h) {
            for xx in max(0, x)..<min(width, x + w) {
                pixels[yy * width + xx] = color
            }
        }
    }

    /// Windows-style 3D edge `t` pixels thick. `topLeft`/`bottomRight` are the
    /// edge colors; the corners split on the diagonal like the classic look.
    public mutating func bevel(x: Int, y: Int, w: Int, h: Int, t: Int, topLeft: RGBA, bottomRight: RGBA) {
        for i in 0..<t {
            for xx in (x + i)..<(x + w - 1 - i) { self[xx, y + i] = topLeft }
            for yy in (y + i)..<(y + h - 1 - i) { self[x + i, yy] = topLeft }
            for xx in (x + i)...(x + w - 1 - i) { self[xx, y + h - 1 - i] = bottomRight }
            for yy in (y + i)...(y + h - 1 - i) { self[x + w - 1 - i, yy] = bottomRight }
        }
    }

    /// Copy `src` onto this buffer, skipping fully transparent pixels.
    public mutating func blit(_ src: PixelBuffer, x: Int, y: Int) {
        for sy in 0..<src.height {
            let dy = y + sy
            guard dy >= 0, dy < height else { continue }
            for sx in 0..<src.width {
                let dx = x + sx
                guard dx >= 0, dx < width else { continue }
                let p = src.pixels[sy * src.width + sx]
                if p.a != 0 { pixels[dy * width + dx] = p }
            }
        }
    }

    /// Nearest-neighbour upscale (used for the app icon and previews).
    public func scaled(by s: Int) -> PixelBuffer {
        var out = PixelBuffer(width: width * s, height: height * s)
        for y in 0..<out.height {
            for x in 0..<out.width {
                out.pixels[y * out.width + x] = pixels[(y / s) * width + (x / s)]
            }
        }
        return out
    }
}
