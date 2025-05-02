//
//  URLSessionMock.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import XCTest
@testable import ExtWSClient

final class URLSessionMock: URLSessionProtocol {

    // MARK: - Tracked Properties

    private(set) var task: WebSocketTaskProtocol                       // Задача
    private(set) var createdWebSocketTasks = [WebSocketTaskProtocol]() // Массив созданных WebSocket задач

    // MARK: - Lifecycle

    init(task: WebSocketTaskProtocol) {
        self.task = task
    }

    // MARK: - URLSessionProtocol Implementation

    func webSocketTask(with request: URLRequest) -> WebSocketTaskProtocol {
        createdWebSocketTasks.append(task)
        return task
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return (Data(), URLResponse())
    }
}