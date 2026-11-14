// swift-tools-version: 5.10
// Uji regresi logika aplikasi di Mac, memakai file sumber aplikasi yang sama persis (symlink ke ../VoiceToTodo).
// Pengenal suara dan peringkas diganti tiruan, folder data diarahkan ke folder sementara.
//   cd ios/UjiLogika && CFFIXED_USER_HOME=$(mktemp -d) swift run
import PackageDescription

let package = Package(
    name: "UjiLogika",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../Packages/VoiceToTodoCore")],
    targets: [
        .target(name: "AppLogika", dependencies: [.product(name: "VoiceToTodoCore", package: "VoiceToTodoCore")],
                swiftSettings: [.unsafeFlags(["-enable-testing"])]),
        .executableTarget(name: "ujilogika", dependencies: ["AppLogika", .product(name: "VoiceToTodoCore", package: "VoiceToTodoCore")]),
    ]
)
