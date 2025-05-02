//
//  Extensions.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import Foundation

// MARK: - Расширение для соответствия URLSessionWebSocketTask протоколу WebSocketTaskProtocol

/// Расширение добавляет соответствие стандартного класса URLSessionWebSocketTask
/// кастомному протоколу WebSocketTaskProtocol для абстракции от системных реализаций
extension URLSessionWebSocketTask: WebSocketTaskProtocol {
    // Все методы протокола уже реализованы в URLSessionWebSocketTask
    // Явная реализация не требуется благодаря совпадению сигнатур методов
}

// MARK: - Расширение URLSession для поддержки протокола URLSessionProtocol

/// Расширение добавляет поддержку кастомного протокола URLSessionProtocol
/// к стандартному классу URLSession
extension URLSession: URLSessionProtocol {

    /// Создает и возвращает WebSocket задачу для указанного URL
    /// - Parameter url: URL endpoint WebSocket сервера
    /// - Returns: Объект задачи, соответствующий протоколу WebSocketTaskProtocol
    /// - Note: Явное приведение типа нужно для совместимости с протоколом
    public func webSocketTask(with url: URL) -> WebSocketTaskProtocol {
        return self.webSocketTask(with: url) as URLSessionWebSocketTask
    }
}
