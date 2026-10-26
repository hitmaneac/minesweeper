import AppKit
import MinesweeperCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation, GameViewDelegate {
    private let settings = Settings()
    private var window: NSWindow!
    private var gameView: GameView!
    private let help = HelpWindow()
    private var keyMonitor: Any?

    private static let zoomLevels: [Double] = [1, 1.5, 2, 3]

    func applicationDidFinishLaunching(_ notification: Notification) {
        gameView = GameView(config: settings.config, marks: settings.marks, color: settings.color,
                            zoom: CGFloat(settings.zoom))
        gameView.sounds.enabled = settings.sound
        gameView.delegate = self

        window = NSWindow(contentRect: NSRect(origin: .zero, size: gameView.boardSize),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Minesweeper"
        window.contentView = gameView
        window.delegate = self
        window.isReleasedWhenClosed = false
        if let topLeft = settings.windowTopLeft {
            window.setFrameTopLeftPoint(topLeft)
            keepOnScreen()
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(gameView)

        NSApp.mainMenu = buildMenu()

        // ⌘N as well as F2 for a new game.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == .command, event.charactersIgnoringModifiers == "n" {
                self?.newGame(nil)
                return nil
            }
            return event
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Window

    private func fitWindow() {
        let topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        window.setContentSize(gameView.boardSize)
        window.setFrameTopLeftPoint(topLeft)
        keepOnScreen()
        gameView.needsDisplay = true
    }

    private func keepOnScreen() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var f = window.frame
        if f.maxX > visible.maxX { f.origin.x = visible.maxX - f.width }
        if f.minX < visible.minX { f.origin.x = visible.minX }
        if f.maxY > visible.maxY { f.origin.y = visible.maxY - f.height }
        if f.minY < visible.minY { f.origin.y = max(visible.minY, visible.maxY - f.height) }
        window.setFrame(f, display: true)
    }

    func windowDidMove(_ notification: Notification) {
        settings.windowTopLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
    }

    func windowWillMiniaturize(_ notification: Notification) { gameView.pause() }
    func windowDidDeminiaturize(_ notification: Notification) { gameView.resume() }

    // MARK: - Game menu

    @objc func newGame(_ sender: Any?) {
        gameView.newGame()
    }

    private func start(_ level: Difficulty) {
        settings.difficulty = level
        gameView.newGame(config: settings.config)
        fitWindow()
    }

    @objc func beginner(_ sender: Any?) { start(.beginner) }
    @objc func intermediate(_ sender: Any?) { start(.intermediate) }
    @objc func expert(_ sender: Any?) { start(.expert) }

    @objc func custom(_ sender: Any?) {
        guard let cfg = Dialogs.customField(current: settings.config) else { return }
        settings.custom = cfg
        start(.custom)
    }

    @objc func toggleMarks(_ sender: Any?) {
        settings.marks.toggle()
        gameView.marksEnabled = settings.marks
    }

    @objc func toggleColor(_ sender: Any?) {
        settings.color.toggle()
        gameView.setColor(settings.color)
    }

    @objc func toggleSound(_ sender: Any?) {
        settings.sound.toggle()
        gameView.sounds.enabled = settings.sound
    }

    @objc func bestTimes(_ sender: Any?) {
        Dialogs.showBestTimes(settings)
    }

    func gameViewDidWin(_ view: GameView, seconds: Int) {
        let level = settings.difficulty
        guard level != .custom, seconds < settings.bestTime(level).seconds else { return }
        let name = Dialogs.askName(level: level, defaultName: settings.lastName)
        settings.lastName = name
        settings.setBestTime(BestTime(seconds: seconds, name: name), for: level)
        Dialogs.showBestTimes(settings)
    }

    // MARK: - View menu

    @objc func setZoom(_ sender: NSMenuItem) {
        applyZoom(Double(sender.tag) / 100)
    }

    @objc func zoomIn(_ sender: Any?) {
        if let next = Self.zoomLevels.first(where: { $0 > settings.zoom }) { applyZoom(next) }
    }

    @objc func zoomOut(_ sender: Any?) {
        if let prev = Self.zoomLevels.last(where: { $0 < settings.zoom }) { applyZoom(prev) }
    }

    private func applyZoom(_ z: Double) {
        settings.zoom = z
        gameView.zoom = CGFloat(z)
        fitWindow()
    }

    // MARK: - Help

    @objc func showHelp(_ sender: Any?) { help.show() }

    @objc func about(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Minesweeper",
            .credits: NSAttributedString(
                string: "A remake of the classic Windows XP game for macOS.",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]),
        ])
    }

    // MARK: - Menu

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(beginner(_:)): item.state = settings.difficulty == .beginner ? .on : .off
        case #selector(intermediate(_:)): item.state = settings.difficulty == .intermediate ? .on : .off
        case #selector(expert(_:)): item.state = settings.difficulty == .expert ? .on : .off
        case #selector(custom(_:)): item.state = settings.difficulty == .custom ? .on : .off
        case #selector(toggleMarks(_:)): item.state = settings.marks ? .on : .off
        case #selector(toggleColor(_:)): item.state = settings.color ? .on : .off
        case #selector(toggleSound(_:)): item.state = settings.sound ? .on : .off
        case #selector(setZoom(_:)): item.state = Int((settings.zoom * 100).rounded()) == item.tag ? .on : .off
        case #selector(zoomIn(_:)): return settings.zoom < Self.zoomLevels.last!
        case #selector(zoomOut(_:)): return settings.zoom > Self.zoomLevels.first!
        default: break
        }
        return true
    }

    private func buildMenu() -> NSMenu {
        func item(_ title: String, _ action: Selector?, _ key: String = "",
                  _ mods: NSEvent.ModifierFlags = .command, tag: Int = 0) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.tag = tag
            return i
        }
        func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let m = NSMenu(title: title)
            items.forEach(m.addItem)
            top.submenu = m
            return top
        }
        let f2 = String(Character(UnicodeScalar(UInt32(NSF2FunctionKey))!))

        let main = NSMenu()
        main.addItem(menu("Minesweeper", [
            item("About Minesweeper", #selector(about(_:))),
            .separator(),
            item("Hide Minesweeper", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:))),
            .separator(),
            item("Quit Minesweeper", #selector(NSApplication.terminate(_:)), "q"),
        ]))
        main.addItem(menu("Game", [
            item("New", #selector(newGame(_:)), f2, []),
            .separator(),
            item("Beginner", #selector(beginner(_:)), "1"),
            item("Intermediate", #selector(intermediate(_:)), "2"),
            item("Expert", #selector(expert(_:)), "3"),
            item("Custom…", #selector(custom(_:)), "4"),
            .separator(),
            item("Marks (?)", #selector(toggleMarks(_:))),
            item("Color", #selector(toggleColor(_:))),
            item("Sound", #selector(toggleSound(_:))),
            .separator(),
            item("Best Times…", #selector(bestTimes(_:))),
        ]))
        main.addItem(menu("View", [
            item("Actual Size", #selector(setZoom(_:)), "0", tag: 100),
            item("150%", #selector(setZoom(_:)), tag: 150),
            item("200%", #selector(setZoom(_:)), tag: 200),
            item("300%", #selector(setZoom(_:)), tag: 300),
            .separator(),
            item("Zoom In", #selector(zoomIn(_:)), "="),
            item("Zoom Out", #selector(zoomOut(_:)), "-"),
        ]))
        let windowMenu = menu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
        ])
        main.addItem(windowMenu)
        NSApp.windowsMenu = windowMenu.submenu
        let helpMenu = menu("Help", [
            item("Minesweeper Help", #selector(showHelp(_:)), "?"),
        ])
        main.addItem(helpMenu)
        NSApp.helpMenu = helpMenu.submenu
        return main
    }
}
