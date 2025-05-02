//
//  URLSessionWebSocketTaskMock.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import XCTest
@testable import ExtWSClient


final class URLSessionWebSocketTaskMock: WebSocketTaskProtocol, @unchecked Sendable {

    private(set) var didResume = false
    private(set) var didSend = false
    private(set) var didCancel = false
    private(set) var didPing = false
    private(set) var resumeCalledCount: Int = .zero
    private(set) var sentMessages = [URLSessionWebSocketTask.Message]()
    private(set) var receiveCompletion: ((Result<URLSessionWebSocketTask.Message, Error>) -> Void)?
    var sendCallback: (() -> Void)?

    func resume() {
        didResume = true
        resumeCalledCount += 1
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        didCancel = true
    }

    func send(_ message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void) {
        print("[Mock] send called")
        didSend = true
        sentMessages.append(message)
        sendCallback?()
        completionHandler(nil)
    }

    func sendPing(pongReceiveHandler: @escaping (Error?) -> Void) {
        didPing = true
        pongReceiveHandler(nil)
    }

    func receive(completionHandler: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void) {
        receiveCompletion = completionHandler
    }
}