//
//  PermissionClientTests.swift
//  AsyncPermissionsTests
//
//  Created by NHN on 2026/10/01.
//  Copyright © 2026 com.nhnedu.pinkdiary. All rights reserved.
//

import AVFoundation
import Photos
import Testing
@testable import AsyncPermissions

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
  @Test(arguments: [PermissionKind.camera, .photosReadWrite, .photosAddOnly])
  func requestsUndeterminedPermission(_ permission: PermissionKind) async throws {
    let driver = PermissionDriverDouble()
    driver.response = .authorized
    let client = PermissionCoordinator(driver: driver)
    #expect(try await client.request(permission) == .authorized)
    #expect(driver.requestedPermissions == [permission])
  }

  /// 설정에서 권한을 변경한 경우 캐시 없이 최신 상태를 조회합니다.
  @Test
  func refreshesStatusAfterSettingsChange() {
    let driver = PermissionDriverDouble()
    let client = PermissionCoordinator(driver: driver)
    #expect(client.status(for: .camera) == .notDetermined)
    driver.currentStatus = .denied
    #expect(client.status(for: .camera) == .denied)
    driver.currentStatus = .authorized
    #expect(client.status(for: .camera) == .authorized)
  }

  /// 사진 limited는 허용으로 판단하되 거부·제한·미지원 상태는 허용하지 않습니다.
  @Test
  func mapsPlatformStatuses() {
    #expect(SystemPermissionDriver.mapPhotoStatus(.limited) == .limited)
    #expect(SystemPermissionDriver.mapPhotoStatus(.authorized) == .authorized)
    #expect(SystemPermissionDriver.mapPhotoStatus(.notDetermined) == .notDetermined)
    #expect(SystemPermissionDriver.mapPhotoStatus(.denied) == .denied)
    #expect(SystemPermissionDriver.mapPhotoStatus(.restricted) == .restricted)
    #expect(SystemPermissionDriver.mapCameraStatus(.authorized) == .authorized)
    #expect(SystemPermissionDriver.mapCameraStatus(.denied) == .denied)
    #expect(SystemPermissionDriver.mapCameraStatus(.restricted) == .restricted)
    #expect(SystemPermissionDriver.mapCameraStatus(.notDetermined) == .notDetermined)
    #expect(PermissionStatus.limited.isGranted)
    #expect(PermissionStatus.authorized.isGranted)
    #expect(PermissionStatus.notDetermined.isGranted == false)
    #expect(PermissionStatus.denied.isGranted == false)
    #expect(PermissionStatus.restricted.isGranted == false)
    #expect(PermissionStatus.unknown.isGranted == false)
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
}

@MainActor
private final class PermissionDriverDouble: PermissionDriving {
  var currentStatus: PermissionStatus = .notDetermined
  var response: PermissionStatus = .denied
  var requestedPermissions: [PermissionKind] = []
  var shouldSuspend = false
  private var pendingResponse: CheckedContinuation<PermissionStatus, Never>?
  private var requestObserver: CheckedContinuation<Void, Never>?
  private var statusQueryCount = 0
  private var expectedStatusQueryCount = 0
  private var statusQueryObserver: CheckedContinuation<Void, Never>?

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
  func request(_ permission: PermissionKind) async -> PermissionStatus {
    requestedPermissions.append(permission)
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
