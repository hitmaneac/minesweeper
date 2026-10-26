/// Window geometry in game pixels — the same proportions as winmine
/// (client area 16·cols+24 by 16·rows+67).
public struct Layout: Equatable, Sendable {
    public let rows: Int
    public let cols: Int

    public init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }

    public init(_ config: BoardConfig) {
        self.init(rows: config.rows, cols: config.cols)
    }

    public static let boardX = 12
    public static let boardY = 55
    public static let counterY = 15

    public var width: Int { Sprites.cellSize * cols + 24 }
    public var height: Int { Sprites.cellSize * rows + 67 }
    public var counterX: Int { 16 }
    public var timerX: Int { width - 57 }
    public var smileyX: Int { (width - Sprites.faceButtonSize) / 2 }
    public var smileyY: Int { 15 }

    public func cell(atX x: Int, y: Int) -> Pos? {
        let bx = x - Layout.boardX
        let by = y - Layout.boardY
        guard bx >= 0, by >= 0 else { return nil }
        let p = Pos(by / Sprites.cellSize, bx / Sprites.cellSize)
        guard p.row < rows, p.col < cols else { return nil }
        return p
    }

    public func smileyContains(x: Int, y: Int) -> Bool {
        x >= smileyX && x < smileyX + Sprites.faceButtonSize &&
            y >= smileyY && y < smileyY + Sprites.faceButtonSize
    }
}

public struct Scene {
    public var game: Game
    public var pressed: Set<Pos>
    public var face: Face
    public var facePressed: Bool
    public var counter: Int
    public var timer: Int

    public init(game: Game, pressed: Set<Pos> = [], face: Face = .smile, facePressed: Bool = false, counter: Int? = nil, timer: Int = 0) {
        self.game = game
        self.pressed = pressed
        self.face = face
        self.facePressed = facePressed
        self.counter = counter ?? game.minesRemaining
        self.timer = timer
    }
}

public final class Renderer {
    public private(set) var palette: Palette
    public private(set) var sprites: Sprites

    public init(palette: Palette = .color) {
        self.palette = palette
        sprites = Sprites(palette: palette)
    }

    public func setPalette(_ p: Palette) {
        palette = p
        sprites = Sprites(palette: p)
    }

    public func render(_ scene: Scene) -> PixelBuffer {
        let game = scene.game
        let layout = Layout(game.config)
        let w = layout.width, h = layout.height
        let p = palette
        var buf = PixelBuffer(width: w, height: h, fill: p.face)

        // Thick white edge on the top/left of the window, sunken header and board.
        buf.bevel(x: 0, y: 0, w: w, h: h, t: 3, topLeft: p.light, bottomRight: p.face)
        buf.bevel(x: 9, y: 9, w: w - 18, h: 37, t: 2, topLeft: p.shadow, bottomRight: p.light)
        buf.bevel(x: 9, y: 52, w: w - 18, h: h - 61, t: 3, topLeft: p.shadow, bottomRight: p.light)

        drawCounter(&buf, value: scene.counter, x: layout.counterX, y: Layout.counterY)
        drawCounter(&buf, value: min(scene.timer, 999), x: layout.timerX, y: Layout.counterY)

        let faceSprite = scene.facePressed ? sprites.faceButtonPressed : sprites.faceButtons[scene.face]!
        buf.blit(faceSprite, x: layout.smileyX, y: layout.smileyY)

        for r in 0..<game.config.rows {
            for c in 0..<game.config.cols {
                let pos = Pos(r, c)
                buf.blit(sprite(for: pos, in: game, pressed: scene.pressed.contains(pos)),
                         x: Layout.boardX + c * Sprites.cellSize,
                         y: Layout.boardY + r * Sprites.cellSize)
            }
        }
        return buf
    }

    func sprite(for pos: Pos, in game: Game, pressed: Bool) -> PixelBuffer {
        let c = game.cell(pos)
        if c.isRevealed {
            if c.isMine { return c.exploded ? sprites.mineExploded : sprites.mine }
            return sprites.opened[c.adjacent]
        }
        if game.state == .lost {
            if c.isMine { return c.mark == .flag ? sprites.flag : sprites.mine }
            if c.mark == .flag { return sprites.mineWrong }
        }
        switch c.mark {
        case .flag: return sprites.flag
        case .question: return pressed ? sprites.questionPressed : sprites.question
        case .none: return pressed ? sprites.opened[0] : sprites.raised
        }
    }

    /// Three LED digits in a 1-pixel sunken box (41×25). Negative values show
    /// a leading minus, like winmine.
    func drawCounter(_ buf: inout PixelBuffer, value: Int, x: Int, y: Int) {
        let v = min(max(value, -99), 999)
        buf.bevel(x: x, y: y, w: 41, h: 25, t: 1, topLeft: palette.shadow, bottomRight: palette.light)
        let digits: [Int]
        if v < 0 {
            let a = -v
            digits = [10, a / 10, a % 10]
        } else {
            digits = [v / 100, (v / 10) % 10, v % 10]
        }
        for (i, d) in digits.enumerated() {
            buf.blit(sprites.led[d], x: x + 1 + i * Sprites.ledWidth, y: y + 1)
        }
    }
}
