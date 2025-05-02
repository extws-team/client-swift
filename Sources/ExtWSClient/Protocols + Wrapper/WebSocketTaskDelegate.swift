//
//  WebSocketTaskDelegate.swift
//  m1
//
//  Created by d.kotina on 30.04.2025.
//

import Foundation

/// Делегат для обработки задач URLSession, связанных с WebSocket соединением
/// Отслеживает и сохраняет HTTP-ответы для WebSocket задач
final class WebSocketTaskDelegate: NSObject, URLSessionTaskDelegate {

    // MARK: - Properties

    /// Словарь для хранения соответствий задач и их HTTP-ответов
    /// - Key: URLSessionTask (WebSocket задача)
    /// - Value: Соответствующий HTTPURLResponse
    private var taskResponseMap = [URLSessionTask: HTTPURLResponse]()

    // MARK: - URLSessionTaskDelegate

    /// Обрабатывает завершение задачи URLSession
    /// - Parameters:
    ///   - session: URLSession, к которой принадлежит задача
    ///   - task: Завершенная задача
    ///   - error: Ошибка выполнения задачи (если есть)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let response = task.response as? HTTPURLResponse {
            taskResponseMap[task] = response
        }
    }

    // MARK: - Public Methods

    /// Получает HTTP-ответ для конкретной задачи WebSocket
    /// - Parameter task: Задача URLSessionWebSocketTask
    /// - Returns: Сохраненный HTTPURLResponse или nil, если ответ не был получен
    func getResponse(for task: URLSessionTask) -> HTTPURLResponse? {
        return taskResponseMap[task]
    }
}
