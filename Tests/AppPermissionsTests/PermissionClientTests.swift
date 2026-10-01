//
//  PermissionClientTests.swift
//  AppPermissionsTests
//
//  Created by Gorani on 2026/10/01.
//  Copyright © 2026 Gorani. All rights reserved.
//

import Testing
@testable import AppPermissions

@MainActor
struct PermissionClientTests {
  /// 결정된 권한에는 시스템 팝업을 다시 요청하지 않습니다.
  @Test(arguments: [PermissionStatus.authorized, .limited, .denied, .restricted, .unknown])
  func determinedStatusDoesNotRequest(_ status: PermissionStatus) async throws {
    let driver = PermissionDriverDouble()
    driver.currentStatus = status
    let client = PermissionCoordinator(driver: driver)
    #expect(try await client.request(.photosReadWrite) == status)
    #expect(driver.requestedPermissions.isEmpty)
  }

  /// 읽기·추가 전용 사진 요청의 종류를 그대로 전달합니다.
  @Test(arguments: [
    PermissionKind.camera, .photosReadWrite, .photosAddOnly, .microphone,
    .locationWhenInUse, .locationAlways, .bluetooth, .calendarFullAccess,
    .calendarWriteOnly, .reminders, .contacts, .notifications(), .tracking
  ])
  func requestsUndeterminedPermission(_ permission: PermissionKind) async throws {
    let driver = PermissionDriverDouble()
    driver.response = .authorized
    let client = PermissionCoordinator(driver: driver)
    #expect(try await client.request(permission) == .authorized)
    #expect(driver.requestedPermissions == [permission])
  }

  /// 설정에서 권한을 변경한 경우 캐시 없이 최신 상태를 조회합니다.
  @Test
  func refreshesStatusAfterSettingsChange() async {
    let driver = PermissionDriverDouble()
    let client = PermissionCoordinator(driver: driver)
    #expect(await client.status(for: .camera) == .notDetermined)
    driver.currentStatus = .denied
    #expect(await client.status(for: .camera) == .denied)
    driver.currentStatus = .authorized
    #expect(await client.status(for: .camera) == .authorized)
  }

  /// 사진 limited는 허용으로 판단하되 거부·제한·미지원 상태는 허용하지 않습니다.
  @Test
  func mapsPlatformStatuses() {
    #expect(PermissionStatus.limited.isGranted)
    #expect(PermissionStatus.authorized.isGranted)
    #expect(PermissionStatus.notDetermined.isGranted == false)
    #expect(PermissionStatus.denied.isGranted == false)
    #expect(PermissionStatus.restricted.isGranted == false)
    #expect(PermissionStatus.unknown.isGranted == false)
    #expect(PermissionStatus.whenInUse.isGranted)
    #expect(PermissionStatus.writeOnly.isGranted)
    #expect(PermissionStatus.provisional.isGranted)
    #expect(PermissionStatus.ephemeral.isGranted)
  }

  /// 동시 호출자는 한 시스템 요청을 공유하며 한 호출자의 취소는 다른 호출자를 취소하지 않습니다.
  @Test
  func sharesPendingRequestAndSeparatesCancellation() async throws {
    let driver = PermissionDriverDouble()
    driver.shouldSuspend = true
    let client = PermissionCoordinator(driver: driver)
    let cancelledRequest = Task { try await client.request(.camera) }
    await driver.waitUntilRequested()
    let remainingRequest = Task { try await client.request(.camera) }
    await driver.waitUntilStatusQueried(count: 2)
    cancelledRequest.cancel()
    driver.complete(with: .authorized)
    do {
      _ = try await cancelledRequest.value
      Issue.record("취소된 요청은 권한 결과를 반환하지 않아야 합니다.")
    } catch {
      #expect(error as? PermissionError == .cancelled)
    }
    #expect(try await remainingRequest.value == .authorized)
    #expect(driver.requestedPermissions == [.camera])
  }

  /// 요청 시작 전의 취소는 OS 권한 요청을 발생시키지 않습니다.
  @Test
  func cancellationBeforeRequest() async {
    let driver = PermissionDriverDouble()
    let client = PermissionCoordinator(driver: driver)
    let request = Task {
      withUnsafeCurrentTask { $0?.cancel() }
      return try await client.request(.camera)
    }
    do {
      _ = try await request.value
      Issue.record("취소된 요청은 명시적 취소 오류를 반환해야 합니다.")
    } catch {
      #expect(error as? PermissionError == .cancelled)
    }
    #expect(driver.requestedPermissions.isEmpty)
  }

  /// 공개 프로토콜 타입도 Sendable 계약으로 전달할 수 있습니다.
  @Test
  func publicContractIsSendable() {
    let client: any PermissionRequesting = PermissionClient()
    requireSendable(client)
  }

  /// 시스템이 미결정 상태를 반환해도 자동으로 재요청하지 않습니다.
  @Test
  func preservesUndeterminedResponse() async throws {
    let driver = PermissionDriverDouble()
    driver.response = .notDetermined
    let client = PermissionCoordinator(driver: driver)
    #expect(try await client.request(.camera) == .notDetermined)
    #expect(driver.requestedPermissions == [.camera])
  }

