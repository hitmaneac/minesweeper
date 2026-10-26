import XCTest
@testable import MinesweeperCore

final class GameTests: XCTestCase {
    let beginnerMines = [Pos(0, 0), Pos(0, 5), Pos(1, 7), Pos(2, 2), Pos(3, 8), Pos(5, 1), Pos(6, 6), Pos(7, 3), Pos(8, 8), Pos(4, 4)]

    func testRandomBoardHasRightMineCount() {
        for cfg in [BoardConfig.beginner, .intermediate, .expert] {
            let g = Game(config: cfg)
            XCTAssertEqual(g.cells.filter(\.isMine).count, cfg.mines)
        }
    }

    func testFirstClickOnMineMovesItToTopLeft() {
        let g = Game(config: .beginner, minePositions: [Pos(4, 4), Pos(0, 1)] + (0..<8).map { Pos(8, $0) })
        XCTAssertEqual(g.reveal(at: Pos(4, 4)), .revealed)
        XCTAssertFalse(g.cell(Pos(4, 4)).isMine)
        XCTAssertTrue(g.cell(Pos(0, 0)).isMine, "mine moves to first free square from the top-left")
        XCTAssertEqual(g.cells.filter(\.isMine).count, 10)
        XCTAssertEqual(g.state, .playing)
    }

    func testFloodFillOpensZeroRegion() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        g.reveal(at: Pos(8, 0))
        XCTAssertTrue(g.cell(Pos(8, 0)).isRevealed)
        XCTAssertTrue(g.cell(Pos(7, 0)).isRevealed)
        XCTAssertFalse(g.cell(Pos(5, 1)).isRevealed)
    }

    func testFlagsBlockRevealAndFloodFill() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        g.cycleMark(at: Pos(8, 1))
        XCTAssertEqual(g.reveal(at: Pos(8, 1)), .none)
        g.reveal(at: Pos(8, 0))
        XCTAssertFalse(g.cell(Pos(8, 1)).isRevealed)
    }

    func testMarkCycleWithAndWithoutQuestionMarks() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        let p = Pos(3, 3)
        g.cycleMark(at: p); XCTAssertEqual(g.cell(p).mark, .flag); XCTAssertEqual(g.minesRemaining, 9)
        g.cycleMark(at: p); XCTAssertEqual(g.cell(p).mark, .question); XCTAssertEqual(g.minesRemaining, 10)
        g.cycleMark(at: p); XCTAssertEqual(g.cell(p).mark, .none)
        g.marksEnabled = false
        g.cycleMark(at: p); g.cycleMark(at: p)
        XCTAssertEqual(g.cell(p).mark, .none)
    }

    func testMineCounterCanGoNegative() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        for c in 0..<9 { g.cycleMark(at: Pos(1, c)); g.cycleMark(at: Pos(3, c)) }
        XCTAssertEqual(g.minesRemaining, -8)
    }

    func testQuestionMarkedCellCanBeOpened() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        g.cycleMark(at: Pos(8, 0)); g.cycleMark(at: Pos(8, 0))
        XCTAssertEqual(g.reveal(at: Pos(8, 0)), .revealed)
        XCTAssertEqual(g.cell(Pos(8, 0)).mark, .none)
    }

    func testChordOpensNeighboursWhenFlagsMatch() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        g.reveal(at: Pos(1, 1)) // touches (0,0) and (2,2) → 2
        XCTAssertEqual(g.cell(Pos(1, 1)).adjacent, 2)
        XCTAssertEqual(g.chord(at: Pos(1, 1)), .none, "not enough flags")
        g.cycleMark(at: Pos(0, 0))
        g.cycleMark(at: Pos(2, 2))
        XCTAssertEqual(g.chord(at: Pos(1, 1)), .revealed)
        for n in g.neighbors(of: Pos(1, 1)) where !g.cell(n).isMine {
            XCTAssertTrue(g.cell(n).isRevealed)
        }
    }

    func testChordWithWrongFlagLoses() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        g.reveal(at: Pos(1, 1))
        g.cycleMark(at: Pos(0, 0))
        g.cycleMark(at: Pos(1, 2)) // wrong
        XCTAssertEqual(g.chord(at: Pos(1, 1)), .lost)
        XCTAssertTrue(g.cell(Pos(2, 2)).exploded)
        XCTAssertEqual(g.state, .lost)
        XCTAssertEqual(g.reveal(at: Pos(8, 0)), .none, "board frozen after loss")
    }

    func testWinFlagsAllMines() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        var last = MoveResult.none
        for r in 0..<9 { for c in 0..<9 where !beginnerMines.contains(Pos(r, c)) {
            let res = g.reveal(at: Pos(r, c))
            if res != .none { last = res }
        } }
        XCTAssertEqual(last, .won)
        XCTAssertEqual(g.state, .won)
        XCTAssertEqual(g.minesRemaining, 0)
        XCTAssertTrue(beginnerMines.allSatisfy { g.cell($0).mark == .flag })
    }

    func testPressedCells() {
        let g = Game(config: .beginner, minePositions: beginnerMines)
        g.cycleMark(at: Pos(3, 3))
        XCTAssertEqual(g.pressedCells(hover: Pos(3, 3), chord: false), [])
        XCTAssertEqual(g.pressedCells(hover: Pos(0, 0), chord: true), [Pos(0, 0), Pos(0, 1), Pos(1, 0), Pos(1, 1)])
        XCTAssertEqual(g.pressedCells(hover: Pos(4, 4), chord: true).count, 8, "flagged (3,3) stays up")
    }

    func testCustomClamping() {
        XCTAssertEqual(BoardConfig.custom(rows: 2, cols: 99, mines: 1), BoardConfig(rows: 9, cols: 30, mines: 10))
        XCTAssertEqual(BoardConfig.custom(rows: 24, cols: 30, mines: 9999).mines, 667)
    }

    func testLayoutMatchesWinmine() {
        let l = Layout(.beginner)
        XCTAssertEqual(l.width, 168)
        XCTAssertEqual(l.height, 211)
        XCTAssertEqual(l.cell(atX: 12, y: 55), Pos(0, 0))
        XCTAssertEqual(l.cell(atX: 12 + 16 * 9 - 1, y: 55 + 16 * 9 - 1), Pos(8, 8))
        XCTAssertNil(l.cell(atX: 11, y: 60))
        XCTAssertNil(l.cell(atX: 12 + 16 * 9, y: 60))
    }

    func testRenderAllStates() {
        let r = Renderer()
        let g = Game(config: .expert)
        let img = r.render(Scene(game: g, counter: -42, timer: 1000))
        XCTAssertEqual(img.width, Layout(.expert).width)
        _ = Renderer(palette: .monochrome).render(Scene(game: g))
    }
}

