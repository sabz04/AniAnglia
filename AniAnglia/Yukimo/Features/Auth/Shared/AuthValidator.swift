//
//  AuthValidator.swift
//  Swift port of the legacy AuthChecker rules. Performs purely
//  client-side validation; server-side checks always win.
//

import Foundation

enum AuthFieldStatus: Equatable {
    case ok
    case tooShort
    case tooLong
    case invalid

    var message: String? {
        switch self {
        case .ok: return nil
        case .tooShort: return "Слишком коротко"
        case .tooLong: return "Слишком длинно"
        case .invalid: return "Неверный формат"
        }
    }
}

enum AuthValidator {

    static func checkUsername(_ value: String) -> AuthFieldStatus {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 { return .tooShort }
        if trimmed.count > 32 { return .tooLong }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-."))
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) { return .invalid }
        return .ok
    }

    static func checkEmail(_ value: String) -> AuthFieldStatus {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .tooShort }
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        guard trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            return .invalid
        }
        return .ok
    }

    static func checkPassword(_ value: String) -> AuthFieldStatus {
        if value.count < 6 { return .tooShort }
        if value.count > 64 { return .tooLong }
        return .ok
    }

    static func checkLoginOrEmail(_ value: String) -> AuthFieldStatus {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .tooShort }
        // Accept either a username or an email.
        if trimmed.contains("@") {
            return checkEmail(trimmed)
        }
        return checkUsername(trimmed)
    }
}
