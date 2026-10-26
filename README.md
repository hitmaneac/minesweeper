# Minesweeper

The Windows XP Minesweeper, remade as a native macOS app (Swift + AppKit, no dependencies).

## Build & run

```sh
./build.sh          # builds build/Minesweeper.app
./build.sh --run    # builds and opens it
swift test          # game-logic and mouse-input tests
```

Requires Xcode (macOS 13+ target).

## Controls

| Action | Mouse |
| --- | --- |
| Open a square | Left click (press, release over the square) |
| Flag / ? / clear | Right click, two-finger click, or Control-click |
| Chord (open around a satisfied number) | Left + right together, middle click, or Shift/Option + click |
| New game | Click the smiley, F2, or ⌘N |

## Features

Beginner / Intermediate / Expert / Custom boards, first click always safe, flood fill,
chording, Marks (?) toggle, Color / black-and-white, Sound (synthesized tick, win, explosion),
Best Times with names and Reset Scores, settings and window position remembered, clock
paused while minimized, and the `xyzzy` + Shift-Return cheat (top-left screen pixel turns black
over a mine). View ▸ Zoom scales the pixel art 100–300%.

## Layout

- `Sources/MinesweeperCore` — game rules (`Game`), mouse-button state machine (`BoardInput`),
  pixel art and renderer. No AppKit, fully unit-tested.
- `Sources/Minesweeper` — the AppKit app: window, menus, dialogs, sounds.
- `Sources/mswtool` — build helper that renders the app icon (and preview PNGs).
