# AsyncPermissions

카메라와 사진 라이브러리의 OS 권한만 조회·요청하는 독립 Swift Package입니다.
앱, UIKit, DI 컨테이너, 네트워크, 저장소 및 권한 안내 UI에 의존하지 않습니다.

## 요구 사항

- Swift 6.0 이상
- iOS 15 이상 또는 macOS 13 이상

## 설치

Xcode의 Add Package Dependencies에서 이 저장소를 추가하고 `AsyncPermissions` product를 선택합니다.
최초 릴리즈 태그가 등록되기 전에는 적용한 커밋 revision을 지정할 수 있습니다.

## 사용

```swift
import AsyncPermissions

@MainActor
final class CameraAccess {
  private let permissionClient: any PermissionRequesting

  init(permissionClient: any PermissionRequesting) {
    self.permissionClient = permissionClient
  }

  func requestCameraAccess() async throws(PermissionError) -> PermissionStatus {
    try await permissionClient.request(.camera)
  }
}

// 앱의 조립 지점에서 구현을 생성하고 필요한 객체에 주입합니다.
// let cameraAccess = CameraAccess(permissionClient: PermissionClient())
```

권한 거부는 오류가 아니라 `.denied` 등의 상태로 반환합니다.
Task 취소는 `PermissionError.cancelled`로 구분하므로 호출부는 `try await`를 사용합니다.

## 지원 범위

| 요청 | OS 접근 범위 |
| --- | --- |
| `.camera` | 카메라 비디오 캡처 |
| `.photosReadWrite` | 사진 라이브러리 읽기·쓰기 |
| `.photosAddOnly` | 사진 라이브러리 추가 전용 |

`PermissionStatus`는 `notDetermined`, `authorized`, `limited`, `denied`, `restricted`, `unknown`을 구분합니다.
`isGranted`는 `authorized` 또는 `limited`에서 true이며, limited는 전체 사진 접근을 뜻하지 않습니다.
미지원 OS 상태는 unknown으로 반환하며 허용으로 처리하지 않습니다.

## 동작 계약

- MainActor에서 사용합니다. 상태는 OS에서 매번 조회하며 자체 저장·캐시하지 않습니다.
- 미결정 상태에서만 시스템 권한을 요청합니다. 같은 권한의 진행 중 요청은 공유합니다.
- 이미 거부·제한된 권한에는 시스템 팝업을 다시 요청하지 않습니다.
- 안내 UI, 설정 앱 이동, 복귀 후 재조회 및 화면 생명주기는 호출자가 관리합니다.
- OS 권한 팝업 자체는 취소할 수 없습니다. 취소된 호출자는 OS 응답 완료 후 cancelled 오류를 받으며, 다른 호출자의 공유 요청은 취소하지 않습니다.
- 카메라 요청에는 `NSCameraUsageDescription`, 사진 읽기·쓰기에는 `NSPhotoLibraryUsageDescription`, 사진 추가 전용에는 `NSPhotoLibraryAddUsageDescription`을 앱 Info.plist에 설정해야 합니다.
- macOS 앱은 사용하는 기능의 sandbox entitlement와 사용 사유를 별도로 구성해야 합니다.

## 소스 구조

- `Sources/AsyncPermissions/Public`: 공개 타입·프로토콜과 얇은 PermissionClient API
- `Sources/AsyncPermissions/Private`: internal 권한 드라이버·요청 조정 구현
- 공개 타입의 캡슐화에 필요한 private 저장 프로퍼티는 해당 타입에 유지하며, 요청 공유·취소 등의 구현은 Private에 둡니다.
- 폴더명 자체가 Swift 접근 제한을 설정하는 것은 아니므로 선언의 접근 수준도 함께 유지합니다.

## 테스트

```sh
swift test
```

Swift Testing과 주입된 대역으로 상태 매핑, 요청 범위, 설정 변경 반영, 중복 요청 공유 및 취소를 검증합니다.
테스트는 실제 사용자 권한을 변경하지 않습니다. 실제 시스템 팝업과 앱 설정 왕복은 기기에서 별도 확인해야 합니다.
