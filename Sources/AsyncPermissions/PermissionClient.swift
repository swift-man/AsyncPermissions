//
//  PermissionClient.swift
//  AsyncPermissions
//
//  Created by NHN on 2026/10/01.
//  Copyright © 2026 com.nhnedu.pinkdiary. All rights reserved.
//

public enum PermissionKind: Sendable, Hashable {
  case camera
  case photosReadWrite
  case photosAddOnly
}

public enum PermissionStatus: Sendable, Equatable {
  case notDetermined
  case authorized
  case limited
  case denied
  case restricted
  case unknown

  public var isGranted: Bool { self == .authorized || self == .limited }
}

public enum PermissionError: Error, Sendable, Equatable {
  case cancelled
}

@MainActor
public protocol PermissionRequesting: AnyObject {
  /// OS의 현재 권한 상태를 조회하며 자체 캐시를 사용하지 않습니다.
  func status(for permission: PermissionKind) -> PermissionStatus
  /// 미결정 상태에서만 시스템 권한을 요청합니다. 안내·설정 이동은 호출자가 담당합니다.
  func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus
}

@MainActor
protocol PermissionDriving: AnyObject {
  /// OS 권한 상태를 공통 상태로 변환합니다.
  func status(for permission: PermissionKind) -> PermissionStatus
  /// 시스템 권한 요청이 완료될 때 최종 상태를 반환합니다.
  func request(_ permission: PermissionKind) async -> PermissionStatus
}

@MainActor
public final class PermissionClient: PermissionRequesting {
  private let driver: any PermissionDriving
  private var pendingRequests: [PermissionKind: Task<PermissionStatus, Never>] = [:]

  /// 플랫폼의 권한 요청 구현으로 클라이언트를 구성합니다.
  public convenience init() {
    self.init(driver: SystemPermissionDriver())
  }

  /// 테스트에서 OS 팝업 없이 상태와 비동기 응답을 주입합니다.
  init(driver: any PermissionDriving) {
    self.driver = driver
  }

  /// 설정에서 변경한 권한도 즉시 반영합니다.
  public func status(for permission: PermissionKind) -> PermissionStatus {
    driver.status(for: permission)
  }

  /// 같은 권한의 진행 중 요청을 공유하고 취소된 호출자에게 결과를 전달하지 않습니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard !Task.isCancelled else { throw .cancelled }
    let currentStatus = status(for: permission)
    guard currentStatus == .notDetermined else { return currentStatus }
    let request: Task<PermissionStatus, Never>
    if let pendingRequest = pendingRequests[permission] {
      request = pendingRequest
    } else {
      let driver = driver
      request = Task { await driver.request(permission) }
      pendingRequests[permission] = request
    }
    let result = await request.value
    // 이전 요청의 늦은 완료가 같은 권한의 새 요청을 제거하지 않도록 확인한다.
    if pendingRequests[permission] == request {
      pendingRequests[permission] = nil
    }
    // OS 팝업 자체는 취소할 수 없으므로 완료 후 호출자의 취소 상태를 확인한다.
    guard !Task.isCancelled else { throw .cancelled }
    return result
  }
}
