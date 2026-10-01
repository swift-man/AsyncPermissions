//
//  PermissionError+System.swift
//  AppPermissions
//
//  Created by Gorani on 2026/10/02.
//  Copyright © 2026 Gorani. All rights reserved.
//

import Foundation

public extension PermissionError {
  /// 구현 모듈의 시스템 오류를 공통 오류 계약으로 변환합니다.
  static func systemError(_ error: any Error) -> PermissionError {
    if let permissionError = error as? PermissionError { return permissionError }
    if error is CancellationError { return .cancelled }
    let systemError = error as NSError
    return .systemFailure(domain: systemError.domain, code: systemError.code)
  }
}
