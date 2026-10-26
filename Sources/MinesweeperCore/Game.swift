/// Board size and mine count.
public struct BoardConfig: Equatable, Codable, Sendable {
    public var rows: Int
    public var cols: Int
    public var mines: Int

    public init(rows: Int, cols: Int, mines: Int) {
        self.rows = rows
        self.cols = cols
        self.mines = mines
    }

    public static let beginner = BoardConfig(rows: 9, cols: 9, mines: 10)
    public static let intermediate = BoardConfig(rows: 16, cols: 16, mines: 40)
    public static let expert = BoardConfig(rows: 16, cols: 30, mines: 99)

    public static let rowRange = 9...24
    public static let colRange = 9...30
    public static let minMines = 10

    /// Same limits as the XP "Custom Field" dialog: height 9–24, width 9–30,
    /// mines 10 to (height-1)*(width-1).
    public static func custom(rows: Int, cols: Int, mines: Int) -> BoardConfig {
        let r = min(max(rows, rowRange.lowerBound), rowRange.upperBound)
        let c = min(max(cols, colRange.lowerBound), colRange.upperBound)
        let m = min(max(mines, minMines), (r - 1) * (c - 1))
        return BoardConfig(rows: r, cols: c, mines: m)
    }
}

public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case beginner, intermediate, expert, custom

    public var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .expert: return "Expert"
        case .custom: return "Custom"
        }
    }

    public var preset: BoardConfig? {
        switch self {
        case .beginner: return .beginner
        case .intermediate: return .intermediate
        case .expert: return .expert
        case .custom: return nil
        }
    }
}

public struct Pos: Hashable, Sendable {
    public var row: Int
    public var col: Int
    public init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }
}

public enum Mark: Sendable { case none, flag, question }

public struct Cell: Sendable {
    public var isMine = false
    public var isRevealed = false
    public var mark: Mark = .none
    public var adjacent = 0
    /// A mine the player opened (drawn with a red background).
    public var exploded = false
}

public enum GameState: Sendable { case ready, playing, won, lost }

public enum MoveResult: Equatable, Sendable { case none, revealed, lost, won }

public final class Game {
    public let config: BoardConfig
    public private(set) var cells: [Cell]
    public private(set) var state: GameState = .ready
    public private(set) var flagCount = 0
    /// When off, right-click cycles blank → flag → blank (no "?").
    public var marksEnabled: Bool
    private var revealedCount = 0

    public var minesRemaining: Int { config.mines - flagCount }
    public var isOver: Bool { state == .won || state == .lost }

    /// `minePositions` is for tests; normally mines are placed at random.
    public init(config: BoardConfig, marksEnabled: Bool = true, minePositions: [Pos]? = nil) {
        precondition(config.mines < config.rows * config.cols, "too many mines")
        self.config = config
        self.marksEnabled = marksEnabled
        cells = Array(repeating: Cell(), count: config.rows * config.cols)
        if let minePositions {
            for p in minePositions { cells[index(p)].isMine = true }
        } else {
            for i in Array(cells.indices).shuffled().prefix(config.mines) {
                cells[i].isMine = true
            }
        }
        computeAdjacent()
    }

    public func contains(_ p: Pos) -> Bool {
        p.row >= 0 && p.row < config.rows && p.col >= 0 && p.col < config.cols
    }

    public func cell(_ p: Pos) -> Cell { cells[index(p)] }

    public func neighbors(of p: Pos) -> [Pos] {
        var result: [Pos] = []
        result.reserveCapacity(8)
        for dr in -1...1 {
            for dc in -1...1 where dr != 0 || dc != 0 {
                let n = Pos(p.row + dr, p.col + dc)
                if contains(n) { result.append(n) }
            }
        }
        return result
    }

    /// Right-click: blank → flag → ? (if marks on) → blank.
    @discardableResult
    public func cycleMark(at p: Pos) -> Bool {
        guard !isOver, contains(p) else { return false }
        let i = index(p)
        guard !cells[i].isRevealed else { return false }
        switch cells[i].mark {
        case .none:
            cells[i].mark = .flag
            flagCount += 1
        case .flag:
            cells[i].mark = marksEnabled ? .question : .none
            flagCount -= 1
        case .question:
            cells[i].mark = .none
        }
        return true
    }

    /// Left-click release on a cell.
    @discardableResult
    public func reveal(at p: Pos) -> MoveResult {
        guard !isOver, contains(p) else { return .none }
        let c = cells[index(p)]
        guard !c.isRevealed, c.mark != .flag else { return .none }
        if state == .ready {
            // The first click is never a mine.
            if c.isMine { relocateMine(from: p) }
            state = .playing
        }
        return open([p])
    }

    /// Left+right (or middle) click on a number: if the right number of flags
    /// surround it, open every other covered neighbour.
    @discardableResult
    public func chord(at p: Pos) -> MoveResult {
        guard state == .playing, contains(p) else { return .none }
        let c = cells[index(p)]
        guard c.isRevealed else { return .none }
        let around = neighbors(of: p)
        let flags = around.filter { cells[index($0)].mark == .flag }.count
        guard flags == c.adjacent else { return .none }
        let targets = around.filter {
            let n = cells[index($0)]
            return !n.isRevealed && n.mark != .flag
        }
        guard !targets.isEmpty else { return .none }
        return open(targets)
    }

    /// Cells drawn pushed-in while a button is held.
    public func pressedCells(hover: Pos?, chord: Bool) -> Set<Pos> {
        guard !isOver, let hover else { return [] }
        var candidates = [hover]
        if chord { candidates += neighbors(of: hover) }
        return Set(candidates.filter { p in
            guard contains(p) else { return false }
            let c = cells[index(p)]
            return !c.isRevealed && c.mark != .flag
        })
    }

    // MARK: - Private

    private func index(_ p: Pos) -> Int { p.row * config.cols + p.col }

    private func open(_ starts: [Pos]) -> MoveResult {
        var hitMine = false
        var stack: [Pos] = []
        for p in starts {
            let i = index(p)
            if cells[i].isMine {
                cells[i].isRevealed = true
                cells[i].exploded = true
                cells[i].mark = .none
                hitMine = true
            } else {
                stack.append(p)
            }
        }
        while let p = stack.popLast() {
            let i = index(p)
            if cells[i].isRevealed || cells[i].mark == .flag { continue }
            cells[i].isRevealed = true
            cells[i].mark = .none
            revealedCount += 1
            if cells[i].adjacent == 0 {
                for n in neighbors(of: p) {
                    let nc = cells[index(n)]
                    if !nc.isRevealed && nc.mark != .flag { stack.append(n) }
                }
            }
        }
        if hitMine {
            state = .lost
            return .lost
        }
        if revealedCount == cells.count - config.mines {
            state = .won
            for i in cells.indices where cells[i].isMine { cells[i].mark = .flag }
            flagCount = config.mines
            return .won
        }
        return .revealed
    }

    /// Like winmine: move the mine to the first free square from the top-left.
    private func relocateMine(from p: Pos) {
        let from = index(p)
        if let to = cells.indices.first(where: { !cells[$0].isMine && $0 != from }) {
            cells[to].isMine = true
            cells[from].isMine = false
            computeAdjacent()
        }
    }

    private func computeAdjacent() {
        for r in 0..<config.rows {
            for c in 0..<config.cols {
                let p = Pos(r, c)
                cells[index(p)].adjacent = neighbors(of: p).filter { cells[index($0)].isMine }.count
            }
        }
    }
}
