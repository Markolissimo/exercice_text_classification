// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExerciseClassifier",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ExerciseClassifier",
            targets: ["ExerciseClassifier"]
        )
    ],
    targets: [
        .target(
            name: "ExerciseClassifier",
            dependencies: []
        )
    ]
)
