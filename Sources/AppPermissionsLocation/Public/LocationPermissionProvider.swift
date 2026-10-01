//
//  LocationPermissionProvider.swift
//  AppPermissionsLocation
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import AppPermissions

@MainActor
public final class LocationPermissionProvider: PermissionProviding {
  private lazy var driver = LocationPermissionDriver()

  /// 선택한 구현을 생성하되 위치 관리자는 첫 사용까지 생성하지 않습니다.
  public init() {}

  /// 사용 중 및 항상 위치 접근만 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool {
    #if os(macOS)
    return permission == .locationWhenInUse
    #else
    permission == .locationWhenInUse || permission == .locationAlways
    #endif
  }

  /// 위치 접근 범위를 최신 OS 상태로 조회합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    return driver.status()
  }

  /// 최초 선택을 기다리고 보류된 Always 승격은 현재 범위로 반환합니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission) else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    #if os(macOS)
    if permission == .locationAlways { throw .unsupported }
    #endif
    let result = await driver.request(permission)
    guard !Task.isCancelled else { throw .cancelled }
    return result
  }
}
