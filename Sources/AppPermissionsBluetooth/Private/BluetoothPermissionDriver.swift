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
final class BluetoothPermissionDriver: NSObject, CBCentralManagerDelegate {
  private var centralManager: CBCentralManager?
  private var waiters: [CheckedContinuation<PermissionStatus, Never>] = []

  /// 스캔 없이 관리자 생성으로 Bluetooth 공유 권한만 요청합니다.
  func request() async -> PermissionStatus {
    let currentStatus = Self.mapStatus(CBManager.authorization)
    guard currentStatus == .notDetermined else { return currentStatus }
    return await withCheckedContinuation { continuation in
      waiters.append(continuation)
      if centralManager == nil {
        centralManager = CBCentralManager(
          delegate: self,
          queue: .main,
          options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
      }
    }
  }

  /// 전원 상태와 권한 상태를 분리하여 OS 콜백을 전달합니다.
  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    let authorization = CBManager.authorization
    let isUnsupported = central.state == .unsupported
    Task { @MainActor [weak self] in
      self?.complete(isUnsupported ? .unknown : Self.mapStatus(authorization))
    }
  }

  /// 결정된 권한을 대기자에게 전달하며 검색이나 연결은 수행하지 않습니다.
  private func complete(_ status: PermissionStatus) {
    guard status != .notDetermined else { return }
    let continuations = waiters
    waiters.removeAll()
    centralManager = nil
    for continuation in continuations { continuation.resume(returning: status) }
  }

  /// Bluetooth 전원 꺼짐을 권한 거부로 취급하지 않습니다.
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
