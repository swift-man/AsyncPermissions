//
//  CalendarPermissionProvider.swift
//  AppPermissionsCalendar
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import EventKit
import AppPermissions

@MainActor
public final class CalendarPermissionProvider: PermissionProviding {
  /// 캘린더 권한 구현을 생성합니다.
  public init() {}

  /// 이 모듈의 접근 범위만 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool {
    if permission == .calendarFullAccess { return true }
    if #available(iOS 17, macOS 14, *) { return permission == .calendarWriteOnly }
    return false
  }

  /// OS의 현재 접근 범위를 조회합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    return Self.mapStatus(EKEventStore.authorizationStatus(for: .event))
  }

  /// 버전별 API로 권한만 요청하고 업무 데이터는 읽지 않습니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission) else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    do {
      let eventStore = EKEventStore()
      if #available(iOS 17, macOS 14, *) {
        if permission == .calendarWriteOnly {
          _ = try await eventStore.requestWriteOnlyAccessToEvents()
        } else {
          _ = try await eventStore.requestFullAccessToEvents()
        }
      } else {
        // 구 OS에서 쓰기 전용 요청을 전체 권한 요청으로 확대하지 않습니다.
        if permission == .calendarWriteOnly { throw PermissionError.unsupported }
        _ = try await eventStore.requestAccess(to: .event)
      }
    } catch { throw .systemError(error) }
    guard !Task.isCancelled else { throw .cancelled }
    return await status(for: permission)
  }

}
