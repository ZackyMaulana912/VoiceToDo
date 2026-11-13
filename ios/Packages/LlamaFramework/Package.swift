// swift-tools-version: 5.9
// llama.cpp sebagai XCFramework. File-nya tidak ikut git (sekitar 70 sampai 380 MB);
// siapkan dulu dengan: sh ios/scripts/siapkan-llama.sh   (lihat docs/model.md)
import PackageDescription

let package = Package(
    name: "LlamaFramework",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LlamaFramework", targets: ["llama"]),
    ],
    targets: [
        .binaryTarget(name: "llama", path: "llama.xcframework"),
    ]
)
