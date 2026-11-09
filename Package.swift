// swift-tools-version: 6.0
import PackageDescription

// The package's identity is its mirror's name, `tamr-waiter-ios`:
//     .product(name: "TamrWaiter", package: "tamr-waiter-ios")
// Its name is the product's, so Xcode's scheme (and the release's build) is `TamrWaiter`.
let package = Package(
    name: "TamrWaiter",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "TamrWaiter", targets: ["TamrWaiter"]),
    ],
    targets: [
        .target(name: "TamrWaiter"),
        .testTarget(
            name: "TamrWaiterTests",
            dependencies: ["TamrWaiter"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
