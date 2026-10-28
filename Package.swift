// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name:"ReleaseKit", defaultLocalization:"en", platforms:[.iOS(.v17)],
    products:[.library(name:"ReleaseKit",targets:["ReleaseKit"])],
    targets:[.target(name:"ReleaseKitCore"),.target(name:"ReleaseKit",dependencies:["ReleaseKitCore"],resources:[.process("Resources/Localizable.xcstrings"),.copy("Resources/PrivacyInfo.xcprivacy")]),.testTarget(name:"ReleaseKitCoreTests",dependencies:["ReleaseKitCore"],resources:[.process("Fixtures")]),.testTarget(name:"ReleaseKitTests",dependencies:["ReleaseKit"])]
)
