//
//  NotificationsPermissionProvider+Mapping.swift
//  AppPermissionsNotifications
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import UserNotifications
import AppPermissions

extension NotificationsPermissionProvider {
  /// 임시 및 App Clip 허용을 별도로 보존합니다.
  static func mapStatus(_ status: UNAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .authorized: return .authorized
    case .denied: return .denied
    case .provisional: return .provisional
    #if os(iOS)
    case .ephemeral: return .ephemeral
    #endif
    @unknown default: return .unknown
    }
  }

  /// 공통 옵션을 OS 옵션으로 손실 없이 변환합니다.
  static func systemOptions(_ options: NotificationPermissionOptions) -> UNAuthorizationOptions {
    var result: UNAuthorizationOptions = []
    if options.contains(.alert) { result.insert(.alert) }
    if options.contains(.sound) { result.insert(.sound) }
    if options.contains(.badge) { result.insert(.badge) }
    if options.contains(.provisional) { result.insert(.provisional) }
    return result
  }
}
