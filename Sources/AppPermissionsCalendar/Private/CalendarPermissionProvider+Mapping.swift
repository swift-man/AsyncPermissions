//
//  CalendarPermissionProvider+Mapping.swift
//  AppPermissionsCalendar
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import EventKit
import AppPermissions

extension CalendarPermissionProvider {
  /// 쓰기 전용 접근과 전체 접근을 구분합니다.
  static func mapStatus(_ status: EKAuthorizationStatus) -> PermissionStatus {
    if #available(iOS 17, macOS 14, *) {
      if status == .fullAccess { return .authorized }
      if status == .writeOnly { return .writeOnly }
    }
    switch status {
    case .notDetermined: return .notDetermined
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    default: return .unknown
    }
  }
}
