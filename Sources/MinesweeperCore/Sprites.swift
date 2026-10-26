public struct Palette: Sendable {
    public var face: RGBA
    public var light: RGBA
    public var shadow: RGBA
    public var black: RGBA
    public var white: RGBA
    public var yellow: RGBA
    public var flag: RGBA
    public var explodedBackground: RGBA
    public var cross: RGBA
    public var ledOn: RGBA
    public var ledOff: RGBA
    public var ledBackground: RGBA
    /// Colors for the numbers 1–8.
    public var numbers: [RGBA]

    public static let color = Palette(
        face: RGBA(0xC0C0C0), light: RGBA(0xFFFFFF), shadow: RGBA(0x808080),
        black: RGBA(0x000000), white: RGBA(0xFFFFFF), yellow: RGBA(0xFFFF00),
        flag: RGBA(0xFF0000), explodedBackground: RGBA(0xFF0000), cross: RGBA(0xFF0000),
        ledOn: RGBA(0xFF0000), ledOff: RGBA(0x580000), ledBackground: RGBA(0x000000),
        numbers: [0x0000FF, 0x008000, 0xFF0000, 0x000080, 0x800000, 0x008080, 0x000000, 0x808080].map { RGBA($0) }
    )

    /// Game > Color turned off.
    public static let monochrome = Palette(
        face: RGBA(0xC0C0C0), light: RGBA(0xFFFFFF), shadow: RGBA(0x808080),
        black: RGBA(0x000000), white: RGBA(0xFFFFFF), yellow: RGBA(0xFFFFFF),
        flag: RGBA(0x000000), explodedBackground: RGBA(0x808080), cross: RGBA(0xFFFFFF),
        ledOn: RGBA(0xFFFFFF), ledOff: RGBA(0x000000), ledBackground: RGBA(0x000000),
        numbers: Array(repeating: RGBA(0x000000), count: 8)
    )
}

public enum Face: Sendable { case smile, surprised, dead, cool }

/// All the hand-drawn pixel art, built for one palette.
public struct Sprites: Sendable {
    public static let cellSize = 16
    public static let ledWidth = 13
    public static let ledHeight = 23
    public static let faceButtonSize = 26

    public let raised: PixelBuffer
    /// Index 0 is an empty opened cell (also used for a pushed-in cell).
    public let opened: [PixelBuffer]
    public let flag: PixelBuffer
    public let question: PixelBuffer
    public let questionPressed: PixelBuffer
    public let mine: PixelBuffer
    public let mineExploded: PixelBuffer
    public let mineWrong: PixelBuffer
    /// 0–9, then 10 = minus sign.
    public let led: [PixelBuffer]
    public let faceButtons: [Face: PixelBuffer]
    /// Smiley button while it is being clicked.
    public let faceButtonPressed: PixelBuffer

    public init(palette p: Palette) {
        raised = Sprites.raisedCell(p)
        opened = (0...8).map { n in
            var b = Sprites.openedCell(p, background: p.face)
            if n > 0 {
                b.blit(PixelBuffer(pattern: Art.digits[n - 1], palette: ["#": p.numbers[n - 1]]), x: 4, y: 2)
            }
            return b
        }

        var f = raised
        f.blit(PixelBuffer(pattern: Art.flag, palette: ["R": p.flag, "K": p.black]), x: 0, y: 0)
        flag = f

        let q = PixelBuffer(pattern: Art.question, palette: ["K": p.black])
        var qr = raised
        qr.blit(q, x: 0, y: 0)
        question = qr
        var qp = Sprites.openedCell(p, background: p.face)
        qp.blit(q, x: 1, y: 1)
        questionPressed = qp

        let minePattern = PixelBuffer(pattern: Art.mine, palette: ["K": p.black, "W": p.white])
        var m = Sprites.openedCell(p, background: p.face)
        m.blit(minePattern, x: 1, y: 1)
        mine = m
        var me = Sprites.openedCell(p, background: p.explodedBackground)
        me.blit(minePattern, x: 1, y: 1)
        mineExploded = me
        var mw = m
        for i in 0...9 {
            mw[3 + i, 3 + i] = p.cross
            mw[4 + i, 3 + i] = p.cross
            mw[13 - i, 3 + i] = p.cross
            mw[12 - i, 3 + i] = p.cross
        }
        mineWrong = mw

        led = (0...10).map { Sprites.ledDigit($0, p) }

        var faces: [Face: PixelBuffer] = [:]
        for face in [Face.smile, .surprised, .dead, .cool] {
            faces[face] = Sprites.faceButton(face, pressed: false, p)
        }
        faceButtons = faces
        faceButtonPressed = Sprites.faceButton(.smile, pressed: true, p)
    }

    // MARK: - Builders

