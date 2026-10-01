//
//  SystemPermissionTests.swift
//  AppPermissionsSystemTests
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import AVFoundation
import Photos
import Contacts
import EventKit
import CoreBluetooth
import CoreLocation
import UserNotifications
import AppPermissions
import Testing
@testable import AppPermissionsCamera
@testable import AppPermissionsPhotos
@testable import AppPermissionsMicrophone
@testable import AppPermissionsLocation
@testable import AppPermissionsBluetooth
@testable import AppPermissionsCalendar
@testable import AppPermissionsReminders
@testable import AppPermissionsContacts
@testable import AppPermissionsNotifications
@testable import AppPermissionsTracking
#if os(iOS)
import AppTrackingTransparency
#endif

@MainActor
struct SystemPermissionTests {
  /// 권한 상태 변환은 실제 OS 팝업 없이 검증합니다.
  @Test
  func mapsCaptureAndPhotoStatuses() {
    #expect(CameraPermissionProvider.mapStatus(.authorized) == .authorized)
    #expect(CameraPermissionProvider.mapStatus(.notDetermined) == .notDetermined)
    #expect(CameraPermissionProvider.mapStatus(.denied) == .denied)
    #expect(CameraPermissionProvider.mapStatus(.restricted) == .restricted)
    #expect(MicrophonePermissionProvider.mapStatus(.authorized) == .authorized)
    #expect(MicrophonePermissionProvider.mapStatus(.notDetermined) == .notDetermined)
    #expect(MicrophonePermissionProvider.mapStatus(.denied) == .denied)
    #expect(MicrophonePermissionProvider.mapStatus(.restricted) == .restricted)
    #expect(PhotosPermissionProvider.mapStatus(.limited) == .limited)
    #expect(PhotosPermissionProvider.mapStatus(.authorized) == .authorized)
    #expect(PhotosPermissionProvider.mapStatus(.notDetermined) == .notDetermined)
    #expect(PhotosPermissionProvider.mapStatus(.denied) == .denied)
    #expect(PhotosPermissionProvider.mapStatus(.restricted) == .restricted)
  }

  /// 위치의 사용 중 허용과 Bluetooth 권한은 서로 다른 범위로 유지합니다.
  @Test
  func mapsLocationAndBluetoothStatuses() {
    #if os(iOS)
    #expect(LocationPermissionDriver.mapStatus(.authorizedWhenInUse) == .whenInUse)
    #endif
    #expect(LocationPermissionDriver.mapStatus(.authorizedAlways) == .authorized)
    #expect(LocationPermissionDriver.mapStatus(.notDetermined) == .notDetermined)
    #expect(LocationPermissionDriver.mapStatus(.denied) == .denied)
    #expect(LocationPermissionDriver.mapStatus(.restricted) == .restricted)
    #expect(BluetoothPermissionDriver.mapStatus(.allowedAlways) == .authorized)
    #expect(BluetoothPermissionDriver.mapStatus(.notDetermined) == .notDetermined)
    #expect(BluetoothPermissionDriver.mapStatus(.denied) == .denied)
    #expect(BluetoothPermissionDriver.mapStatus(.restricted) == .restricted)
  }

  /// 연락처와 EventKit의 접근 범위를 구분합니다.
  @Test
  func mapsContactsAndEventStatuses() {
    #expect(ContactsPermissionProvider.mapStatus(.authorized) == .authorized)
    #expect(ContactsPermissionProvider.mapStatus(.denied) == .denied)
    #expect(ContactsPermissionProvider.mapStatus(.restricted) == .restricted)
    #expect(ContactsPermissionProvider.mapStatus(.notDetermined) == .notDetermined)
    #if os(iOS)
    if #available(iOS 18, *) {
      #expect(ContactsPermissionProvider.mapStatus(.limited) == .limited)
    }
    #endif
    #expect(CalendarPermissionProvider.mapStatus(.notDetermined) == .notDetermined)
    #expect(CalendarPermissionProvider.mapStatus(.denied) == .denied)
    #expect(CalendarPermissionProvider.mapStatus(.restricted) == .restricted)
    #expect(RemindersPermissionProvider.mapStatus(.notDetermined) == .notDetermined)
    #expect(RemindersPermissionProvider.mapStatus(.denied) == .denied)
    #expect(RemindersPermissionProvider.mapStatus(.restricted) == .restricted)
    if #available(iOS 17, macOS 14, *) {
      #expect(CalendarPermissionProvider.mapStatus(.writeOnly) == .writeOnly)
      #expect(CalendarPermissionProvider.mapStatus(.fullAccess) == .authorized)
      #expect(RemindersPermissionProvider.mapStatus(.fullAccess) == .authorized)
    }
  }

  /// 알림 옵션 변환과 임시 허용 상태를 보존합니다.
  @Test
  func mapsNotificationAndTrackingStatuses() {
    #expect(NotificationsPermissionProvider.mapStatus(.authorized) == .authorized)
    #expect(NotificationsPermissionProvider.mapStatus(.denied) == .denied)
    #expect(NotificationsPermissionProvider.mapStatus(.notDetermined) == .notDetermined)
    #expect(NotificationsPermissionProvider.mapStatus(.provisional) == .provisional)
    #expect(NotificationsPermissionProvider.systemOptions(.standard) == [.alert, .sound, .badge])
    #expect(NotificationsPermissionProvider.systemOptions([.badge, .provisional]) == [.badge, .provisional])
    #if os(iOS)
    #expect(NotificationsPermissionProvider.mapStatus(.ephemeral) == .ephemeral)
    #expect(TrackingPermissionProvider.mapStatus(.authorized) == .authorized)
    #expect(TrackingPermissionProvider.mapStatus(.notDetermined) == .notDetermined)
    #expect(TrackingPermissionProvider.mapStatus(.denied) == .denied)
    #expect(TrackingPermissionProvider.mapStatus(.restricted) == .restricted)
    #endif
  }

  /// 구현별 담당 권한을 확인하고 다른 권한 요청은 OS 호출 전에 거절합니다.
  @Test
  func providersRejectUnrelatedPermissions() async {
    let providers: [any PermissionProviding] = [
      CameraPermissionProvider(), PhotosPermissionProvider(), MicrophonePermissionProvider(),
      LocationPermissionProvider(), BluetoothPermissionProvider(), CalendarPermissionProvider(),
      RemindersPermissionProvider(), ContactsPermissionProvider(), NotificationsPermissionProvider(),
      TrackingPermissionProvider()
    ]
    for provider in providers {
      let unrelated: PermissionKind = provider.supports(.camera) ? .contacts : .camera
      #expect(await provider.status(for: unrelated) == .unknown)
      do {
        _ = try await provider.request(unrelated)
        Issue.record("담당하지 않는 권한을 요청하면 안 됩니다.")
      } catch { #expect(error == .unsupported) }
    }
  }

  /// 미지원 옵션 비트는 OS 팝업 요청 전에 명시적으로 거절합니다.
  @Test
  func rejectsUnknownNotificationOptions() async {
    let provider = NotificationsPermissionProvider()
    do {
      _ = try await provider.request(.notifications(options: .init(rawValue: 1 << 20)))
      Issue.record("정의되지 않은 알림 옵션은 거절해야 합니다.")
    } catch { #expect(error == .unsupported) }
  }
}
