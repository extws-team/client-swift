//
//  URLSessionWebSocketTaskMock.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import XCTest
@testable import ExtWSClient

final class URLSessionWebSocketTaskMock: WebSocketTaskProtocol, @unchecked Sendable {

    private(set) var resumeCalled = false
    private(set) var cancelCalled = false
    private(set) var pingCalled = false
    private(set) var receiveCompletion: ((Result<URLSessionWebSocketTask.Message, Error>) -> Void)?
    private(set) var pingCompletion: ((Error?) -> Void)?
    private(set) var resumeCalledCount: Int = .zero
    private(set) var cancelCalledCount: Int = .zero
    private(set) var sentMessages = [URLSessionWebSocketTask.Message]()
    private(set) var sendCompletions = [(Error?) -> Void]()

    func resume() {
        resumeCalledCount += 1
        resumeCalled = true
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        cancelCalled = true
    }

    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void) {
        sentMessages.append(message)
        sendCompletions.append(completionHandler)
        let error = NSError(domain: "test", code: .zero)
        completionHandler(error)
    }

    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        receiveCompletion = completionHandler
    }

    func sendPing(pongReceiveHandler: @escaping (Error?) -> Void) {
        pingCalled = true
        pingCompletion = pongReceiveHandler
    }
}
