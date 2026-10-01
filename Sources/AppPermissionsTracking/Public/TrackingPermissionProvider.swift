//
//  TrackingPermissionProvider.swift
//  AppPermissionsTracking
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import AppPermissions
#if os(iOS)
import AppTrackingTransparency
#endif

@MainActor
public final class TrackingPermissionProvider: PermissionProviding {
  /// ATT 권한 구현을 생성합니다.
  public init() {}

  /// 광고 추적 권한만 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool {
    #if os(iOS)
    return permission == .tracking
    #else
    return false
    #endif
  }

  /// ATT 권한만 조회하고 IDFA에는 접근하지 않습니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    #if os(iOS)
    return Self.mapStatus(ATTrackingManager.trackingAuthorizationStatus)
    #else
    return .unknown
    #endif
  }

  /// 호출자가 앱 활성 상태와 팝업 순서를 보장한 뒤 요청합니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission) else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    #if os(iOS)
    let result = await ATTrackingManager.requestTrackingAuthorization()
    guard !Task.isCancelled else { throw .cancelled }
    return Self.mapStatus(result)
    #else
    throw .unsupported
    #endif
  }

}