final class BoardInputTests: XCTestCase {
    let a = Pos(1, 1), b = Pos(2, 2)

    func testLeftClickRevealsOnRelease() {
        var i = BoardInput()
        XCTAssertEqual(i.press(.left, at: a), [])
        XCTAssertEqual(i.mode, .single)
        i.move(to: b)
        XCTAssertEqual(i.release(.left, at: b), [.reveal(b)], "opens the cell under the cursor at release")
        XCTAssertEqual(i.mode, .none)
    }

    func testDraggingOffBoardCancels() {
        var i = BoardInput()
        _ = i.press(.left, at: a)
        XCTAssertEqual(i.release(.left, at: nil), [])
    }

    func testRightClickMarksOnPress() {
        var i = BoardInput()
        XCTAssertEqual(i.press(.right, at: a), [.mark(a)])
        XCTAssertEqual(i.release(.right, at: a), [])
    }

    func testLeftThenRightChordsOnFirstRelease() {
        var i = BoardInput()
        _ = i.press(.left, at: a)
        XCTAssertEqual(i.press(.right, at: a), [], "no flag when left already held")
        XCTAssertEqual(i.mode, .chord)
        XCTAssertEqual(i.release(.left, at: a), [.chord(a)])
        XCTAssertEqual(i.mode, .none)
        XCTAssertEqual(i.release(.right, at: a), [])
    }

    func testRightThenLeftChords() {
        var i = BoardInput()
        XCTAssertEqual(i.press(.right, at: a), [.mark(a)], "winmine flags on right press even when chording")
        _ = i.press(.left, at: a)
        XCTAssertEqual(i.mode, .chord)
        XCTAssertEqual(i.release(.right, at: b), [.chord(b)])
        XCTAssertEqual(i.release(.left, at: b), [], "held button doesn't open a cell after the chord")
    }

    func testButtonsLockedUntilAllReleased() {
        var i = BoardInput()
        _ = i.press(.left, at: a)
        _ = i.press(.right, at: a)
        XCTAssertEqual(i.release(.right, at: a), [.chord(a)])
        XCTAssertEqual(i.press(.right, at: a), [], "re-pressing right while left still held does nothing")
        XCTAssertEqual(i.mode, .none)
        XCTAssertEqual(i.release(.right, at: a), [])
        XCTAssertEqual(i.release(.left, at: a), [])
        // Fresh click works again.
        _ = i.press(.left, at: a)
        XCTAssertEqual(i.release(.left, at: a), [.reveal(a)])
    }

    func testMiddleAndShiftChord() {
        var i = BoardInput()
        _ = i.press(.middle, at: a)
        XCTAssertEqual(i.release(.middle, at: a), [.chord(a)])
        _ = i.press(.left, at: a, chordModifier: true)
        XCTAssertEqual(i.mode, .chord)
        XCTAssertEqual(i.release(.left, at: a), [.chord(a)])
    }

    func testCancelIgnoresHeldButtons() {
        var i = BoardInput()
        _ = i.press(.left, at: a)
        i.cancel()
        XCTAssertEqual(i.mode, .none)
        XCTAssertEqual(i.release(.left, at: a), [])
    }
}
