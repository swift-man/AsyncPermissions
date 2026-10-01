//
//  DelegatePermissionTests.swift
//  AppPermissionsSystemTests
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import AppPermissions
import CoreLocation
import CoreBluetooth
import Testing
@testable import AppPermissionsLocation
@testable import AppPermissionsBluetooth

@MainActor
struct DelegatePermissionTests {
  /// 위치 콜백 누락은 시간 초과로 종료되며 다음 요청을 다시 수행할 수 있습니다.
  @Test
  func locationTimeoutAndRetry() async throws {
    let manager = LocationManagerDouble()
    let deadline = DeadlineDouble()
    let driver = LocationPermissionDriver(
      manager: manager,
      waitForDeadline: { try await deadline.wait() },
      hasUsageDescription: { _ in true }
    )
    let request = Task { try await driver.request(.locationWhenInUse) }
    await manager.waitUntilRequested()
    manager.onChange?(.notDetermined)
    deadline.fire()
    do {
      _ = try await request.value
      Issue.record("콜백 누락은 시간 초과 오류여야 합니다.")
    } catch { #expect(error as? PermissionError == .timedOut) }
    manager.authorizationStatus = .authorizedAlways
    #expect(try await driver.request(.locationWhenInUse) == .authorized)
    #expect(manager.requestCount == 1)
  }

  /// 미결정 콜백을 무시하고 여러 대기자에게 한 요청의 결과를 전달합니다.
  @Test
  func locationSharesWaiters() async throws {
    let manager = LocationManagerDouble()
    let deadline = DeadlineDouble()
    let driver = LocationPermissionDriver(
      manager: manager,
      waitForDeadline: { try await deadline.wait() },
      hasUsageDescription: { _ in true }
    )
    let first = Task { try await driver.request(.locationWhenInUse) }
    await manager.waitUntilRequested()
    let started = AsyncStream<Void>.makeStream()
    let second = Task { @MainActor in
      started.continuation.yield(())
      return try await driver.request(.locationWhenInUse)
    }
    var iterator = started.stream.makeAsyncIterator()
    _ = await iterator.next()
    manager.onChange?(.notDetermined)
    manager.authorizationStatus = .authorizedAlways
    manager.onChange?(.authorizedAlways)
    #expect(try await first.value == .authorized)
    #expect(try await second.value == .authorized)
    #expect(manager.requestCount == 1)
    started.continuation.finish()
  }

  /// 사용 사유가 없으면 OS를 호출하지 않습니다.
  @Test
  func rejectsMissingLocationUsageDescription() async {
    let manager = LocationManagerDouble()
    let driver = LocationPermissionDriver(
      manager: manager,
      waitForDeadline: {},
      hasUsageDescription: { _ in false }
    )
    do {
      _ = try await driver.request(.locationWhenInUse)
      Issue.record("설정 누락은 요청 전에 거절해야 합니다.")
    } catch {
      #if os(macOS)
      #expect(error == .missingUsageDescription(key: "NSLocationUsageDescription"))
      #else
      #expect(error == .missingUsageDescription(key: "NSLocationWhenInUseUsageDescription"))
      #endif
    }
    #expect(manager.requestCount == 0)
  }

  /// 플랫폼에 맞는 사용 사유 키만 설정해도 위치 요청을 시작할 수 있습니다.
  @Test
  func acceptsPlatformLocationUsageDescription() async throws {
    let manager = LocationManagerDouble()
    let deadline = DeadlineDouble()
    let driver = LocationPermissionDriver(
      manager: manager,
      waitForDeadline: { try await deadline.wait() },
      hasUsageDescription: { key in
        #if os(macOS)
        return key == "NSLocationUsageDescription"
        #else
        return key == "NSLocationWhenInUseUsageDescription"
        #endif
      }
    )
    let request = Task { try await driver.request(.locationWhenInUse) }
    await manager.waitUntilRequested()
    manager.authorizationStatus = .authorizedAlways
    manager.onChange?(.authorizedAlways)
    #expect(try await request.value == .authorized)
    #expect(manager.requestCount == 1)
  }

  /// Always 승격이 보류되더라도 무기한 대기하지 않습니다.
  @Test
  func alwaysUpgradeReturnsCurrentScope() async throws {
    #if os(iOS)
    let manager = LocationManagerDouble()
    manager.authorizationStatus = .authorizedWhenInUse
    let driver = LocationPermissionDriver(
      manager: manager,
      waitForDeadline: {},
      hasUsageDescription: { _ in true }
    )
    #expect(try await driver.request(.locationAlways) == .whenInUse)
    #expect(manager.alwaysRequestCount == 1)
    #endif
  }

  /// Bluetooth 콜백 누락 시 관리자를 정리하고 다음 요청이 고착되지 않습니다.
  @Test
  func bluetoothTimeoutAndRetry() async throws {
    let manager = BluetoothManagerDouble()
    let deadline = DeadlineDouble()
    let driver = BluetoothPermissionDriver(manager: manager, waitForDeadline: { try await deadline.wait() })
    let request = Task { try await driver.request() }
    await manager.waitUntilStarted()
    deadline.fire()
    do {
      _ = try await request.value
      Issue.record("콜백 누락은 시간 초과 오류여야 합니다.")
    } catch { #expect(error as? PermissionError == .timedOut) }
    #expect(manager.stopCount == 1)
    manager.authorization = .denied
    #expect(try await driver.request() == .denied)
    #expect(manager.startCount == 1)
  }

  /// 전원과 무관한 허용 콜백을 공유하고 중복 콜백으로 대기자를 재개하지 않습니다.
  @Test
  func bluetoothSharesWaitersAndCleansUp() async throws {
    let manager = BluetoothManagerDouble()
    let deadline = DeadlineDouble()
    let driver = BluetoothPermissionDriver(manager: manager, waitForDeadline: { try await deadline.wait() })
    let first = Task { try await driver.request() }
    await manager.waitUntilStarted()
    let started = AsyncStream<Void>.makeStream()
    let second = Task { @MainActor in
      started.continuation.yield(())
      return try await driver.request()
    }
    var iterator = started.stream.makeAsyncIterator()
    _ = await iterator.next()
    manager.onChange?(.notDetermined, false)
    manager.authorization = .allowedAlways
    manager.onChange?(.allowedAlways, false)
    #expect(try await first.value == .authorized)
    #expect(try await second.value == .authorized)
    #expect(manager.startCount == 1)
    manager.onChange?(.allowedAlways, false)
    #expect(manager.stopCount == 1)
    started.continuation.finish()
  }

  /// 장치 미지원은 권한 거부나 미결정 성공으로 반환하지 않습니다.
  @Test
  func bluetoothUnsupportedHardware() async {
    let manager = BluetoothManagerDouble()
    let deadline = DeadlineDouble()
    let driver = BluetoothPermissionDriver(manager: manager, waitForDeadline: { try await deadline.wait() })
    let request = Task { try await driver.request() }
    await manager.waitUntilStarted()
    manager.onChange?(.notDetermined, true)
    do {
      _ = try await request.value
      Issue.record("미지원 장치는 명시적 오류여야 합니다.")
    } catch { #expect(error as? PermissionError == .unsupported) }
    #expect(manager.stopCount == 1)
  }
}

@MainActor
private final class DeadlineDouble {
  private let signal = AsyncStream<Void>.makeStream()

  /// 시간 지연 없이 테스트가 지정한 순간을 기다리며 취소에 반응합니다.
  func wait() async throws {
    var iterator = signal.stream.makeAsyncIterator()
    guard await iterator.next() != nil else { throw CancellationError() }
  }

  /// 시간 제한을 결정적으로 발생시킵니다.
  func fire() {
    signal.continuation.yield(())
    signal.continuation.finish()
  }
}

@MainActor
private final class LocationManagerDouble: LocationAuthorizationManaging {
  var authorizationStatus: CLAuthorizationStatus = .notDetermined
  var onChange: (@MainActor (CLAuthorizationStatus) -> Void)?
  var requestCount = 0
  var alwaysRequestCount = 0
  private let requested = AsyncStream<Void>.makeStream()

  /// 위치 OS 요청을 기록합니다.
  func requestWhenInUse() {
    requestCount += 1
    requested.continuation.yield(())
  }

  /// Always 승격 요청을 기록합니다.
  func requestAlways() {
    alwaysRequestCount += 1
    requestWhenInUse()
  }

  /// 요청이 발생한 뒤 테스트를 진행합니다.
  func waitUntilRequested() async {
    var iterator = requested.stream.makeAsyncIterator()
    _ = await iterator.next()
  }
}

@MainActor
private final class BluetoothManagerDouble: BluetoothAuthorizationManaging {
  var authorization: CBManagerAuthorization = .notDetermined
  var onChange: (@MainActor (CBManagerAuthorization, Bool) -> Void)?
  var startCount = 0
  var stopCount = 0
  private let started = AsyncStream<Void>.makeStream()

  /// 관리자 시작을 기록합니다.
  func start() {
    startCount += 1
    started.continuation.yield(())
  }

  /// 관리자 해제를 기록합니다.
  func stop() { stopCount += 1 }

  /// 관리자가 시작한 뒤 콜백을 전달합니다.
  func waitUntilStarted() async {
    var iterator = started.stream.makeAsyncIterator()
    _ = await iterator.next()
  }
}
