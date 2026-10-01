//
//  PhotosPermissionProvider.swift
//  AppPermissionsPhotos
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import Photos
import AppPermissions

@MainActor
public final class PhotosPermissionProvider: PermissionProviding {
  /// 사진 읽기·쓰기 및 추가 전용 구현을 생성합니다.
  public init() {}

  /// 사진 접근 범위 두 종류만 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool {
    permission == .photosReadWrite || permission == .photosAddOnly
  }

  /// 요청한 접근 범위의 최신 상태를 조회합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    return Self.mapStatus(PHPhotoLibrary.authorizationStatus(for: accessLevel(permission)))
  }

  /// 사진 접근 범위만 요청하며 사진 조회·저장은 수행하지 않습니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission) else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    let result = await PHPhotoLibrary.requestAuthorization(for: accessLevel(permission))
    guard !Task.isCancelled else { throw .cancelled }
    return Self.mapStatus(result)
  }

}
