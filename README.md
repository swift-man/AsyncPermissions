# AppPermissions

필요한 OS 권한 구현만 선택하는 Swift Package입니다. 저장소 주소는 AsyncPermissions이며 패키지·공통 product 이름은 AppPermissions입니다.
Swift 6.0+, iOS 15+, macOS 13+를 지원합니다. 외부 의존성과 앱 코드가 없습니다.

## 선택적 설치

Xcode에서 이 저장소를 추가하고 필요한 product만 선택합니다. 전체 구현을 묶는 umbrella product는 제공하지 않습니다.

| Product | 요청 종류 | OS 프레임워크 |
| --- | --- | --- |
| AppPermissions | 공통 계약·상태·요청 공유 | Foundation만 |
| AppPermissionsCamera | camera | AVFoundation |
| AppPermissionsPhotos | photosReadWrite / photosAddOnly | Photos |
| AppPermissionsMicrophone | microphone | AVFoundation |
| AppPermissionsLocation | locationWhenInUse / locationAlways | CoreLocation |
| AppPermissionsBluetooth | bluetooth | CoreBluetooth |
| AppPermissionsCalendar | calendarFullAccess / calendarWriteOnly | EventKit |
| AppPermissionsReminders | reminders | EventKit |
| AppPermissionsContacts | contacts | Contacts |
| AppPermissionsNotifications | notifications(options:) | UserNotifications |
| AppPermissionsTracking | tracking | AppTrackingTransparency (iOS만) |

구현 target은 공통 target에만 의존합니다. 공통 target은 구현 target을 참조하지 않습니다.
SPM은 저장소를 내려받지만 소비 앱이 선택하지 않은 product는 앱 링크 의존성에 포함하지 않습니다.
전체 패키지 테스트는 모든 구현을 검증하므로 모든 target을 빌드합니다.

## 사용

카메라만 필요한 소비자는 AppPermissions와 AppPermissionsCamera만 연결합니다.

```swift
import AppPermissions
import AppPermissionsCamera

@MainActor
func cameraAccess(using permissionClient: any PermissionRequesting) async throws(PermissionError) -> PermissionStatus {
  try await permissionClient.request(.camera)
}

// 조립 지점: let permissionClient = PermissionClient(providers: [CameraPermissionProvider()])
```

조립 지점에서 클라이언트를 한 번 만들고 PermissionRequesting으로 주입합니다.
동일 클라이언트의 동일 요청은 공유됩니다. 등록한 provider 순서에서 처음 지원하는 구현을 선택하므로 한 범위의 구현은 하나만 등록합니다.
기본 initializer는 구현을 등록하지 않습니다. 미등록 권한의 조회는 unknown, 요청은 unsupported입니다.
등록 및 supports 조회는 OS 관리자를 자동 생성하지 않습니다. 위치·Bluetooth 관리자는 실제 해당 기능 사용 시 지연 생성합니다.

## 공개 계약 변경

기존 AsyncPermissions product/import는 AppPermissions로 변경합니다.
PermissionClient()의 기본 시스템 구현 생성은 제거하고 providers를 명시적으로 전달합니다.
status(for:)는 알림의 비동기 OS 설정 조회를 지원하도록 async로 변경했습니다.
이번 변경에는 소비 앱 연동이 포함되지 않습니다.

## 상태와 오류

notDetermined / authorized / limited / denied / restricted / unknown 외에 whenInUse / writeOnly / provisional / ephemeral을 구분합니다.
isGranted는 일부 접근이라도 허용되었는지를 뜻하며 요청한 전체 접근 범위 충족을 보장하지 않습니다.
예를 들어 Always 위치는 authorized, 전체 캘린더 접근은 authorized인지 직접 확인합니다.
limited 사진·연락처는 전체 데이터 접근이 아닙니다.

PermissionError는 cancelled, unsupported, timedOut, missingUsageDescription(key:), systemFailure(domain:code:)를 구분합니다.
거부는 오류가 아니라 상태입니다. 시스템 오류를 빈 결과나 denied로 숨기지 않습니다.
취소된 호출자는 공유 요청이 OS 응답 또는 드라이버 시간 초과로 끝난 뒤 cancelled를 받습니다. 실제 OS 팝업과 공유 작업은 취소하지 않습니다.

## 범위별 동작

