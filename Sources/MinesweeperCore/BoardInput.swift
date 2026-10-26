/// Turns raw mouse button presses into game actions, the way winmine does:
///
/// - Left press pushes a cell in; releasing over a cell opens it.
///   Dragging off the board before release cancels.
/// - Right press flags immediately (on press, not release).
/// - Left + right held together (in either order), middle button, or
///   shift/option + left is a "chord": the 3×3 block pushes in and releasing
///   either button chords the cell under the cursor.
/// - After a chord, nothing else happens until every button is up, so the
///   button still held can't open or flag something by accident.
public enum MouseButton: Sendable { case left, right, middle }

public enum InputAction: Equatable, Sendable {
    case reveal(Pos)
    case chord(Pos)
    case mark(Pos)
}

public enum PressMode: Equatable, Sendable { case none, single, chord }

public struct BoardInput: Sendable {
    public private(set) var left = false
    public private(set) var right = false
    public private(set) var middle = false
    public private(set) var mode: PressMode = .none
    public private(set) var hover: Pos?
    private var locked = false

    public init() {}

    public var anyButtonDown: Bool { left || right || middle }

    public mutating func press(_ button: MouseButton, at pos: Pos?, chordModifier: Bool = false) -> [InputAction] {
        hover = pos
        switch button {
        case .left:
            left = true
            guard !locked else { return [] }
            mode = (right || middle || chordModifier) ? .chord : .single
            return []
        case .right:
            right = true
            guard !locked else { return [] }
            if left || middle {
                mode = .chord
                return []
            }
            if let pos { return [.mark(pos)] }
            return []
        case .middle:
            middle = true
            guard !locked else { return [] }
            mode = .chord
            return []
        }
    }

    public mutating func move(to pos: Pos?) {
        hover = pos
    }

    public mutating func release(_ button: MouseButton, at pos: Pos?) -> [InputAction] {
        hover = pos
        switch button {
        case .left: left = false
        case .right: right = false
        case .middle: middle = false
        }
        var actions: [InputAction] = []
        switch mode {
        case .single:
            if button == .left {
                if let pos { actions = [.reveal(pos)] }
                mode = .none
            }
        case .chord:
            if let pos { actions = [.chord(pos)] }
            mode = .none
            if anyButtonDown { locked = true }
        case .none:
            break
        }
        if !anyButtonDown { locked = false }
        return actions
    }

    /// Forget any press in progress (e.g. a new game started mid-click).
    /// Buttons still physically down stay ignored until released.
    public mutating func cancel() {
        mode = .none
        locked = anyButtonDown
    }
}
