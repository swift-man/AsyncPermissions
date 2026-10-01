# Changelog

사용자에게 영향을 주는 변경과 공개 계약 변경을 기록합니다.
VERSION.txt는 다음 배포 대상 버전을 나타내며 릴리즈 태그 생성 자체를 의미하지 않습니다.

## [Unreleased]

### Added

- AppPermissions 공통 모듈과 선택 가능한 권한별 SPM product 10개.
- 마이크, 위치, Bluetooth, 캘린더, 미리 알림, 연락처, 알림 및 ATT 권한 구현.
- 접근 범위 승격 정책과 시스템 오류를 보존하는 typed throws 계약.
- 선택적 구현 등록, 상태 매핑 및 요청 오류의 Swift Testing 검증.
- SOLID 설계와 독립 권한 패키지 개발을 위한 AGENTS.md.

### Changed

- 패키지·공통 product·import 이름을 AsyncPermissions에서 AppPermissions로 변경.
- PermissionClient는 기본 OS 구현을 생성하지 않고 providers로 구현을 주입받음.
- status(for:)를 비동기 OS 설정 조회를 지원하는 async API로 변경.
- 내부 구현과 공개 계약을 모듈별 Public/Private 폴더로 분리.

## 초기 구현 이력

- PR #1: 카메라·사진 권한의 async 조회·요청, 요청 공유와 호출자별 취소 분리.
- PR #1: 공개 Sendable 계약, 제한 허용 상태 및 시스템 상태 매핑 검증.
- 아직 릴리즈 태그가 없으므로 배포 완료된 버전으로 기록하지 않습니다.
