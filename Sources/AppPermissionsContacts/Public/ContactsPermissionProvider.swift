//
//  ContactsPermissionProvider.swift
//  AppPermissionsContacts
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import Contacts
import AppPermissions

@MainActor
public final class ContactsPermissionProvider: PermissionProviding {
  /// 연락처 권한 구현을 생성합니다.
  public init() {}

  /// 연락처 접근만 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool { permission == .contacts }

  /// 제한 허용을 포함한 현재 연락처 권한을 조회합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    return Self.mapStatus(CNContactStore.authorizationStatus(for: .contacts))
  }

  /// 연락처를 읽지 않고 OS 권한만 요청합니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission) else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    do {
      _ = try await CNContactStore().requestAccess(for: .contacts)
    } catch { throw .systemError(error) }
    guard !Task.isCancelled else { throw .cancelled }
    return await status(for: permission)
  }

}