- 미결정 권한과 명시적인 범위 승격(WhenInUse → Always, 캘린더 writeOnly → fullAccess, 알림 provisional → 일반 요청)만 요청합니다.
- 상태는 OS에서 매번 조회하며 자체 저장·캐시하지 않습니다. OS가 notDetermined를 유지하면 그대로 반환하며 자동 재요청하지 않습니다.
- Bluetooth Central/Peripheral은 현대 OS의 공유 Bluetooth 권한 하나로 표현합니다. 스캔·연결·광고는 수행하지 않으며 전원 꺼짐을 거부로 오판하지 않습니다.
- 위치·Bluetooth 초기 요청은 60초 안에 콜백이 없으면 현재 권한을 다시 확인합니다. 여전히 미결정이면 timedOut으로 대기를 정리합니다. 위치 사용 사유 누락은 missingUsageDescription으로 요청 전에 거절합니다. 시간 초과는 OS 팝업 취소나 자동 재요청을 뜻하지 않습니다.
- Bluetooth 하드웨어 미지원은 request에서 unsupported입니다. 조회는 하드웨어 관리자를 생성하지 않고 OS 접근 권한만 반환하므로 미지원 장치에서도 notDetermined일 수 있습니다.
- 옵션이나 접근 범위가 다른 요청은 별도 공유 키를 사용합니다. 알림 옵션을 버리거나 캘린더 쓰기 전용을 전체 접근과 합치지 않습니다. 소비 앱이 서로 다른 범위의 요청 순서를 조정해야 합니다.
- Always 위치 최초 요청은 최초 OS 선택을 기다립니다. 기존 WhenInUse에서 Always 승격은 OS가 프롬프트를 보류하거나 Allow Once에서 무시할 수 있으므로 요청 후 현재 범위를 즉시 반환합니다. 이후 상태를 다시 조회해야 하며 즉시 Always 획득을 보장하지 않습니다.
- 동시에 다른 위치 범위를 요청하면 최초 진행 중 OS 선택을 공유하므로 반환된 범위를 확인하고 필요한 승격을 별도로 요청합니다. 위치 좌표 조회는 수행하지 않습니다.
- macOS는 locationAlways 및 ATT 요청을 지원하지 않습니다.
- iOS 17 / macOS 14 이상은 EventKit fullAccess/writeOnly 및 미리 알림 fullAccess API를 사용합니다. 구 OS에서는 캘린더 전체 접근과 미리 알림만 레거시 API를 사용합니다. 쓰기 전용 요청을 전체 요청으로 확대하지 않고 unsupported를 반환합니다.
- 알림 기본 옵션은 alert/sound/badge이며 provisional을 선택할 수 있습니다. 설정 값의 세부 알림 채널 변경, APNs 등록, 푸시 토큰 및 광고 동의는 담당하지 않습니다.
- ATT 호출자는 앱 활성 상태와 다른 시스템 팝업 종료를 보장해야 합니다. 패키지는 UIKit·앱 생명주기·IDFA·광고 SDK에 의존하지 않습니다.
- 안내 UI, 설정 앱 이동, 제한적 사진 선택기, 권한 복귀 재조회는 소비 앱에서 처리합니다.
- 다양한 종류의 OS 팝업을 동시에 요청하지 않도록 소비 앱이 요청 순서를 관리합니다.

## 앱 설정

선택한 권한만 Info.plist 사용 사유와 필요한 sandbox entitlement를 구성합니다.
키 누락 시 OS가 앱을 종료할 수 있으며 패키지가 앱 설정을 대신 수정하지 않습니다.

| 권한 | iOS 사용 사유 키 |
| --- | --- |
| 카메라 | NSCameraUsageDescription |
| 사진 읽기·쓰기 / 추가 | NSPhotoLibraryUsageDescription / NSPhotoLibraryAddUsageDescription |
| 마이크 | NSMicrophoneUsageDescription |
| 위치 | NSLocationWhenInUseUsageDescription / Always 사용 시 NSLocationAlwaysAndWhenInUseUsageDescription도 필요 |
| Bluetooth | NSBluetoothAlwaysUsageDescription |
| 연락처 | NSContactsUsageDescription |
| 캘린더 | 구 OS: NSCalendarsUsageDescription / iOS 17+: NSCalendarsFullAccessUsageDescription 또는 NSCalendarsWriteOnlyAccessUsageDescription |
| 미리 알림 | 구 OS: NSRemindersUsageDescription / iOS 17+: NSRemindersFullAccessUsageDescription |
| ATT | NSUserTrackingUsageDescription |
| 알림 | 사용 사유 키 없음. capabilities와 APNs 등록은 소비 앱 책임 |

macOS 위치 권한은 NSLocationUsageDescription을 사용합니다. macOS 앱은 각 기능의 entitlement와 OS 버전별 사용 사유를 별도로 구성합니다.

## 구조와 검증

각 target은 Sources/<모듈>/Public 및 Private 경계를 사용합니다.
Public에는 공개 타입·계약을, Private에는 요청 조정·delegate·상태 변환 구현을 둡니다.
공개 타입의 private 저장 프로퍼티는 해당 타입에 유지합니다. 폴더명만으로 접근 수준이 제한되는 것은 아닙니다.

```sh
swift build --target AppPermissions
swift test
xcodebuild -scheme AppPermissions-Package -destination 'generic/platform=iOS Simulator' build
```

Swift Testing은 OS 팝업 없이 공통 요청 공유·취소·선택적 등록·접근 범위 승격·오류 보존과 플랫폼 상태 매핑을 검증합니다.
실제 권한 팝업·설정 왕복·Always 보류·Bluetooth 전원 꺼짐·ATT 활성 상태는 실기기 검증이 별도로 필요합니다.
