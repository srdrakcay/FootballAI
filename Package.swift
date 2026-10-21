// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FootballAI",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CoreDomain", targets: ["CoreDomain"]),
        .library(name: "CoreLocalization", targets: ["CoreLocalization"]),
        .library(name: "CorePersistence", targets: ["CorePersistence"]),
        .library(name: "FeatureFixtures", targets: ["FeatureFixtures"]),
        .library(name: "FeatureAnalysis", targets: ["FeatureAnalysis"]),
        .library(name: "FirebaseAdapters", targets: ["FirebaseAdapters"]),
        .library(name: "FootballAIAppCore", targets: ["FootballAIAppCore"]),
        .library(name: "AppUI", targets: ["AppUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "12.14.0"),
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm.git", from: "5.0.0")
    ],
    targets: [
        .target(name: "CoreDomain"),
        .target(
            name: "CoreLocalization",
            dependencies: ["CoreDomain"],
            resources: [.process("Resources")]
        ),
        .target(name: "CorePersistence", dependencies: ["CoreDomain"]),
        .target(
            name: "FeatureFixtures",
            dependencies: ["CoreDomain", "CoreLocalization"]
        ),
        .target(
            name: "FeatureAnalysis",
            dependencies: ["CoreDomain", "CoreLocalization", "CorePersistence"]
        ),
        .target(
            name: "FirebaseAdapters",
            dependencies: [
                "CoreDomain", "FeatureFixtures", "FeatureAnalysis",
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAppCheck", package: "firebase-ios-sdk"),
                .product(name: "RevenueCat", package: "purchases-ios-spm")
            ]
        ),
        .target(
            name: "FootballAIAppCore",
            dependencies: ["CoreDomain", "CoreLocalization", "FeatureFixtures", "FeatureAnalysis", "FirebaseAdapters"]
        ),
        .target(
            name: "AppUI",
            dependencies: ["CoreDomain", "FootballAIAppCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "CoreDomainTests", dependencies: ["CoreDomain"]),
        .testTarget(name: "CorePersistenceTests", dependencies: ["CorePersistence", "CoreDomain"]),
        .testTarget(name: "FeatureFixturesTests", dependencies: ["FeatureFixtures", "CoreDomain"]),
        .testTarget(name: "FeatureAnalysisTests", dependencies: ["FeatureAnalysis", "CoreDomain"])
    ],
    swiftLanguageModes: [.v6]
)
