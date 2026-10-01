//
//  PermissionCoordinator.swift
//  AppPermissions
//
//  Created by Gorani on 2026/10/01.
//  Copyright © 2026 Gorani. All rights reserved.
//

@MainActor
final class PermissionCoordinator: PermissionRequesting {
  private let driver: any PermissionProviding
  private var pendingRequests: [PermissionKind: Task<Result<PermissionStatus, PermissionError>, Never>] = [:]

  /// 테스트에서 OS 팝업 없이 상태와 비동기 응답을 주입합니다.
  init(driver: any PermissionProviding) {
    self.driver = driver
  }

  /// 설정에서 변경한 권한도 즉시 반영합니다.
  func status(for permission: PermissionKind) async -> PermissionStatus {
    await driver.status(for: permission)
  }

  /// 같은 권한의 진행 중 요청을 공유하고 취소된 호출자에게 결과를 전달하지 않습니다.
  func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard !Task.isCancelled else { throw .cancelled }
    let currentStatus = await status(for: permission)
    guard !Task.isCancelled else { throw .cancelled }
    guard Self.shouldRequest(permission, status: currentStatus) else { return currentStatus }
    let request: Task<Result<PermissionStatus, PermissionError>, Never>
    if let pendingRequest = pendingRequests[permission] {
      request = pendingRequest
    } else {
      let driver = driver
      request = Task {
        do { return .success(try await driver.request(permission)) }
        catch { return .failure(PermissionError.systemError(error)) }
      }
      pendingRequests[permission] = request
    }
    let result = await request.value
    // 이전 요청의 늦은 완료가 같은 권한의 새 요청을 제거하지 않도록 확인한다.
    if pendingRequests[permission] == request {
      pendingRequests[permission] = nil
    }
    // OS 팝업 자체는 취소할 수 없으므로 완료 후 호출자의 취소 상태를 확인한다.
    guard !Task.isCancelled else { throw .cancelled }
    return try result.get()
  }

  /// 미결정 권한과 OS가 허용하는 접근 범위 승격만 요청합니다.
  static func shouldRequest(_ permission: PermissionKind, status: PermissionStatus) -> Bool {
    if status == .notDetermined { return true }
    switch permission {
    case .locationAlways: return status == .whenInUse
    case .calendarFullAccess: return status == .writeOnly
    case .notifications(let options):
      return status == .provisional && !options.contains(.provisional)
    default: return false
    }
  }
}
