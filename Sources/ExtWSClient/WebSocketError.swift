//
//  WebSocketError.swift
//  m1
//
//  Created by d.kotina on 02.05.2025.
//

import Foundation

/// Ошибки WebSocket клиента
enum WebSocketError: Error {
    case connectionClosed        // Соединение закрыто
    case encodingFailed(Error)   // Ошибка кодирования данных
    case sendFailed(Error)       // Ошибка отправки данных

    /// Локализованное описание ошибки
    var localizedDescription: String {
        switch self {
            case .connectionClosed:
                return "[WebSocketClient] ❌ Ошибка отправки: нет активных соединений"
            case .encodingFailed(let error):
                return "[WebSocketClient] ❌ Ошибка кодирования: \(error.localizedDescription)"
            case .sendFailed(let error):
                return "[WebSocketClient] ❌ Ошибка отправки: \(error.localizedDescription)"
        }
    }
}
