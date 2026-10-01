//
//  RemindersPermissionProvider.swift
//  AppPermissionsReminders
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import EventKit
import AppPermissions

@MainActor
public final class RemindersPermissionProvider: PermissionProviding {
  /// 미리 알림 권한 구현을 생성합니다.
  public init() {}

  /// 이 모듈의 접근 범위만 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool {
    permission == .reminders
  }

  /// OS의 현재 접근 범위를 조회합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    return Self.mapStatus(EKEventStore.authorizationStatus(for: .reminder))
  }

  /// 버전별 API로 권한만 요청하고 업무 데이터는 읽지 않습니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission) else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    do {
      let eventStore = EKEventStore()
      if #available(iOS 17, macOS 14, *) {
        _ = try await eventStore.requestFullAccessToReminders()
      } else {
        _ = try await eventStore.requestAccess(to: .reminder)
      }
    } catch { throw .systemError(error) }
    guard !Task.isCancelled else { throw .cancelled }
    return await status(for: permission)
  }

}
