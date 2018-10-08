// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "ALark",
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "4.5.0")
    ],
    targets: [
        .target(name: "ALark", dependencies: ["Alamofire"]),
        .target(name: "CodeGenerator", dependencies: ["ALark", "SchemaParser"]),
        .target(name: "SchemaParser", dependencies: ["ALark"]),
        .target(name: "lark-generate-client", dependencies: ["SchemaParser", "CodeGenerator"])
    ]
)
