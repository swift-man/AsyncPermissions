//
//  PermissionTypes.swift
//  AppPermissions
//
//  Created by Gorani on 2026/10/01.
//  Copyright © 2026 Gorani. All rights reserved.
//

public enum PermissionKind: Sendable, Hashable {
  case camera
  case photosReadWrite
  case photosAddOnly
  case microphone
  case locationWhenInUse
  case locationAlways
  case bluetooth
  case calendarFullAccess
  case calendarWriteOnly
  case reminders
  case contacts
  case notifications(options: NotificationPermissionOptions = .standard)
  case tracking
}

public enum PermissionStatus: Sendable, Equatable {
  case notDetermined
  case authorized
  case limited
  case denied
  case restricted
  case unknown
  case whenInUse
  case writeOnly
  case provisional
  case ephemeral

  public var isGranted: Bool {
    switch self {
    case .authorized, .limited, .whenInUse, .writeOnly, .provisional, .ephemeral: true
    default: false
    }
  }
}

public enum PermissionError: Error, Sendable, Equatable {
  case cancelled
  case systemFailure(domain: String, code: Int)
  case unsupported
  case timedOut
  case missingUsageDescription(key: String)
}

@MainActor
public protocol PermissionRequesting: AnyObject, Sendable {
  /// OS의 현재 권한 상태를 조회하며 자체 캐시를 사용하지 않습니다.
  func status(for permission: PermissionKind) async -> PermissionStatus
  /// 미결정 상태와 지원되는 접근 범위 승격에서 요청합니다. 안내·설정 이동은 호출자가 담당합니다.
  func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus
}

@MainActor
public protocol PermissionProviding: PermissionRequesting {
  /// 담당 권한의 옵션·플랫폼 지원 범위를 검증하며 OS 객체를 생성하지 않습니다.
  func supports(_ permission: PermissionKind) -> Bool
}
