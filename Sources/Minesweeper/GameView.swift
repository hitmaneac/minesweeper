import AppKit
import MinesweeperCore

protocol GameViewDelegate: AnyObject {
    func gameViewDidWin(_ view: GameView, seconds: Int)
}

/// The whole game window contents: draws the pixel-art scene and turns mouse
/// events into game moves.
final class GameView: NSView {
    weak var delegate: GameViewDelegate?

    private(set) var game: Game
    private var input = BoardInput()
    private let renderer: Renderer
    let sounds = Sounds()

    private var elapsed = 0
    private var timer: Timer?
    private var smileyTracking = false
    private var smileyPressed = false
    /// Control-click acts as a right click; remember it so the matching
    /// mouseUp is treated as a right-button release.
    private var controlClickIsRight = false

    private let cheat = CheatPixel()
    private var typed = ""

    var zoom: CGFloat {
        didSet { needsDisplay = true }
    }

    var marksEnabled: Bool {
        get { game.marksEnabled }
        set { game.marksEnabled = newValue }
    }

    init(config: BoardConfig, marks: Bool, color: Bool, zoom: CGFloat) {
        game = Game(config: config, marksEnabled: marks)
        renderer = Renderer(palette: color ? .color : .monochrome)
        self.zoom = zoom
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var layout: Layout { Layout(game.config) }

    /// View size in points for the current board and zoom.
    var boardSize: NSSize {
        NSSize(width: CGFloat(layout.width) * zoom, height: CGFloat(layout.height) * zoom)
    }

    // MARK: - Game control

    func newGame(config: BoardConfig? = nil) {
        stopTimer()
        game = Game(config: config ?? game.config, marksEnabled: game.marksEnabled)
        elapsed = 0
        input.cancel()
        smileyTracking = false
        smileyPressed = false
        needsDisplay = true
    }

    func setColor(_ on: Bool) {
        renderer.setPalette(on ? .color : .monochrome)
        needsDisplay = true
    }

    /// Winmine stops the clock while minimized.
    func pause() {
        stopTimer()
    }

    func resume() {
        if game.state == .playing, timer == nil { scheduleTimer() }
    }

    private func startClock() {
        elapsed = 1
        sounds.tick()
        scheduleTimer()
    }

    private func scheduleTimer() {
        let t = Timer(timeInterval: 1, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func timerFired() {
        guard elapsed < 999 else { return }
        elapsed += 1
        sounds.tick()
        needsDisplay = true
    }

    private func perform(_ actions: [InputAction]) {
        for action in actions {
            let wasReady = game.state == .ready
            let result: MoveResult
            switch action {
            case .reveal(let p): result = game.reveal(at: p)
            case .chord(let p): result = game.chord(at: p)
            case .mark(let p):
                game.cycleMark(at: p)
                result = .none
            }
            if wasReady, game.state != .ready { startClock() }
            switch result {
            case .lost:
                stopTimer()
                sounds.lose()
            case .won:
                stopTimer()
                sounds.win()
                let seconds = elapsed
                // Let the board redraw (cool face) before any dialog appears.
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.gameViewDidWin(self, seconds: seconds)
                }
            case .none, .revealed:
                break
            }
        }
    }

    // MARK: - Drawing

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let face: Face
        switch game.state {
        case .lost: face = .dead
        case .won: face = .cool
        default: face = input.mode != .none ? .surprised : .smile
        }
        let pressed = smileyTracking || input.mode == .none
            ? []
            : game.pressedCells(hover: input.hover, chord: input.mode == .chord)
        let buf = renderer.render(Scene(game: game, pressed: pressed, face: face,
                                        facePressed: smileyPressed, timer: elapsed))
        guard let image = makeImage(buf) else { return }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: bounds)
    }

