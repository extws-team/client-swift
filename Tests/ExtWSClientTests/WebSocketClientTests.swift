//
//  WebSocketClientTests.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import XCTest
@testable import ExtWSClient

final class WebSocketClientTests: XCTestCase {

    // MARK: - Test Constants

    private enum Constants {
        static let testURLString = "wss://example.com"
        static let connectEvent = "connect"
        static let disconnectEvent = "disconnect"
        static let messageEvent = "message"
        static let testEventName = "testEvent"
        static let queuedEventName = "queuedEvent"
        static let testPayloadValue = "test"
        static let queuedPayloadValue = "queued"
        static let receivedPayloadValue = "received"
        static let stringPayloadValue = "str"
        static let eventPayloadValue = "event"
        static let authorizationHeader = "Authorization"
        static let bearerToken = "Bearer token"
        static let statusExpectationTrue = "Connection status changed to true"
        static let connectEventExpectation = "Connect event emitted"
        static let dataMessage = "Expected .data message"
        static let messageSentAfterReconnect = "Message was sent after reconnect"
        static let disconnectEventExpectation = "disconnect event emitted"
        static let handledStringMessageExpectation = "Handled string message"
        static let decodingFailedExpectation = "Decoding failed"
        static let standardTimeout: TimeInterval = 1.0
        static let extendedTimeout: TimeInterval = 2.0
        static let valueOne = 1
        static let nanoSecondMultiplier: UInt64 = 500_000_000
    }

    // MARK: - Private properties

    private struct TestPayload: PayloadData {
        let value: String
    }

