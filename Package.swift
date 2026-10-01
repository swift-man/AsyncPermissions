// swift-tools-version: 6.0
//
//  Package.swift
//  AppPermissions
//
//  Created by Gorani on 2026/10/01.
//  Copyright © 2026 Gorani. All rights reserved.
//

import PackageDescription

let permissionModules = [
  "AppPermissionsCamera",
  "AppPermissionsPhotos",
  "AppPermissionsMicrophone",
  "AppPermissionsLocation",
  "AppPermissionsBluetooth",
  "AppPermissionsCalendar",
  "AppPermissionsReminders",
  "AppPermissionsContacts",
  "AppPermissionsNotifications",
  "AppPermissionsTracking"
]

let package = Package(
  name: "AppPermissions",
  platforms: [.iOS(.v15), .macOS(.v13)],
  products: [.library(name: "AppPermissions", targets: ["AppPermissions"])]
    + permissionModules.map { .library(name: $0, targets: [$0]) },
  targets: [
    .target(name: "AppPermissions"),
    .testTarget(name: "AppPermissionsTests", dependencies: ["AppPermissions"]),
    .testTarget(
      name: "AppPermissionsSystemTests",
      dependencies: [.target(name: "AppPermissions")] + permissionModules.map { .target(name: $0) }
    )
  ] + permissionModules.map { .target(name: $0, dependencies: ["AppPermissions"]) }
)
