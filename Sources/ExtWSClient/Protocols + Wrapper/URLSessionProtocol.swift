//
//  URLSessionProtocol.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import Foundation

/// Протокол для абстракции сессии WebSocket
/// Определяет интерфейс для создания задач WebSocket, позволяя внедрять кастомные реализации и моки для тестирования. Соответствует интерфейсу `URLSession` из Foundation.
public protocol URLSessionProtocol {

    /// Создает задачу WebSocket
    /// - Parameter request: URLRequest для подключения WebSocket
    /// - Returns: Объект, реализующий WebSocketTaskProtocol
    func webSocketTask(with request: URLRequest) -> WebSocketTaskProtocol

    /// Выполняет стандартный HTTP-запрос
    /// - Parameter request: URLRequest для выполнения
    /// - Returns: Кортеж с данными ответа и объектом URLResponse
    /// - Throws: Ошибки сети или обработки запроса
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - Расширение для соответствия URLSessionWebSocketTask протоколу WebSocketTaskProtocol

/// Расширение добавляет соответствие стандартного класса URLSessionWebSocketTask кастомному протоколу WebSocketTaskProtocol для абстракции от системных реализаций
extension URLSessionWebSocketTask: WebSocketTaskProtocol {}


