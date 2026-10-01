//
//  PhotosPermissionProvider+Mapping.swift
//  AppPermissionsPhotos
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import Photos
import AppPermissions

extension PhotosPermissionProvider {
  /// 추가 전용 요청을 전체 라이브러리 요청으로 확대하지 않습니다.
  func accessLevel(_ permission: PermissionKind) -> PHAccessLevel {
    permission == .photosAddOnly ? .addOnly : .readWrite
  }

  /// 선택한 사진 허용을 전체 접근과 구분합니다.
  static func mapStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .authorized: return .authorized
    case .limited: return .limited
    case .denied: return .denied
    case .restricted: return .restricted
    @unknown default: return .unknown
    }
  }
}
