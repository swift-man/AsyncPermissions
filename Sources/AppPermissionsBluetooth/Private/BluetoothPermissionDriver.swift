//
//  BluetoothPermissionDriver.swift
//  AppPermissionsBluetooth
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import CoreBluetooth
import AppPermissions

@MainActor
protocol BluetoothAuthorizationManaging: AnyObject {
  var authorization: CBManagerAuthorization { get }
  var onChange: (@MainActor (CBManagerAuthorization, Bool) -> Void)? { get set }
  /// 권한 확인용 관리자를 시작합니다.
  func start()
  /// 사용이 끝난 관리자를 해제합니다.
  func stop()
}

@MainActor
final class SystemBluetoothAuthorizationManager: NSObject, CBCentralManagerDelegate, BluetoothAuthorizationManaging {
  private var manager: CBCentralManager?
  var authorization: CBManagerAuthorization { CBManager.authorization }
  var onChange: (@MainActor (CBManagerAuthorization, Bool) -> Void)?

  /// 스캔이나 전원 경고 없이 OS 권한 확인을 시작합니다.
  func start() {
    manager = CBCentralManager(
      delegate: self,
      queue: .main,
      options: [CBCentralManagerOptionShowPowerAlertKey: false]
    )
  }

  /// 다음 요청과 이전 관리자의 수명을 분리합니다.
  func stop() { manager = nil }

  /// 해제된 이전 관리자의 늦은 콜백은 새 요청에 전달하지 않습니다.
  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    let identity = ObjectIdentifier(central)
    let authorization = CBManager.authorization
    let isUnsupported = central.state == .unsupported
    Task { @MainActor [weak self] in
      guard let self, let manager, ObjectIdentifier(manager) == identity else { return }
      onChange?(authorization, isUnsupported)
    }
  }
}

@MainActor
final class BluetoothPermissionDriver {
  private let manager: any BluetoothAuthorizationManaging
  private let waitForDeadline: @MainActor @Sendable () async throws -> Void
  private var waiters: [CheckedContinuation<Result<PermissionStatus, PermissionError>, Never>] = []
  private var deadlineTask: Task<Void, Never>?

  /// 관리자와 시간 제한을 주입하며 생성만으로 OS 요청을 수행하지 않습니다.
  init(
    manager: any BluetoothAuthorizationManaging = SystemBluetoothAuthorizationManager(),
    waitForDeadline: @escaping @MainActor @Sendable () async throws -> Void = { try await Task.sleep(nanoseconds: 60_000_000_000) }
  ) {
    self.manager = manager
    self.waitForDeadline = waitForDeadline
    manager.onChange = { [weak self] authorization, isUnsupported in
      guard let self else { return }
      if isUnsupported { finish(.failure(.unsupported)) }
      else if authorization != .notDetermined { finish(.success(Self.mapStatus(authorization))) }
    }
  }

  /// 공유 Bluetooth 권한만 요청하고 콜백 누락 시 대기를 종료합니다.
  func request() async throws(PermissionError) -> PermissionStatus {
    let currentStatus = Self.mapStatus(manager.authorization)
    guard currentStatus == .notDetermined else { return currentStatus }
    let result: Result<PermissionStatus, PermissionError> = await withCheckedContinuation { continuation in
      waiters.append(continuation)
      if waiters.count == 1 {
        startDeadline()
        manager.start()
      }
    }
    return try result.get()
  }

  /// 콜백이 누락돼도 현재 권한을 재조회하고 미결정이면 시간 초과로 해제합니다.
  private func startDeadline() {
    let waitForDeadline = waitForDeadline
    deadlineTask = Task { @MainActor [weak self] in
      do { try await waitForDeadline() } catch { return }
      guard !Task.isCancelled else { return }
      guard let self else { return }
      let currentStatus = Self.mapStatus(manager.authorization)
      finish(currentStatus == .notDetermined ? .failure(.timedOut) : .success(currentStatus))
    }
  }

  /// 대기자와 관리자 및 시간 제한 작업을 함께 정리합니다.
  private func finish(_ result: Result<PermissionStatus, PermissionError>) {
    guard !waiters.isEmpty else { return }
    deadlineTask?.cancel()
    deadlineTask = nil
    manager.stop()
    let continuations = waiters
    waiters.removeAll()
    for continuation in continuations { continuation.resume(returning: result) }
  }

  /// 전원 상태와 접근 권한을 분리합니다.
  nonisolated static func mapStatus(_ status: CBManagerAuthorization) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .allowedAlways: return .authorized
    case .denied: return .denied
    case .restricted: return .restricted
    @unknown default: return .unknown
    }
  }
}
