//
//  NotificationPermissionOptions.swift
//  AppPermissions
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

public struct NotificationPermissionOptions: OptionSet, Sendable, Hashable {
  public let rawValue: UInt

  /// 알림 요구 옵션을 표현하며 시스템 권한 외의 푸시 등록은 수행하지 않습니다.
  public init(rawValue: UInt) {
    self.rawValue = rawValue
  }

  public static let alert = Self(rawValue: 1 << 0)
  public static let sound = Self(rawValue: 1 << 1)
  public static let badge = Self(rawValue: 1 << 2)
  public static let provisional = Self(rawValue: 1 << 3)
  public static let standard: Self = [.alert, .sound, .badge]
}
