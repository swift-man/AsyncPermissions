// swift-tools-version: 6.0
//
//  Package.swift
//  AsyncPermissions
//
//  Created by Gorani on 2026/10/01.
//  Copyright © 2026 Gorani. All rights reserved.
//

import PackageDescription

let package = Package(
  name: "AsyncPermissions",
  platforms: [.iOS(.v15), .macOS(.v13)],
  products: [.library(name: "AsyncPermissions", targets: ["AsyncPermissions"])],
  targets: [
    .target(name: "AsyncPermissions"),
    .testTarget(name: "AsyncPermissionsTests", dependencies: ["AsyncPermissions"])
  ]
)
