// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftDB",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio.git", from: "1.7.0"),
        .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.18.0"),
    ],
    targets: [
        .target(
            name: "SwiftDB",
            dependencies: [
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
            ]
        )
    ]
)
