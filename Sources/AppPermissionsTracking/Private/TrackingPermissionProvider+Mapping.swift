//
//  TrackingPermissionProvider+Mapping.swift
//  AppPermissionsTracking
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import AppPermissions
#if os(iOS)
import AppTrackingTransparency
#endif

extension TrackingPermissionProvider {
  #if os(iOS)
  /// 추적 거부와 시스템 제한을 구분합니다.
  static func mapStatus(_ status: ATTrackingManager.AuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    @unknown default: return .unknown
    }
  }
  #endif
}
