import AppKit
import MinesweeperCore

enum Dialogs {
    /// Game > Custom… (Height / Width / Mines). Returns nil on Cancel.
    static func customField(current: BoardConfig) -> BoardConfig? {
        let alert = NSAlert()
        alert.messageText = "Custom Field"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let rows: [(String, Int)] = [("Height:", current.rows), ("Width:", current.cols), ("Mines:", current.mines)]
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 96))
        var fields: [NSTextField] = []
        for (i, (label, value)) in rows.enumerated() {
            let y = CGFloat(96 - (i + 1) * 32 + 6)
            let l = NSTextField(labelWithString: label)
            l.alignment = .right
            l.frame = NSRect(x: 0, y: y + 2, width: 64, height: 20)
            let f = NSTextField(string: "\(value)")
            f.frame = NSRect(x: 72, y: y, width: 80, height: 24)
            container.addSubview(l)
            container.addSubview(f)
            fields.append(f)
        }
        fields[0].nextKeyView = fields[1]
        fields[1].nextKeyView = fields[2]
        fields[2].nextKeyView = fields[0]
        alert.accessoryView = container
        alert.layout()
        alert.window.initialFirstResponder = fields[0]

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        func value(_ i: Int, _ fallback: Int) -> Int {
            Int(fields[i].stringValue.trimmingCharacters(in: .whitespaces)) ?? fallback
        }
        return BoardConfig.custom(rows: value(0, current.rows), cols: value(1, current.cols), mines: value(2, current.mines))
    }

    /// Shown after a record time.
    static func askName(level: Difficulty, defaultName: String) -> String {
        let alert = NSAlert()
        alert.messageText = "You have the fastest time for \(level.displayName.lowercased()) level."
        alert.informativeText = "Please type your name:"
        alert.addButton(withTitle: "OK")
        let field = NSTextField(string: defaultName)
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.layout()
        alert.window.initialFirstResponder = field
        alert.runModal()
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Anonymous" : String(name.prefix(32))
    }

    /// Game > Best Times… ("Fastest Mine Sweepers").
    static func showBestTimes(_ settings: Settings) {
        while true {
            let alert = NSAlert()
            alert.messageText = "Fastest Mine Sweepers"
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Reset Scores")

            let levels = [Difficulty.beginner, .intermediate, .expert]
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 72))
            for (i, level) in levels.enumerated() {
                let best = settings.bestTime(level)
                let y = CGFloat(72 - (i + 1) * 24)
                let cols: [(String, CGFloat, CGFloat, NSTextAlignment)] = [
                    ("\(level.displayName):", 0, 90, .left),
                    ("\(best.seconds) seconds", 90, 90, .right),
                    (best.name, 196, 104, .left),
                ]
                for (text, x, w, align) in cols {
                    let l = NSTextField(labelWithString: text)
                    l.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
                    l.alignment = align
                    l.lineBreakMode = .byTruncatingTail
                    l.frame = NSRect(x: x, y: y, width: w, height: 20)
                    container.addSubview(l)
                }
            }
            alert.accessoryView = container
            if alert.runModal() == .alertSecondButtonReturn {
                settings.resetBestTimes()
                continue
            }
            return
        }
    }
}

/// Help > Minesweeper Help.
final class HelpWindow {
    private var panel: NSPanel?

    func show() {
        if panel == nil { panel = makePanel() }
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
                            styleMask: [.titled, .closable, .resizable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.title = "Minesweeper Help"
        panel.isReleasedWhenClosed = false
        let scroll = NSTextView.scrollableTextView()
        let text = scroll.documentView as! NSTextView
        text.isEditable = false
        text.textContainerInset = NSSize(width: 14, height: 14)
        text.textStorage?.setAttributedString(HelpWindow.content())
        panel.contentView = scroll
        return panel
    }

    private static func content() -> NSAttributedString {
        let out = NSMutableAttributedString()
        let body = NSFont.systemFont(ofSize: 13)
        let head = NSFont.boldSystemFont(ofSize: 15)
        func add(_ s: String, _ font: NSFont) {
            out.append(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: NSColor.textColor]))
        }
        let sections: [(String, String)] = [
            ("Object of the game", """
            Find all the mines as quickly as possible without uncovering any of them. \
            If you uncover a mine, you lose.

            """),
            ("Playing", """
            • Click a square to uncover it. If it's a mine, the game is over.
            • A number tells you how many mines touch that square (including diagonals).
            • Right-click (or Control-click) a square you think is a mine to flag it. \
            Right-click again for a question mark, and again to clear it. \
            Turn question marks off with Game ▸ Marks (?).
            • The counter on the left shows mines left (mines minus flags). \
            The counter on the right is the timer, which starts on your first click.
            • Your first click is never a mine.

            """),
            ("Clearing around a number (chording)", """
            When a number already has that many flags around it, press both the left and \
            right mouse buttons on it and release to uncover all its other neighbours. \
            You can also use the middle button, or hold Shift (or Option) while clicking. \
            If a flag is wrong, you hit a mine.

            """),
            ("The face", """
            Click the smiley (or press F2 / ⌘N) to start a new game. It gasps while you \
            hold the mouse down, wears sunglasses when you win, and is dead when you lose.

            """),
            ("Levels", """
            Beginner: 9 × 9, 10 mines
            Intermediate: 16 × 16, 40 mines
            Expert: 30 × 16, 99 mines
            Custom: 9–30 wide, 9–24 high, up to (width−1)×(height−1) mines

            Your fastest time for each standard level is saved. See Game ▸ Best Times…

            """),
            ("Options", """
            Game ▸ Color switches between color and black & white. Game ▸ Sound plays a tick \
            every second, a fanfare when you win and a bang when you lose. View ▸ Zoom changes \
            the size of the window. Minimizing the window pauses the clock.

            """),
        ]
        for (title, text) in sections {
            add(title + "\n", head)
            add(text + "\n", body)
        }
        return out
    }
}
