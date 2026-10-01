//
//  PermissionClient.swift
//  AppPermissions
//
//  Created by Gorani on 2026/10/01.
//  Copyright © 2026 Gorani. All rights reserved.
//

@MainActor
public final class PermissionClient: PermissionRequesting {
  private let coordinators: [(provider: any PermissionProviding, coordinator: PermissionCoordinator)]

  /// 앱이 선택한 권한 구현만 등록하며 기본 구현을 자동 생성하지 않습니다.
  public init(providers: [any PermissionProviding] = []) {
    coordinators = providers.map { ($0, PermissionCoordinator(driver: $0)) }
  }

  /// OS의 최신 권한 상태를 조회합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard let entry = coordinators.first(where: { $0.provider.supports(permission) }) else { return .unknown }
    return await entry.coordinator.status(for: permission)
  }

  /// 요청 공유와 취소 처리는 내부 구현에 위임합니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard !Task.isCancelled else { throw .cancelled }
    guard let entry = coordinators.first(where: { $0.provider.supports(permission) }) else { throw .unsupported }
    return try await entry.coordinator.request(permission)
  }
}
