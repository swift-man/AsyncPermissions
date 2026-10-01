//
//  CameraPermissionProvider.swift
//  AppPermissionsCamera
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import AVFoundation
import AppPermissions

@MainActor
public final class CameraPermissionProvider: PermissionProviding {
  /// 필요한 권한 구현만 명시적으로 생성합니다.
  public init() {}

  /// 해당 캡처 권한만 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool { permission == .camera }

  /// OS의 현재 캡처 권한을 조회합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    return Self.mapStatus(AVCaptureDevice.authorizationStatus(for: .video))
  }

  /// 캡처 권한만 요청하며 캡처 세션을 생성하지 않습니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission) else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    _ = await AVCaptureDevice.requestAccess(for: .video)
    guard !Task.isCancelled else { throw .cancelled }
    return await status(for: permission)
  }

}