    static func raisedCell(_ p: Palette) -> PixelBuffer {
        var b = PixelBuffer(width: cellSize, height: cellSize, fill: p.face)
        b.bevel(x: 0, y: 0, w: cellSize, h: cellSize, t: 2, topLeft: p.light, bottomRight: p.shadow)
        return b
    }

    static func openedCell(_ p: Palette, background: RGBA) -> PixelBuffer {
        var b = PixelBuffer(width: cellSize, height: cellSize, fill: background)
        b.fill(x: 0, y: 0, w: cellSize, h: 1, p.shadow)
        b.fill(x: 0, y: 0, w: 1, h: cellSize, p.shadow)
        return b
    }

    /// Seven-segment digit, 13×23. Unlit segments are drawn dim.
    static func ledDigit(_ value: Int, _ p: Palette) -> PixelBuffer {
        var b = PixelBuffer(width: ledWidth, height: ledHeight, fill: p.ledBackground)
        let lit: Set<Character>
        switch value {
        case 0: lit = ["a", "b", "c", "d", "e", "f"]
        case 1: lit = ["b", "c"]
        case 2: lit = ["a", "b", "g", "e", "d"]
        case 3: lit = ["a", "b", "g", "c", "d"]
        case 4: lit = ["f", "g", "b", "c"]
        case 5: lit = ["a", "f", "g", "c", "d"]
        case 6: lit = ["a", "f", "g", "e", "c", "d"]
        case 7: lit = ["a", "b", "c"]
        case 8: lit = ["a", "b", "c", "d", "e", "f", "g"]
        case 9: lit = ["a", "b", "c", "d", "f", "g"]
        default: lit = ["g"] // minus
        }
        for seg in "abcdefg" {
            let color = lit.contains(seg) ? p.ledOn : p.ledOff
            for (x, y) in segmentPixels(seg) { b[x, y] = color }
        }
        return b
    }

    static func segmentPixels(_ seg: Character) -> [(Int, Int)] {
        var px: [(Int, Int)] = []
        func hRow(_ y: Int, _ x0: Int, _ x1: Int) { for x in x0...x1 { px.append((x, y)) } }
        func vCol(_ x: Int, _ y0: Int, _ y1: Int) { for y in y0...y1 { px.append((x, y)) } }
        switch seg {
        case "a": hRow(1, 2, 10); hRow(2, 3, 9); hRow(3, 4, 8)
        case "d": hRow(21, 2, 10); hRow(20, 3, 9); hRow(19, 4, 8)
        case "g": hRow(10, 3, 9); hRow(11, 2, 10); hRow(12, 3, 9)
        case "f": vCol(1, 2, 10); vCol(2, 3, 9); vCol(3, 4, 8)
        case "b": vCol(11, 2, 10); vCol(10, 3, 9); vCol(9, 4, 8)
        case "e": vCol(1, 12, 20); vCol(2, 13, 19); vCol(3, 14, 18)
        case "c": vCol(11, 12, 20); vCol(10, 13, 19); vCol(9, 14, 18)
        default: break
        }
        return px
    }

    static func faceButton(_ face: Face, pressed: Bool, _ p: Palette) -> PixelBuffer {
        let s = faceButtonSize
        var b = PixelBuffer(width: s, height: s, fill: p.face)
        b.bevel(x: 0, y: 0, w: s, h: s, t: 1, topLeft: p.shadow, bottomRight: p.shadow)
        if pressed {
            b.fill(x: 1, y: 1, w: s - 2, h: 1, p.shadow)
            b.fill(x: 1, y: 1, w: 1, h: s - 2, p.shadow)
        } else {
            b.bevel(x: 1, y: 1, w: s - 2, h: s - 2, t: 2, topLeft: p.light, bottomRight: p.shadow)
        }
        var art = PixelBuffer(pattern: Art.faceBase, palette: ["K": p.black, "Y": p.yellow])
        let features: [String]
        switch face {
        case .smile: features = Art.smile
        case .surprised: features = Art.surprised
        case .dead: features = Art.dead
        case .cool: features = Art.cool
        }
        art.blit(PixelBuffer(pattern: features, palette: ["K": p.black]), x: 0, y: 0)
        let offset = pressed ? 5 : 4
        b.blit(art, x: offset, y: offset)
        return b
    }
}

/// ASCII pixel art. '.' is transparent.
enum Art {
    static let mine = [
        "...............",
        ".......K.......",
        ".......K.......",
        "...K.KKKKK.K...",
        "....KKKKKKK....",
        "...KKWWKKKKK...",
        "...KKWWKKKKK...",
        ".KKKKKKKKKKKKK.",
        "...KKKKKKKKK...",
        "...KKKKKKKKK...",
        "....KKKKKKK....",
        "...K.KKKKK.K...",
        ".......K.......",
        ".......K.......",
        "...............",
    ]

