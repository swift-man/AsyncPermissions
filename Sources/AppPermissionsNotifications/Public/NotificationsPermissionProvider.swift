//
//  NotificationsPermissionProvider.swift
//  AppPermissionsNotifications
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import UserNotifications
import AppPermissions

@MainActor
public final class NotificationsPermissionProvider: PermissionProviding {
  /// 알림 권한 구현을 생성하며 APNs 등록은 하지 않습니다.
  public init() {}

  /// 알림 요청 옵션을 가진 권한만 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool {
    guard case .notifications(let options) = permission else { return false }
    return !options.isEmpty && options.subtracting([.alert, .sound, .badge, .provisional]).isEmpty
  }

  /// 비동기 OS 설정 조회로 최신 권한을 반환합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    return Self.mapStatus(settings.authorizationStatus)
  }

  /// 전달받은 알림 옵션만 요청하고 설정 이동·푸시 토큰 등록은 하지 않습니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission), case .notifications(let options) = permission else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    do {
      _ = try await UNUserNotificationCenter.current().requestAuthorization(options: Self.systemOptions(options))
    } catch { throw .systemError(error) }
    guard !Task.isCancelled else { throw .cancelled }
    return await status(for: permission)
  }

}