    private var client: WebSocketClient!
    private var mockTask: URLSessionWebSocketTaskMock!
    private var sessionMock: URLSessionMock!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        mockTask = URLSessionWebSocketTaskMock()
        sessionMock = URLSessionMock(task: mockTask)
        client = WebSocketClient(
            url: URL(string: Constants.testURLString)!,
            session: sessionMock
        )
    }

    override func tearDown() {
        client = nil
        mockTask = nil
        sessionMock = nil
        super.tearDown()
    }

    // MARK: - Tests

    func testConnectInvokesResumeAndEmitsEvents() async throws {
        // Arrange
        let statusExpectation = expectation(description: Constants.statusExpectationTrue)
        statusExpectation.assertForOverFulfill = false
        client.onConnectionStatusChanged = { isConnected in
            if isConnected {
                statusExpectation.fulfill()
            }
        }

        // Act
        let connectEventExpectation = expectation(description: Constants.connectEventExpectation)
        client.on(Constants.connectEvent) { _ in
            connectEventExpectation.fulfill()
        }

        await client.connect()

        // Assert
        await fulfillment(
            of: [statusExpectation, connectEventExpectation],
            timeout: Constants.standardTimeout
        )
        XCTAssertTrue(mockTask.didResume)
    }

    func testDoubleConnect() async {
        // Arrange
        await client.connect()

        // Act
        await client.connect()

        // Assert
        XCTAssertEqual(mockTask.resumeCalledCount, Constants.valueOne)
    }

    func testDisconnect() async {
        // Arrange
        await client.connect()

        // Act
        await client.disconnect()

        // Assert
        let isConnected = await client.isConnected
        XCTAssertFalse(isConnected)
        XCTAssertTrue(mockTask.didCancel)
    }

    func testSendStructuredMessage() async throws {
        // Arrange
        await client.connect()
        let payload = TestPayload(value: Constants.testPayloadValue)

        // Act
        client.send(
            type: .message,
            event: Constants.testEventName,
            data: payload
        )
        try await Task.sleep(nanoseconds: Constants.nanoSecondMultiplier)

        // Assert
        XCTAssertEqual(mockTask.sentMessages.count, Constants.valueOne)

        switch mockTask.sentMessages.first! {
        case .data(let data):
            let decoded: Payload<TestPayload> = try PayloadSerializer().parse(data)
            XCTAssertEqual(decoded.data?.value, Constants.testPayloadValue)
            XCTAssertEqual(decoded.type, .message)
            XCTAssertEqual(decoded.event, Constants.testEventName)
        default:
            XCTFail(Constants.dataMessage)
        }
    }

    func testSendWhenDisconnected() async {
        // Arrange
        let payload = TestPayload(value: Constants.testPayloadValue)

        // Act
        client.send(type: .message, event: nil, data: payload)
        try? await Task.sleep(nanoseconds: Constants.nanoSecondMultiplier / 5)

        // Assert
        XCTAssertEqual(mockTask?.sentMessages.count ?? .zero, .zero)
    }

    func testFlushQueueOnReconnect() async {
        // Arrange
        let payload = TestPayload(value: Constants.queuedPayloadValue)
        client.send(
            type: .message,
            event: Constants.queuedEventName,
            data: payload
        )

        let expectation = expectation(description: Constants.messageSentAfterReconnect)
        mockTask.sendCallback = {
            expectation.fulfill()
        }

        // Act
        await client.connect()

        // Assert
        await fulfillment(of: [expectation], timeout: Constants.extendedTimeout)
        XCTAssertEqual(mockTask.sentMessages.count, Constants.valueOne)
    }

    func testMessageHandling() async throws {
        // Arrange
        let expectation = expectation(description: Constants.messageEvent)
        let testValue = Constants.receivedPayloadValue
        let serializer = PayloadSerializer()

        client.on(Constants.messageEvent) { data in
            do {
                let (type, event, payloadData) = try serializer.parseHeader(from: data)
                let decodedPayload = try serializer.decode(TestPayload.self, from: payloadData)

                XCTAssertEqual(type, .message)
                XCTAssertEqual(event, Constants.testEventName)
                XCTAssertEqual(decodedPayload.value, testValue)
                expectation.fulfill()
            } catch {
                XCTFail("Decoding failed: \(error)")
            }
        }

        // Act
        await client.connect()

        let manualPayload = """
        4\(Constants.testEventName){"value":"\(testValue)"}
        """
        let payloadData = manualPayload.data(using: .utf8)!

        mockTask.receiveCompletion?(.success(.data(payloadData)))

        // Assert
        await fulfillment(of: [expectation], timeout: 2)
    }

    func testDisconnectEmitsEvent() async {
        // Arrange
        let expectation = expectation(description: Constants.disconnectEventExpectation)

        client.on(Constants.disconnectEvent) { _ in
            expectation.fulfill()
        }

        await client.connect()

        // Act
        await client.disconnect()

        // Assert
        await fulfillment(of: [expectation], timeout: Constants.standardTimeout)
    }

    func testBeforeConnectModifiesRequest() async {
        // Arrange
        var wasCalled = false

        // Act
        client.beforeConnect = { request in
            wasCalled = true
            var r = request
            r.setValue(
                Constants.bearerToken,
                forHTTPHeaderField: Constants.authorizationHeader
            )
            return r
        }

        // Assert
        await client.connect()
        XCTAssertTrue(wasCalled)
    }
    // MARK: - Connection Tests

    func testReconnectOnSendFailure() async {
        // Arrange
        let payload = TestPayload(value: "test")
        let connectionExpectation = expectation(description: "Reconnected")
        var connectCount = 0

        client.onConnectionStatusChanged = { isConnected in
            if isConnected {
                connectCount += 1
                if connectCount == 2 {
                    connectionExpectation.fulfill()
                }
            }
        }

        // Act
        await client.connect()
        client.send(type: .message, event: "test", data: payload)

        // Simulate connection failure
        mockTask.receiveCompletion?(.failure(URLError(.networkConnectionLost)))

        // Assert
        await fulfillment(of: [connectionExpectation], timeout: 3)
        XCTAssertEqual(connectCount, 2)
    }
}
