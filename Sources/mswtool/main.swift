// Build helper.
//   mswtool icon <dir.iconset>   write the app icon PNGs for iconutil
//   mswtool preview <dir>        render sample game screens as PNGs
import CoreGraphics
import Foundation
import ImageIO
import MinesweeperCore
import UniformTypeIdentifiers

func writePNG(_ buf: PixelBuffer, to path: String) {
    var bytes = buf.pixels.flatMap { [$0.r, $0.g, $0.b, $0.a] }
    let image = bytes.withUnsafeMutableBytes { raw -> CGImage in
        let ctx = CGContext(data: raw.baseAddress, width: buf.width, height: buf.height,
                            bitsPerComponent: 8, bytesPerRow: buf.width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        FileHandle.standardError.write("failed to write \(path)\n".data(using: .utf8)!)
        exit(1)
    }
}

/// 32×32 icon art: a raised tile with a big mine on it.
func iconArt() -> PixelBuffer {
    let p = Palette.color
    var b = PixelBuffer(width: 32, height: 32, fill: p.face)
    b.bevel(x: 0, y: 0, w: 32, h: 32, t: 3, topLeft: p.light, bottomRight: p.shadow)
    let sprites = Sprites(palette: p)
    // Crop the 15×15 mine out of the "mine" cell sprite and draw it doubled.
    var mine = PixelBuffer(width: 15, height: 15)
    for y in 0..<15 {
        for x in 0..<15 {
            let px = sprites.mine[x + 1, y + 1]
            mine[x, y] = (px == p.face || px == p.shadow) ? .clear : px
        }
    }
    b.blit(mine.scaled(by: 2), x: 1, y: 1)
    return b
}

func downsample(_ src: PixelBuffer, to size: Int) -> PixelBuffer {
    var out = PixelBuffer(width: size, height: size)
    for y in 0..<size {
        for x in 0..<size {
            out[x, y] = src[x * src.width / size, y * src.height / size]
        }
    }
    return out
}

func icon(_ dir: String) {
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let art = iconArt()
    for base in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let px = base * scale
            let img = px >= 32 ? art.scaled(by: px / 32) : downsample(art, to: px)
            let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
            writePNG(img, to: "\(dir)/\(name)")
        }
    }
}

func preview(_ dir: String) {
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let mines = [Pos(0, 0), Pos(0, 5), Pos(1, 7), Pos(2, 2), Pos(3, 8), Pos(5, 1), Pos(6, 6), Pos(7, 3), Pos(8, 8), Pos(4, 4)]
    let renderer = Renderer()

    // Mid-game with flags, a question mark and a chord press.
    let g = Game(config: .beginner, minePositions: mines)
    g.reveal(at: Pos(8, 0))
    g.reveal(at: Pos(0, 8))
    g.reveal(at: Pos(4, 6))
    g.cycleMark(at: Pos(6, 6))
    g.cycleMark(at: Pos(2, 2)); g.cycleMark(at: Pos(2, 2))
    let pressed = g.pressedCells(hover: Pos(5, 6), chord: true)
    writePNG(renderer.render(Scene(game: g, pressed: pressed, face: .surprised, timer: 42)).scaled(by: 4), to: "\(dir)/playing.png")

    // Lost: wrong flag and exploded mine.
    let l = Game(config: .beginner, minePositions: mines)
    l.reveal(at: Pos(8, 0))
    l.cycleMark(at: Pos(8, 7))
    l.reveal(at: Pos(4, 4))
    writePNG(renderer.render(Scene(game: l, face: .dead, timer: 7)).scaled(by: 4), to: "\(dir)/lost.png")

    // Won.
    let w = Game(config: .beginner, minePositions: mines)
    for r in 0..<9 { for c in 0..<9 where !mines.contains(Pos(r, c)) { w.reveal(at: Pos(r, c)) } }
    writePNG(renderer.render(Scene(game: w, face: .cool, timer: 123)).scaled(by: 4), to: "\(dir)/won.png")

    // Black & white mode with a negative mine counter.
    let mono = Renderer(palette: .monochrome)
    writePNG(mono.render(Scene(game: g, counter: -5, timer: 999)).scaled(by: 4), to: "\(dir)/mono.png")

    // Expert board, fresh.
    writePNG(renderer.render(Scene(game: Game(config: .expert))).scaled(by: 2), to: "\(dir)/expert.png")

    // Sprite sheet: all numbers, marks, mines, faces, LED digits.
    let s = renderer.sprites
    var sheet = PixelBuffer(width: 16 * 9 + 8, height: 16 * 2 + 26 + 23 + 16, fill: RGBA(0x008080))
    for (i, cell) in s.opened.enumerated() { sheet.blit(cell, x: i * 16, y: 0) }
    for (i, cell) in [s.raised, s.flag, s.question, s.questionPressed, s.mine, s.mineExploded, s.mineWrong].enumerated() {
        sheet.blit(cell, x: i * 16, y: 18)
    }
    for (i, f) in [Face.smile, .surprised, .dead, .cool].enumerated() { sheet.blit(s.faceButtons[f]!, x: i * 28, y: 36) }
    sheet.blit(s.faceButtonPressed, x: 4 * 28, y: 36)
    for (i, d) in s.led.enumerated() { sheet.blit(d, x: i * 13, y: 64) }
    writePNG(sheet.scaled(by: 6), to: "\(dir)/sprites.png")
}

let args = CommandLine.arguments
switch (args.count > 1 ? args[1] : "", args.count > 2 ? args[2] : "") {
case ("icon", let dir) where !dir.isEmpty: icon(dir)
case ("preview", let dir) where !dir.isEmpty: preview(dir)
default:
    print("usage: mswtool icon <dir.iconset> | preview <dir>")
    exit(2)
}
