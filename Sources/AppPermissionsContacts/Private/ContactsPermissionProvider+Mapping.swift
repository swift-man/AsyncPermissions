//
//  ContactsPermissionProvider+Mapping.swift
//  AppPermissionsContacts
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import Contacts
import AppPermissions

extension ContactsPermissionProvider {
  /// iOS 18의 제한 허용을 전체 허용과 구분합니다.
  static func mapStatus(_ status: CNAuthorizationStatus) -> PermissionStatus {
    #if os(iOS)
    if #available(iOS 18, *), status == .limited { return .limited }
    #endif
    switch status {
    case .notDetermined: return .notDetermined
    case .authorized: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    default: return .unknown
    }
  }
}