  /// 컴파일 시 공개 계약의 Sendable 준수를 검증합니다.
  private func requireSendable<Value: Sendable>(_ value: Value) {}

  /// 미등록 권한은 구현 자동 생성 없이 미지원 오류를 반환합니다.
  @Test
  func unregisteredPermissionsDoNotCreateProviders() async {
    let client = PermissionClient()
    #expect(await client.status(for: .camera) == .unknown)
    do {
      _ = try await client.request(.camera)
      Issue.record("미등록 권한은 거부해야 합니다.")
    } catch { #expect(error == .unsupported) }
  }

  /// 선택한 구현만 호출하고 다른 구현에는 요청을 전달하지 않습니다.
  @Test
  func routesOnlyToSelectedProvider() async throws {
    let cameraDriver = PermissionDriverDouble()
    cameraDriver.supportedPermission = .camera
    cameraDriver.response = .authorized
    let photosDriver = PermissionDriverDouble()
    photosDriver.supportedPermission = .photosReadWrite
    let client = PermissionClient(providers: [cameraDriver, photosDriver])
    #expect(try await client.request(.camera) == .authorized)
    #expect(cameraDriver.requestedPermissions == [.camera])
    #expect(photosDriver.requestedPermissions.isEmpty)
    #expect(await client.status(for: .tracking) == .unknown)
  }

  /// 제한된 접근에서 필요한 권한 승격만 허용합니다.
  @Test
  func requestsOnlySupportedScopeUpgrades() {
    #expect(PermissionCoordinator.shouldRequest(.locationAlways, status: .whenInUse))
    #expect(!PermissionCoordinator.shouldRequest(.locationWhenInUse, status: .whenInUse))
    #expect(PermissionCoordinator.shouldRequest(.calendarFullAccess, status: .writeOnly))
    #expect(!PermissionCoordinator.shouldRequest(.calendarWriteOnly, status: .writeOnly))
    #expect(PermissionCoordinator.shouldRequest(.notifications(), status: .provisional))
    #expect(!PermissionCoordinator.shouldRequest(.notifications(options: [.provisional]), status: .provisional))
    #expect(!PermissionCoordinator.shouldRequest(.contacts, status: .limited))
  }

  /// 시스템 오류와 취소 오류를 공개 typed throws 계약으로 보존합니다.
  @Test
  func preservesTypedSystemErrors() async {
    let driver = PermissionDriverDouble()
    driver.requestError = .systemFailure(domain: "Test", code: 42)
    let client = PermissionClient(providers: [driver])
    do {
      _ = try await client.request(.contacts)
      Issue.record("시스템 오류가 보존되어야 합니다.")
    } catch { #expect(error == .systemFailure(domain: "Test", code: 42)) }
    #expect(PermissionError.systemError(CancellationError()) == .cancelled)
    #expect(PermissionError.systemError(PermissionError.unsupported) == .unsupported)
  }
}

@MainActor
private final class PermissionDriverDouble: PermissionProviding {
  var currentStatus: PermissionStatus = .notDetermined
  var response: PermissionStatus = .denied
  var requestedPermissions: [PermissionKind] = []
  var shouldSuspend = false
  var supportedPermission: PermissionKind?
  var requestError: PermissionError?
  private var pendingResponse: CheckedContinuation<PermissionStatus, Never>?
  private var requestObserver: CheckedContinuation<Void, Never>?
  private var statusQueryCount = 0
  private var expectedStatusQueryCount = 0
  private var statusQueryObserver: CheckedContinuation<Void, Never>?

  /// 공통 요청 조정 테스트에서는 모든 권한을 지원합니다.
  func supports(_ permission: PermissionKind) -> Bool {
    supportedPermission == nil || supportedPermission == permission
  }

  /// 테스트에서 설정 변경을 재현합니다.
  func status(for permission: PermissionKind) -> PermissionStatus {
    statusQueryCount += 1
    if statusQueryCount >= expectedStatusQueryCount {
      statusQueryObserver?.resume()
      statusQueryObserver = nil
    }
    return currentStatus
  }

  /// 두 번째 호출의 동기 상태 조회와 공유 요청 선택이 끝난 뒤 테스트를 재개합니다.
  func waitUntilStatusQueried(count: Int) async {
    if statusQueryCount >= count { return }
    expectedStatusQueryCount = count
    await withCheckedContinuation { statusQueryObserver = $0 }
  }

  /// 주입된 응답 또는 명시적으로 완료하는 요청을 사용합니다.
  func request(_ permission: PermissionKind) async throws(PermissionError) -> PermissionStatus {
    requestedPermissions.append(permission)
    if let requestError { throw requestError }
    if shouldSuspend {
      return await withCheckedContinuation { continuation in
        pendingResponse = continuation
        requestObserver?.resume()
        requestObserver = nil
      }
    }
    currentStatus = response
    return response
  }

  /// 요청 등록을 시간 지연 없이 기다립니다.
  func waitUntilRequested() async {
    if pendingResponse != nil { return }
    await withCheckedContinuation { requestObserver = $0 }
  }

  /// 공유 요청을 한 번 완료합니다.
  func complete(with status: PermissionStatus) {
    currentStatus = status
    pendingResponse?.resume(returning: status)
    pendingResponse = nil
  }
}
