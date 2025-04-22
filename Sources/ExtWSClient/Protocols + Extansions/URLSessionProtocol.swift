//
//  URLSessionProtocol.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import Foundation

/// Протокол для абстракции сессии WebSocket
/// Определяет интерфейс для создания задач WebSocket, позволяя внедрять кастомные реализации
/// и моки для тестирования. Соответствует интерфейсу `URLSession` из Foundation.
public protocol URLSessionProtocol {

    /// Создает и возвращает задачу WebSocket для указанного URL
    /// - Parameter url: URL сервера WebSocket. Должен использовать схемы:
    ///   - `ws` для незащищенных соединений
    ///   - `wss` для TLS-соединений
    /// - Returns: Готовый к использованию объект WebSocket задачи
    /// - Important: Возвращенная задача находится в приостановленном состоянии.
    ///   Для старта соединения необходимо вызвать `resume()`.
    /// - Note: Реализации должны гарантировать:
    ///   - Корректную обработку URL согласно RFC 6455
    ///   - Потокобезопасность при создании задач
    /// ## Пример использования:
    /// ```swift
    /// let session: URLSessionProtocol = URLSession.shared
    /// let task = session.webSocketTask(with: URL(string: "wss://echo.websocket.org")!)
    /// task.resume()
    /// ```
    func webSocketTask(with url: URL) -> WebSocketTaskProtocol
}
