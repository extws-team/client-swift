//
//  SessionWrapper.swift
//  m1
//
//  Created by d.kotina on 29.04.2025.
//

import Foundation

/// Обертка над URLSession для работы с WebSocket и обычными HTTP-запросами
/// Предоставляет унифицированный интерфейс и поддерживает dependency injection
final class SessionWrapper: URLSessionProtocol {

    // MARK: - Private Properties

    private let session: URLSession      // Базовая URLSession, используемая для выполнения запросов

    // MARK: - Lifecycle

    init(
        configuration: URLSessionConfiguration = .default,
        delegate: URLSessionDelegate? = nil,
        delegateQueue: OperationQueue? = nil
    ) {
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: delegateQueue)
    }

    // MARK: - WebSocket

    /// Создает задачу WebSocket
    /// - Parameter request: URLRequest для подключения WebSocket
    /// - Returns: Объект, реализующий WebSocketTaskProtocol
    func webSocketTask(with request: URLRequest) -> WebSocketTaskProtocol {
        return session.webSocketTask(with: request)
    }

    // MARK: - HTTP Requests

    /// Выполняет стандартный HTTP-запрос
    /// - Parameter request: URLRequest для выполнения
    /// - Returns: Кортеж с данными ответа и объектом URLResponse
    /// - Throws: Ошибки сети или обработки запроса
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}
