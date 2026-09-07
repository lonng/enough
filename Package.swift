// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Enough",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Enough", targets: ["Enough"])],
    targets: [
        .target(name: "EnoughCore"),
        .executableTarget(name: "Enough", dependencies: ["EnoughCore"]),
        .executableTarget(name: "EnoughChecks", dependencies: ["EnoughCore"], path: "Tests/EnoughChecks")
    ]
)
