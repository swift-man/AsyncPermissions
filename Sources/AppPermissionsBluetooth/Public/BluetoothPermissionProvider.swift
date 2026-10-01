//
//  BluetoothPermissionProvider.swift
//  AppPermissionsBluetooth
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import CoreBluetooth
import AppPermissions

@MainActor
public final class BluetoothPermissionProvider: PermissionProviding {
  private lazy var driver = BluetoothPermissionDriver()

  /// 조회만으로 Bluetooth 관리자를 생성하지 않습니다.
  public init() {}

  /// Central과 Peripheral이 공유하는 OS Bluetooth 권한을 지원합니다.
  public func supports(_ permission: PermissionKind) -> Bool { permission == .bluetooth }

  /// Bluetooth 전원 상태와 관계없이 접근 권한을 조회합니다.
  public func status(for permission: PermissionKind) async -> PermissionStatus {
    guard supports(permission) else { return .unknown }
    return BluetoothPermissionDriver.mapStatus(CBManager.authorization)
  }

  /// 스캔·광고·연결 없이 OS 권한만 요청합니다.
  public func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    guard supports(permission) else { throw .unsupported }
    guard !Task.isCancelled else { throw .cancelled }
    let result = await driver.request()
    guard !Task.isCancelled else { throw .cancelled }
    return result
  }
}
