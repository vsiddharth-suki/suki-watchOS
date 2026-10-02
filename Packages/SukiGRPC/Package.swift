// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SukiGRPC",
    platforms: [
        .watchOS(.v10),
        .iOS(.v16),
    ],
    products: [
        .library(name: "SukiGRPC", targets: ["SukiGRPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.26.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.38.0"),
    ],
    targets: [
        .target(
            name: "SukiGRPC",
            dependencies: [
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Sources/SukiGRPC"
        ),
    ]
)
