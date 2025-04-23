//
//  URLSessionMock.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import XCTest
@testable import ExtWSClient

final class URLSessionMock: URLSessionProtocol {
    private(set) var createdTasks = [URLSessionWebSocketTaskMock]()
    private(set) var webSocketTask: URLSessionWebSocketTaskMock?

    func webSocketTask(with url: URL) -> WebSocketTaskProtocol {
        let task = URLSessionWebSocketTaskMock()
        createdTasks.append(task)
        webSocketTask = task
        return task
    }
}
