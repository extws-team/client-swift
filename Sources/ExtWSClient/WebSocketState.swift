//
//  WebSocketState.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import Foundation

/// Потокобезопасный актор для управления состоянием WebSocket соединения
actor WebSocketState {
    /// Флаг текущего состояния подключения
    var isConnected = false
    /// Очередь сообщений для отправки
    var sendQueue: [Data] = []
    /// Количество попыток переподключения
    var reconnectAttempts: Int = .zero

    /// Обновляет состояние подключения
    /// - Parameter connected: Новое состояние подключения
    func updateConnectionStatus(_ connected: Bool) {
        isConnected = connected
    }

    /// Добавляет данные в очередь отправки
    /// - Parameter data: Данные для добавления в очередь
    func addToQueue(_ data: Data) {
        sendQueue.append(data)
    }

    /// Очищает очередь и возвращает все данные
    /// - Returns: Массив данных из очереди
    func flushQueue() -> [Data] {
        let queue = sendQueue
        sendQueue.removeAll()
        return queue
    }

    /// Увеличивает счетчик попыток переподключения
    func incrementReconnectAttempts() {
        reconnectAttempts += 1
    }

    /// Сбрасывает счетчик попыток переподключения
    func resetReconnectAttempts() {
        reconnectAttempts = .zero
    }
}
