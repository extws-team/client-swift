//
//  WebSocketTaskProtocol.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import Foundation

/// Протокол для абстракции WebSocket задачи
/// Определяет базовые операции для управления WebSocket соединением
public protocol WebSocketTaskProtocol: Sendable {

    /// Запускает или возобновляет задачу WebSocket соединения
    /// - Important: Должен быть вызван для установки соединения после инициализации
    func resume()

    /// Отменяет задачу WebSocket соединения
    /// - Parameters:
    ///   - closeCode: Код закрытия соединения (RFC 6455 Section 7.4)
    ///   - reason: Дополнительные данные, описывающие причину закрытия (макс 125 байт)
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)

    /// Отправляет сообщение через WebSocket соединение
    /// - Parameters:
    ///   - message: Сообщение для отправки (текст или бинарные данные)
    ///   - completionHandler: Обработчик завершения с возможной ошибкой
    /// - Note: Сообщения ставятся в очередь и отправляются асинхронно
    func send(_ message: URLSessionWebSocketTask.Message,
             completionHandler: @Sendable @escaping (Error?) -> Void)

    /// Начинает асинхронное ожидание входящего сообщения
    /// - Parameter completionHandler: Обработчик результата:
    ///   - Успех: полученное сообщение (текст/данные)
    ///   - Неудача: ошибка получения
    /// - Important: Должен вызываться рекурсивно для непрерывного чтения сообщений
    func receive(completionHandler: @Sendable @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void)

    /// Отправляет ping-сообщение и ожидает pong-ответ
    /// - Parameter pongReceiveHandler: Обработчик получения ответа:
    ///   - `nil`: pong получен успешно
    ///   - Ошибка: проблемы с соединением или таймаут
    /// - Important: Используется для поддержания активности соединения
    func sendPing(pongReceiveHandler: @Sendable @escaping (Error?) -> Void)
}
