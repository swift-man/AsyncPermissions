//
//  LocationPermissionDriver.swift
//  AppPermissionsLocation
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import CoreLocation
import AppPermissions
import Foundation

@MainActor
protocol LocationAuthorizationManaging: AnyObject {
  var authorizationStatus: CLAuthorizationStatus { get }
  var onChange: (@MainActor (CLAuthorizationStatus) -> Void)? { get set }
  /// OS에 사용 중 접근을 요청합니다.
  func requestWhenInUse()
  /// OS에 항상 접근을 요청합니다.
  func requestAlways()
}

@MainActor
final class SystemLocationAuthorizationManager: NSObject, CLLocationManagerDelegate, LocationAuthorizationManaging {
  private let manager = CLLocationManager()
  var onChange: (@MainActor (CLAuthorizationStatus) -> Void)?
  var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

  /// 실제 위치 기능 사용 지점에서 delegate를 연결합니다.
  override init() {
    super.init()
    manager.delegate = self
  }

  /// 좌표를 조회하지 않고 사용 중 접근만 요청합니다.
  func requestWhenInUse() { manager.requestWhenInUseAuthorization() }

  /// iOS에서 OS가 제공하는 승격 요청만 수행합니다.
  func requestAlways() {
    #if os(iOS)
    manager.requestAlwaysAuthorization()
    #endif
  }

  /// 상태 값만 주 액터로 전달합니다.
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      onChange?(authorizationStatus)
    }
  }
}

@MainActor
final class LocationPermissionDriver {
  private let manager: any LocationAuthorizationManaging
  private let waitForDeadline: @MainActor @Sendable () async throws -> Void
  private let hasUsageDescription: @MainActor (String) -> Bool
  private var waiters: [CheckedContinuation<Result<PermissionStatus, PermissionError>, Never>] = []
  private var deadlineTask: Task<Void, Never>?

  /// OS 관리자와 시간 제한을 주입하여 콜백 누락도 테스트할 수 있게 합니다.
  init(
    manager: any LocationAuthorizationManaging = SystemLocationAuthorizationManager(),
    waitForDeadline: @escaping @MainActor @Sendable () async throws -> Void = { try await Task.sleep(nanoseconds: 60_000_000_000) },
    hasUsageDescription: @escaping @MainActor (String) -> Bool = {
      guard let value = Bundle.main.object(forInfoDictionaryKey: $0) as? String else { return false }
      return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
  ) {
    self.manager = manager
    self.waitForDeadline = waitForDeadline
    self.hasUsageDescription = hasUsageDescription
    manager.onChange = { [weak self] status in
      guard status != .notDetermined else { return }
      self?.finish(.success(Self.mapStatus(status)))
    }
  }

  /// 최신 접근 범위를 조회합니다.
  func status() -> PermissionStatus { Self.mapStatus(manager.authorizationStatus) }

  /// 사용 사유를 검증하고 콜백 누락 시 60초 뒤 명시적 오류로 대기를 해제합니다.
  func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    #if os(macOS)
    let requiredKeys = ["NSLocationUsageDescription"]
    #else
    var requiredKeys = ["NSLocationWhenInUseUsageDescription"]
    if permission == .locationAlways { requiredKeys.append("NSLocationAlwaysAndWhenInUseUsageDescription") }
    #endif
    for key in requiredKeys where !hasUsageDescription(key) { throw .missingUsageDescription(key: key) }
    let currentStatus = status()
    if currentStatus == .whenInUse && permission == .locationAlways {
      manager.requestAlways()
      return status()
    }
    guard currentStatus == .notDetermined else { return currentStatus }
    let result: Result<PermissionStatus, PermissionError> = await withCheckedContinuation { continuation in
      waiters.append(continuation)
      if waiters.count == 1 {
        startDeadline()
        if permission == .locationAlways { manager.requestAlways() }
        else { manager.requestWhenInUse() }
      }
    }
    return try result.get()
  }

  /// 상태가 이미 바뀌었으면 최신 값을, 여전히 미결정이면 시간 초과를 반환합니다.
  private func startDeadline() {
    let waitForDeadline = waitForDeadline
    deadlineTask = Task { @MainActor [weak self] in
      do { try await waitForDeadline() } catch { return }
      guard !Task.isCancelled else { return }
      guard let self else { return }
      let currentStatus = status()
      finish(currentStatus == .notDetermined ? .failure(.timedOut) : .success(currentStatus))
    }
  }

  /// 모든 대기자를 정확히 한 번 재개하고 시간 제한 작업을 정리합니다.
  private func finish(_ result: Result<PermissionStatus, PermissionError>) {
    guard !waiters.isEmpty else { return }
    deadlineTask?.cancel()
    deadlineTask = nil
    let continuations = waiters
    waiters.removeAll()
    for continuation in continuations { continuation.resume(returning: result) }
  }

  /// 사용 중 접근을 전체 Always 접근으로 오판하지 않습니다.
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
