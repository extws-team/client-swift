//
//  WebSocketClientTests.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import XCTest
@testable import ExtWSClient

// MARK: - Test Payload Type

struct TestPayload: PayloadData {
    let value: String
}

final class WebSocketClientTests: XCTestCase {

    // MARK: - Constants
    private enum Constants {
        static let testURL = URL(string: "ws://test.com")!
        static let testEvent = "testEvent"
        static let queuedEvent = "queuedEvent"
        static let messageEvent = "message"
        static let disconnectEvent = "disconnect"
        static let connectEvent = "connect"
        static let valueOne: Int = 1
        static let valueTwo: Int = 2

        enum Values {
            static let testValue = "test"
            static let queuedValue = "queued"
            static let receivedValue = "received"
        }

        enum Time {
            static let asyncProcessingDelay: UInt64 = 100_000_000
            static let testTimeout: TimeInterval = 15.0
            static let timeoutInterval: TimeInterval = 1.0
        }

        enum Errors {
            static let domain = "test"
            static let code = 0
        }

        enum Messages {
            static let taskNotCreated = "WebSocket task not created"
            static let noMessageSent = "No message sent"
            static let decodingFailed = "Decoding failed: %@"
            static let tasksCountMismatch = "Должно быть 2 задачи"
            static let taskNotStarted = "Новая задача не запущена"
        }
    }

    // MARK: - Private properties

    private var client: WebSocketClient!
    private var mockSession: URLSessionMock!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        mockSession = URLSessionMock()
        client = WebSocketClient(url: Constants.testURL, session: mockSession)
    }

    override func tearDown() {
        client = nil
        mockSession = nil
        super.tearDown()
    }
}

// MARK: - Connection Tests

extension WebSocketClientTests {

    func testConnect() async {
        // arrange & act
        await client.connect()

        // assert
        let isConnected = await client.isConnected
        XCTAssertTrue(isConnected)

        guard let task = mockSession.webSocketTask else {
            XCTFail(Constants.Messages.taskNotCreated)
            return
        }

        XCTAssertTrue(task.resumeCalled)
    }

    func testDoubleConnect() async {
        // arrange
        await client.connect()

        // act
        await client.connect()

        // assert
        XCTAssertEqual(mockSession.webSocketTask?.resumeCalledCount, Constants.valueOne)
    }

    func testDisconnect() async {
        // arrange
        await client.connect()

        // act
        await client.disconnect()

        // assert
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
        XCTAssertTrue(mockSession.webSocketTask?.cancelCalled ?? false)
    }
}

// MARK: - Message Sending Tests

extension WebSocketClientTests {

    func testSendStructuredMessage() async throws {
        // arrange
        await client.connect()
        let payload = TestPayload(value: Constants.Values.testValue)

        // act
        client.send(type: .message, event: Constants.testEvent, data: payload)

        // Wait for async processing
        try await Task.sleep(nanoseconds: Constants.Time.asyncProcessingDelay)

        // assert
        guard let message = mockSession.webSocketTask?.sentMessages.first,
              case .data(let data) = message else {
            XCTFail(Constants.Messages.noMessageSent)
            return
        }

        let decoded: Payload<TestPayload> = try PayloadSerializer().parse(data)
        XCTAssertEqual(decoded.data?.value, Constants.Values.testValue)
        XCTAssertEqual(decoded.type, .message)
        XCTAssertEqual(decoded.event, Constants.testEvent)
    }

    func testSendWhenDisconnected() async {
        // arrange
        let payload = TestPayload(value: Constants.Values.testValue)

        // act
        client.send(type: .message, event: nil, data: payload)

        // Wait for async processing
        try? await Task.sleep(nanoseconds: Constants.Time.asyncProcessingDelay)

        // assert
        XCTAssertEqual(mockSession.webSocketTask?.sentMessages.count ?? .zero, .zero)
    }

    func testFlushQueueOnReconnect() async {
        // arrange
        let payload = TestPayload(value: Constants.Values.queuedValue)
        client.send(type: .message, event: Constants.queuedEvent, data: payload)

        // act
        await client.connect()

        // Wait for async processing
        try? await Task.sleep(nanoseconds: Constants.Time.asyncProcessingDelay)

        // assert
        XCTAssertEqual(mockSession.webSocketTask?.sentMessages.count ?? .zero, Constants.valueOne)
    }
}

// MARK: - Reconnection Tests

extension WebSocketClientTests {

    func testReconnectOnSendFailure() async {
        // arrange
        let mockSession = URLSessionMock()
        let client = WebSocketClient(url: Constants.testURL, session: mockSession)
        let disconnectExpectation = XCTestExpectation(description: Constants.disconnectEvent)
        let reconnectExpectation = XCTestExpectation(description: Constants.connectEvent)

        client.on(Constants.disconnectEvent) { _ in
            disconnectExpectation.fulfill()
        }

        client.on(Constants.connectEvent) { _ in
            if mockSession.createdTasks.count == 2 {
                reconnectExpectation.fulfill()
            }
        }

        // act
        await client.connect()
        client.send(type: .message, event: nil, data: TestPayload(value: Constants.Values.testValue))
        mockSession.createdTasks.first?.sendCompletions.first?(NSError(
                    domain: Constants.Errors.domain,
                    code: Constants.Errors.code
                ))

        // assert
        await fulfillment(
            of: [disconnectExpectation, reconnectExpectation],
            timeout: Constants.Time.testTimeout,
            enforceOrder: true
        )

        XCTAssertEqual(mockSession.createdTasks.count, Constants.valueTwo, Constants.Messages.tasksCountMismatch)
        XCTAssertEqual(mockSession.createdTasks.last?.resumeCalledCount, Constants.valueOne, Constants.Messages.taskNotStarted)
    }
}

// MARK: - Message Handling Tests

extension WebSocketClientTests {

    func testMessageHandling() async throws {
        // arrange
        let expectation = expectation(description: Constants.messageEvent)
        let payload = TestPayload(value: Constants.Values.receivedValue)

        client.on(Constants.messageEvent) { data in
            do {
                let decoded: Payload<TestPayload> = try PayloadSerializer().parse(data)
                XCTAssertEqual(decoded.data?.value, Constants.Values.receivedValue)
                expectation.fulfill()
            } catch {
                XCTFail(String(format: Constants.Messages.decodingFailed, error.localizedDescription))
            }
        }

        // act
        await client.connect()
        let testData = try PayloadSerializer().build(
            type: .message,
            event: Constants.testEvent,
            data: payload
        )
        mockSession.webSocketTask?.receiveCompletion?(.success(.data(testData)))

        // assert
        await fulfillment(of: [expectation], timeout: Constants.Time.timeoutInterval)
    }
}
