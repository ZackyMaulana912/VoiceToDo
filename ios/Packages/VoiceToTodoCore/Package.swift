// swift-tools-version: 5.9
// Logika inti yang tidak bergantung pada iPhone: frasa waktu jadi tanggal, validasi hasil AI, dan prompt.
// Unit test-nya bisa dijalankan di Mac dengan `swift test` dari folder ini.
import PackageDescription

let package = Package(
    name: "VoiceToTodoCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "VoiceToTodoCore", targets: ["VoiceToTodoCore"]),
    ],
    targets: [
        .target(name: "VoiceToTodoCore"),
        .testTarget(name: "VoiceToTodoCoreTests", dependencies: ["VoiceToTodoCore"]),
    ]
)
