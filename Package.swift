// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "AgentZeroIOS",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "A0Core", targets: ["A0Core"]), .library(name: "A0Realtime", targets: ["A0Realtime"]), .library(name: "A0GenerativeUI", targets: ["A0GenerativeUI"]), .executable(name: "a0-transport-probe", targets: ["A0TransportProbe"])],
    dependencies: [.package(url: "https://github.com/socketio/socket.io-client-swift", exact: "16.1.1"), .package(url: "https://github.com/BBC6BAE9/a2ui-swift", revision: "16476ba2cb3fcb4c4bcb141dfa4c2804adbdedb0")],
    targets: [
        .executableTarget(name: "A0TransportProbe", dependencies: ["A0Core", "A0Realtime"]),
        .target(name: "A0Core"),
        .target(name: "A0GenerativeUI", dependencies: ["A0Core", .product(name: "A2UISwiftUI", package: "a2ui-swift"), .product(name: "A2UISwiftCore", package: "a2ui-swift")]),
        .testTarget(name: "A0GenerativeUITests", dependencies: ["A0GenerativeUI"]),
        .target(name: "A0Realtime", dependencies: ["A0Core", .product(name: "SocketIO", package: "socket.io-client-swift")]),
        .testTarget(name: "A0CoreTests", dependencies: ["A0Core"], resources: [.process("Fixtures")])
    ]
)
