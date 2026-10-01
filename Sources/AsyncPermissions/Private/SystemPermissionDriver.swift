//
//  SystemPermissionDriver.swift
//  AsyncPermissions
//
//  Created by NHN on 2026/10/01.
//  Copyright © 2026 com.nhnedu.pinkdiary. All rights reserved.
//

import AVFoundation
import Photos

@MainActor
final class SystemPermissionDriver: PermissionDriving {
  /// 권한 상태를 조회하고 미래의 미지원 상태는 허용하지 않습니다.
  func status(for permission: PermissionKind) -> PermissionStatus {
    switch permission {
    case .camera:
      return Self.mapCameraStatus(AVCaptureDevice.authorizationStatus(for: .video))
    case .photosReadWrite:
      return Self.mapPhotoStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    case .photosAddOnly:
      return Self.mapPhotoStatus(PHPhotoLibrary.authorizationStatus(for: .addOnly))
    }
  }

  /// Apple의 async API로 권한만 요청합니다.
  func request(_ permission: PermissionKind) async -> PermissionStatus {
    switch permission {
    case .camera:
      _ = await AVCaptureDevice.requestAccess(for: .video)
      return status(for: permission)
    case .photosReadWrite:
      return Self.mapPhotoStatus(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    case .photosAddOnly:
      return Self.mapPhotoStatus(await PHPhotoLibrary.requestAuthorization(for: .addOnly))
    }
  }

  /// 카메라 거부와 시스템 제한을 구분합니다.
  static func mapCameraStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    @unknown default: return .unknown
    }
  }

  /// 선택한 사진만 허용한 상태를 전체 접근과 구분합니다.
  static func mapPhotoStatus(_ status: PHAuthorizationStatus) -> PermissionStatus {
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