    static let flag = [
        "................",
        "................",
        "................",
        ".......RR.......",
        ".....RRRR.......",
        "....RRRRR.......",
        ".....RRRR.......",
        ".......RR.......",
        "........K.......",
        "........K.......",
        "......KKKK......",
        "....KKKKKKKK....",
        "....KKKKKKKK....",
        "................",
        "................",
        "................",
    ]

    static let question = [
        "................",
        "................",
        "................",
        "......KKKK......",
        ".....KK..KK.....",
        ".....KK..KK.....",
        "........KK......",
        ".......KK.......",
        ".......KK.......",
        "................",
        ".......KK.......",
        ".......KK.......",
        "................",
        "................",
        "................",
        "................",
    ]

    /// Numbers 1–8, 8×12, bold 2-pixel strokes.
    static let digits: [[String]] = [
        [
            "...##...",
            "..###...",
            ".####...",
            "...##...",
            "...##...",
            "...##...",
            "...##...",
            "...##...",
            "...##...",
            "...##...",
            ".######.",
            ".######.",
        ],
        [
            ".######.",
            "########",
            "##....##",
            "......##",
            ".....###",
            "...####.",
            ".####...",
            "###.....",
            "##......",
            "##......",
            "########",
            "########",
        ],
        [
            ".######.",
            "########",
            "##....##",
            "......##",
            "......##",
            "..#####.",
            "..#####.",
            "......##",
            "......##",
            "##....##",
            "########",
            ".######.",
        ],
        [
            "....###.",
            "...####.",
            "..#####.",
            ".###.##.",
            "###..##.",
            "##...##.",
            "########",
            "########",
            ".....##.",
            ".....##.",
            ".....##.",
            ".....##.",
        ],
        [
            "########",
            "########",
            "##......",
            "##......",
            "#######.",
            "########",
            "......##",
            "......##",
            "......##",
            "##....##",
            "########",
            ".######.",
        ],
        [
            ".######.",
            "########",
            "##....##",
            "##......",
            "#######.",
            "########",
            "##....##",
            "##....##",
            "##....##",
            "##....##",
            "########",
            ".######.",
        ],
        [
            "########",
            "########",
            "......##",
            ".....###",
            "....###.",
            "...###..",
            "...##...",
            "..###...",
            "..##....",
            "..##....",
            "..##....",
            "..##....",
        ],
        [
            ".######.",
            "########",
            "##....##",
            "##....##",
            ".######.",
            ".######.",
            "##....##",
            "##....##",
            "##....##",
            "##....##",
            "########",
            ".######.",
        ],
    ]

    static let faceBase = [
        "......KKKKK......",
        "....KKYYYYYKK....",
        "...KYYYYYYYYYK...",
        "..KYYYYYYYYYYYK..",
        ".KYYYYYYYYYYYYYK.",
        ".KYYYYYYYYYYYYYK.",
        "KYYYYYYYYYYYYYYYK",
        "KYYYYYYYYYYYYYYYK",
        "KYYYYYYYYYYYYYYYK",
        "KYYYYYYYYYYYYYYYK",
        "KYYYYYYYYYYYYYYYK",
        ".KYYYYYYYYYYYYYK.",
        ".KYYYYYYYYYYYYYK.",
        "..KYYYYYYYYYYYK..",
        "...KYYYYYYYYYK...",
        "....KKYYYYYKK....",
        "......KKKKK......",
    ]

    static let smile = [
        ".................",
        ".................",
        ".................",
        ".................",
        ".................",
        ".....KK...KK.....",
        ".....KK...KK.....",
        ".................",
        ".................",
        ".................",
        "....K.......K....",
        ".....K.....K.....",
        "......KKKKK......",
        ".................",
        ".................",
        ".................",
        ".................",
    ]

    static let surprised = [
        ".................",
        ".................",
        ".................",
        ".................",
        ".................",
        ".....KK...KK.....",
        ".....KK...KK.....",
        ".................",
        ".................",
        ".......KKK.......",
        "......K...K......",
        "......K...K......",
        "......K...K......",
        ".......KKK.......",
        ".................",
        ".................",
        ".................",
    ]

    static let dead = [
        ".................",
        ".................",
        ".................",
        ".................",
        "....K.K...K.K....",
        ".....K.....K.....",
        "....K.K...K.K....",
        ".................",
        ".................",
        ".................",
        ".................",
        "......KKKKK......",
        ".....K.....K.....",
        "....K.......K....",
        ".................",
        ".................",
        ".................",
    ]

    static let cool = [
        ".................",
        ".................",
        ".................",
        ".................",
        ".................",
        "..KKKKKKKKKKKKK..",
        "...KKKKK.KKKKK...",
        "....KKK...KKK....",
        ".................",
        ".................",
        "....K.......K....",
        ".....K.....K.....",
        "......KKKKK......",
        ".................",
        ".................",
        ".................",
        ".................",
    ]
}