    private func makeImage(_ buf: PixelBuffer) -> CGImage? {
        let data = buf.pixels.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: buf.width, height: buf.height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: buf.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    // MARK: - Mouse

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func artPoint(_ event: NSEvent) -> (x: Int, y: Int) {
        let p = convert(event.locationInWindow, from: nil)
        return (Int(floor(p.x / zoom)), Int(floor((bounds.height - p.y) / zoom)))
    }

    private func cell(at event: NSEvent) -> Pos? {
        let p = artPoint(event)
        return layout.cell(atX: p.x, y: p.y)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            controlClickIsRight = true
            buttonDown(.right, event)
        } else {
            buttonDown(.left, event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if controlClickIsRight {
            controlClickIsRight = false
            buttonUp(.right, event)
        } else {
            buttonUp(.left, event)
        }
    }

    override func rightMouseDown(with event: NSEvent) { buttonDown(.right, event) }
    override func rightMouseUp(with event: NSEvent) { buttonUp(.right, event) }

    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 { buttonDown(.middle, event) }
    }

    override func otherMouseUp(with event: NSEvent) {
        if event.buttonNumber == 2 { buttonUp(.middle, event) }
    }

    override func mouseDragged(with event: NSEvent) { dragged(event) }
    override func rightMouseDragged(with event: NSEvent) { dragged(event) }
    override func otherMouseDragged(with event: NSEvent) { dragged(event) }

    override func mouseMoved(with event: NSEvent) {
        updateCheat(event)
    }

    private func buttonDown(_ button: MouseButton, _ event: NSEvent) {
        let p = artPoint(event)
        if button == .left, !input.anyButtonDown, layout.smileyContains(x: p.x, y: p.y) {
            smileyTracking = true
            smileyPressed = true
            needsDisplay = true
            return
        }
        if smileyTracking { return }
        let chordModifier = button == .left && !event.modifierFlags.intersection([.shift, .option]).isEmpty
        perform(input.press(button, at: layout.cell(atX: p.x, y: p.y), chordModifier: chordModifier))
        updateCheat(event)
        needsDisplay = true
    }

    private func dragged(_ event: NSEvent) {
        let p = artPoint(event)
        if smileyTracking {
            let inside = layout.smileyContains(x: p.x, y: p.y)
            if inside != smileyPressed {
                smileyPressed = inside
                needsDisplay = true
            }
            return
        }
        let pos = layout.cell(atX: p.x, y: p.y)
        updateCheat(event)
        if pos != input.hover {
            input.move(to: pos)
            if input.mode != .none { needsDisplay = true }
        }
    }

    private func buttonUp(_ button: MouseButton, _ event: NSEvent) {
        if smileyTracking {
            guard button == .left else { return }
            smileyTracking = false
            let clicked = smileyPressed
            smileyPressed = false
            if clicked { newGame() } else { needsDisplay = true }
            return
        }
        perform(input.release(button, at: cell(at: event)))
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    // MARK: - Keyboard (the xyzzy cheat)

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn, event.modifierFlags.contains(.shift), typed.hasSuffix("xyzzy") {
            cheat.toggle()
            typed = ""
            return
        }
        if let ch = event.charactersIgnoringModifiers?.lowercased(), ch.count == 1, ch.first!.isLetter {
            typed = String((typed + ch).suffix(5))
            return
        }
        super.keyDown(with: event)
    }

    private func updateCheat(_ event: NSEvent) {
        guard cheat.active, let pos = cell(at: event) else { return }
        cheat.show(mine: game.cell(pos).isMine)
    }
}

/// Winmine's xyzzy cheat: after typing "xyzzy" then Shift+Return, the
/// top-left pixel of the screen turns black over a mine and white otherwise.
final class CheatPixel {
    private(set) var active = false
    private var window: NSWindow?

    func toggle() {
        active.toggle()
        if !active { window?.orderOut(nil) }
    }

    func show(mine: Bool) {
        guard active else { return }
        if window == nil, let screen = NSScreen.screens.first {
            let f = screen.frame
            let w = NSWindow(contentRect: NSRect(x: f.minX, y: f.maxY - 1, width: 1, height: 1),
                             styleMask: .borderless, backing: .buffered, defer: false)
            w.level = .screenSaver
            w.ignoresMouseEvents = true
            w.hasShadow = false
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window = w
        }
        window?.backgroundColor = mine ? .black : .white
        window?.orderFrontRegardless()
    }
}
