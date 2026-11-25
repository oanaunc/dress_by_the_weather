// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "WeatherStyle", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "WeatherStyle", targets: ["WeatherStyle"])], targets: [.target(name: "WeatherStyle"), .testTarget(name: "WeatherStyleTests", dependencies: ["WeatherStyle"])])
