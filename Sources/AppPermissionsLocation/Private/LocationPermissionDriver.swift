//
//  LocationPermissionDriver.swift
//  AppPermissionsLocation
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import CoreLocation
import AppPermissions

@MainActor
final class LocationPermissionDriver: NSObject, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private var waiters: [CheckedContinuation<PermissionStatus, Never>] = []

  /// 위치 관리자와 delegate를 같은 주 액터에 유지합니다.
  override init() {
    super.init()
    locationManager.delegate = self
  }

  /// 사용 중 허용과 항상 허용을 구분하여 반환합니다.
  func status() -> PermissionStatus {
    Self.mapStatus(locationManager.authorizationStatus)
  }

  /// 최초 선택을 기다리며 Always 승격이 보류되면 현재 범위를 즉시 반환합니다.
  func request(_ permission: PermissionKind) async -> PermissionStatus {
    let currentStatus = status()
    if currentStatus == .whenInUse && permission == .locationAlways {
      #if os(iOS)
      locationManager.requestAlwaysAuthorization()
      #endif
      return status()
    }
    guard currentStatus == .notDetermined else { return currentStatus }
    return await withCheckedContinuation { continuation in
      waiters.append(continuation)
      if waiters.count == 1 {
        #if os(iOS)
        if permission == .locationAlways {
          locationManager.requestAlwaysAuthorization()
        } else {
          locationManager.requestWhenInUseAuthorization()
        }
        #else
        locationManager.requestWhenInUseAuthorization()
        #endif
      }
    }
  }

  /// OS delegate 콜백에서 상태 값만 주 액터로 전달합니다.
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let authorization = manager.authorizationStatus
    Task { @MainActor [weak self] in
      self?.complete(Self.mapStatus(authorization))
    }
  }

  /// 초기 미결정 콜백은 무시하고 모든 대기자를 정확히 한 번 재개합니다.
  private func complete(_ status: PermissionStatus) {
    guard status != .notDetermined else { return }
    let continuations = waiters
    waiters.removeAll()
    for continuation in continuations { continuation.resume(returning: status) }
  }

  /// 위치 허용 범위를 공개 상태로 변환합니다.
  nonisolated static func mapStatus(_ status: CLAuthorizationStatus) -> PermissionStatus {
    switch status {
    case .notDetermined: return .notDetermined
    case .authorizedAlways: return .authorized
    case .authorizedWhenInUse: return .whenInUse
    case .denied: return .denied
    case .restricted: return .restricted
    @unknown default: return .unknown
    }
  }
}
