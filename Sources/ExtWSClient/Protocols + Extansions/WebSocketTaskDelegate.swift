//
//  WebSocketTaskDelegate.swift
//  m1
//
//  Created by d.kotina on 30.04.2025.
//

import Foundation

/// Делегат для обработки задач URLSession, связанных с WebSocket соединением.
/// Отслеживает и сохраняет HTTP-ответы для WebSocket задач.
final class WebSocketTaskDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {

    // MARK: - Properties

    /// Словарь для хранения соответствий задач и их HTTP-ответов.
    /// - Key: URLSessionTask (WebSocket задача)
    /// - Value: Соответствующий HTTPURLResponse
    private var taskResponseMap = [URLSessionTask: HTTPURLResponse]()

    // MARK: - URLSessionTaskDelegate

    /// Обрабатывает получение HTTP-ответа перед апгрейдом на WebSocket.
    /// Сохраняет ответ сразу при получении.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {

        if let httpResponse = response as? HTTPURLResponse {
            taskResponseMap[task] = httpResponse
        } else {
            Logger().log("[Delegate] ⚠️ Response is not HTTPURLResponse", error: true)
        }

        completionHandler(.allow)
    }


    /// Обрабатывает завершение задачи URLSession
    /// (используется на случай, если соединение завершилось до получения ответа)
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        taskResponseMap.removeValue(forKey: task)
    }

    // MARK: - Public Methods

    /// Получает HTTP-ответ для конкретной задачи WebSocket.
    /// - Parameter task: Задача URLSessionWebSocketTask
    /// - Returns: Сохраненный HTTPURLResponse или nil, если ответ не был получен
    func getResponse(for task: URLSessionTask) -> HTTPURLResponse? {
        let response = taskResponseMap[task]
        return response
    }
}
