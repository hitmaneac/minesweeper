// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Minesweeper",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Minesweeper", targets: ["Minesweeper"]),
    ],
    targets: [
        // Pure game logic, mouse-input state machine and pixel-art renderer (no AppKit).
        .target(name: "MinesweeperCore"),
        // The macOS app.
        .executableTarget(name: "Minesweeper", dependencies: ["MinesweeperCore"]),
        // Build helper: renders the app icon and preview PNGs.
        .executableTarget(name: "mswtool", dependencies: ["MinesweeperCore"]),
        .testTarget(name: "MinesweeperCoreTests", dependencies: ["MinesweeperCore"]),
    ]
)
