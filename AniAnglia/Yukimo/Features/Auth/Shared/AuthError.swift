//
//  AuthError.swift
//  Friendly Russian messages mapped from YukimoAuthErrorCode.
//

import Foundation

struct AuthErrorMessage {
    static func from(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == YukimoAuthErrorDomain else {
            return ns.localizedDescription.isEmpty
                ? "Что-то пошло не так. Попробуйте ещё раз."
                : ns.localizedDescription
        }
        switch YukimoAuthErrorCode(rawValue: ns.code) ?? .unknown {
        case .network:            return "Нет связи с сервером. Проверьте интернет."
        case .invalidLogin:       return "Неверный логин или email."
        case .invalidPassword:    return "Неверный пароль."
        case .invalidEmail:       return "Некорректный email."
        case .loginAlreadyTaken:  return "Этот логин уже занят."
        case .emailAlreadyTaken:  return "Этот email уже зарегистрирован."
        case .accountBanned:      return "Аккаунт временно заблокирован."
        case .accountPermBanned:  return "Аккаунт заблокирован навсегда."
        case .unauthorized:       return "Сессия истекла. Войдите снова."
        case .invalidCode:        return "Неверный код подтверждения."
        case .codeExpired:        return "Срок действия кода истёк."
        case .tooManyAttempts:    return "Слишком много попыток. Попробуйте позже."
        case .serverFailure:      return "Сервер вернул ошибку. Попробуйте ещё раз."
        case .unknown:            fallthrough
        @unknown default:         return ns.localizedDescription.isEmpty
                                    ? "Что-то пошло не так."
                                    : ns.localizedDescription
        }
    }
}
