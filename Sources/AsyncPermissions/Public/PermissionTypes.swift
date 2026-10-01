//
//  PermissionTypes.swift
//  AsyncPermissions
//
//  Created by NHN on 2026/10/02.
//  Copyright © 2026 com.nhnedu.pinkdiary. All rights reserved.
//

public enum PermissionKind: Sendable, Hashable {
  case camera
  case photosReadWrite
  case photosAddOnly
}

public enum PermissionStatus: Sendable, Equatable {
  case notDetermined
  case authorized
  case limited
  case denied
  case restricted
  case unknown

  public var isGranted: Bool { self == .authorized || self == .limited }
}

public enum PermissionError: Error, Sendable, Equatable {
  case cancelled
}

@MainActor
public protocol PermissionRequesting: AnyObject {
  /// OS의 현재 권한 상태를 조회하며 자체 캐시를 사용하지 않습니다.
  func status(for permission: PermissionKind) -> PermissionStatus
  /// 미결정 상태에서만 시스템 권한을 요청합니다. 안내·설정 이동은 호출자가 담당합니다.
  func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus
}
