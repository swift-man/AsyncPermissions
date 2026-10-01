//
//  CameraPermissionProvider+Mapping.swift
//  AppPermissionsCamera
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import AVFoundation
import AppPermissions

extension CameraPermissionProvider {
  /// 거부와 시스템 제한을 구분합니다.
  static func mapStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    @unknown default: return .unknown
    }
  }
}
