//
//  PermissionClient.swift
//  AsyncPermissions
//
//  Created by Gorani on 2026/10/01.
//  Copyright © 2026 Gorani. All rights reserved.
//

@MainActor
public final class PermissionClient: PermissionRequesting {
  private let coordinator: PermissionCoordinator

  /// 내부 요청 조정 구현을 생성하며 외부에는 공개 권한 계약만 제공합니다.
  public init() {
    coordinator = PermissionCoordinator(driver: SystemPermissionDriver())
  }

  /// OS의 최신 권한 상태를 조회합니다.
  public func status(for permission: PermissionKind) -> PermissionStatus {
    coordinator.status(for: permission)
  }

  /// 요청 공유와 취소 처리는 내부 구현에 위임합니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    try await coordinator.request(permission)
  }
}
