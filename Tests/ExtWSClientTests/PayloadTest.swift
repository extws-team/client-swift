//
//  PayLoadTest.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import XCTest
@testable import ExtWSClient

final class PayloadTests: XCTestCase {

    // MARK: - Constants

    private enum Constants {
        static let testEventName: String = "test_event"
        static let testName: String = "Test Name"
        static let errorType = -1
        static let timeoutType = 1
        static let pingType = 2
        static let pongType = 3
        static let messageType = 4
        static let invalidJSON: Data = "{\"invalid\":}".data(using: .utf8)!
        static let accuracy: TimeInterval = 1
        static let testId: Int = 123
        static let testStringId = "test_id"
        static let idleTimeout = 300
        static let testString = "4test_event{\"id\":123}"
        static let invalidString = "Xinvalid"
        static let testStringIdValue = "1"
    }

    // MARK: - Private properties

    private var serializer: PayloadSerializer!

    private struct TestData: PayloadData {
        let id: Int
        let name: String
    }

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        serializer = PayloadSerializer()
    }

    override func tearDown() {
        serializer = nil
        super.tearDown()
    }

    // MARK: - PayloadType Tests

    func testPayloadTypeRawValues() {
        // Act & Assert
        XCTAssertEqual(PayloadType.error.rawValue, Constants.errorType)
        XCTAssertEqual(PayloadType.timeout.rawValue, Constants.timeoutType)
        XCTAssertEqual(PayloadType.ping.rawValue, Constants.pingType)
        XCTAssertEqual(PayloadType.pong.rawValue, Constants.pongType)
        XCTAssertEqual(PayloadType.message.rawValue, Constants.messageType)
    }

    func testPayloadTypeCodable() throws {
        // Arrange
        let types: [PayloadType] = [.error, .timeout, .ping]
        let encoded = try JSONEncoder().encode(types)
        let decoded = try JSONDecoder().decode([PayloadType].self, from: encoded)

        // Act & Assert
        XCTAssertEqual(types, decoded)
    }

    // MARK: - Payload Struct Tests

    func testPayloadInitialization() {
        // Arrange & Act
        let testData = TestData(id: Constants.testId, name: Constants.testName)
        let payload = Payload(type: .message, event: Constants.testEventName, data: testData)

        // Assert
        XCTAssertEqual(payload.type, .message)
        XCTAssertEqual(payload.event, Constants.testEventName)
        XCTAssertEqual(payload.data?.id, Constants.testId)
        XCTAssertEqual(payload.data?.name, Constants.testName)
    }

    func testPayloadWithEmptyData() {
        // Arrange & Act
        let payload = Payload<EmptyPayload>(type: .message, event: nil, data: EmptyPayload())

        // Assert
        XCTAssertEqual(payload.type, .message)
        XCTAssertNil(payload.event)
        XCTAssertNotNil(payload.data)
    }

    // MARK: - PayloadSerializer Tests

    func testBuildWithData() throws {
        // Arrange & Act
        let testData = TestData(id: Constants.testId, name: Constants.testName)
        let data = try serializer.build(
            type: .message,
            event: Constants.testEventName,
            data: testData
        )

        // Assert
        XCTAssertFalse(data.isEmpty)
        let decoded = try JSONDecoder().decode(Payload<TestData>.self, from: data)
        XCTAssertEqual(decoded.type, .message)
        XCTAssertEqual(decoded.event, Constants.testEventName)
        XCTAssertEqual(decoded.data?.id, Constants.testId)
        XCTAssertEqual(decoded.data?.name, Constants.testName)
    }

    func testBuildWithOptionalData() throws {
        // Arrange & Act
        let data = try serializer.build(
            type: .message,
            event: nil,
            data: EmptyPayload()
        )

        // Assert
        XCTAssertFalse(data.isEmpty)
        let decoded = try JSONDecoder().decode(Payload<EmptyPayload>.self, from: data)
        XCTAssertEqual(decoded.type, .message)
        XCTAssertNil(decoded.event)
        XCTAssertNotNil(decoded.data)
    }

    func testParseValidPayload() throws {
        // Arrange
        let original = Payload(
            type: .message,
            event: Constants.testEventName,
            data: TestData(id: Constants.testId, name: Constants.testName)
        )

        // Act
        let encoded = try JSONEncoder().encode(original)
        let decoded = try serializer.parse(encoded) as Payload<TestData>

        // Assert
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.event, original.event)
        XCTAssertEqual(decoded.data?.id, original.data?.id)
        XCTAssertEqual(decoded.data?.name, original.data?.name)
    }

    func testParseEmptyPayload() throws {
        // Arrange
        let original = Payload<EmptyPayload>(type: .error, event: nil, data: EmptyPayload())

        // Act
        let encoded = try JSONEncoder().encode(original)
        let decoded = try serializer.parse(encoded) as Payload<EmptyPayload>

        // Assert
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertNil(decoded.event)
        XCTAssertNotNil(decoded.data)
    }

    func testParseInvalidDataThrowsError() {
        // Act & Assert
        XCTAssertThrowsError(try serializer.parse(Constants.invalidJSON) as Payload<TestData>) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testDateEncodingStrategy() throws {
        // Arrange
        struct DateData: PayloadData {
            let date: Date
        }

        let testDate = Date()
        let testData = DateData(date: testDate)
        let data = try serializer.build(type: .message, event: nil, data: testData)
        let decoded = try serializer.parse(data) as Payload<DateData>
        let decodedDate = try XCTUnwrap(decoded.data?.date)

        // Assert
        XCTAssertEqual(
            decodedDate.timeIntervalSince1970,
            testDate.timeIntervalSince1970,
            accuracy: Constants.accuracy
        )
    }

    // MARK: - Header Parsing Tests

    func testParseHeaderValid() throws {
        // Arrange
        let data = Constants.testString.data(using: .utf8)!
        let (type, event, jsonData) = try serializer.parseHeader(from: data)

        // Assert
        XCTAssertEqual(type, .message)
        XCTAssertEqual(event, Constants.testEventName)
        XCTAssertNotNil(jsonData)
    }

    func testParseHeaderWithoutData() throws {
        // Arrange
        let data = Constants.testStringIdValue.data(using: .utf8)!

        // Act
        let (type, event, jsonData) = try serializer.parseHeader(from: data)

        // Assert
        XCTAssertEqual(type, .timeout)
        XCTAssertNil(event)
        XCTAssertNil(jsonData)
    }

    func testParseHeaderInvalidType() {
        // Arrange
        let data = Constants.invalidString.data(using: .utf8)!

        // Assert
        XCTAssertThrowsError(try serializer.parseHeader(from: data)) { error in
            XCTAssertTrue(error is WebSocketError)
        }
    }

    func testDecodeInitData() throws {
        // Arrange
        let initData = InitData(id: Constants.testStringId, idle_timeout: Constants.idleTimeout)

        // Act
        let encoded = try JSONEncoder().encode(initData)
        let decoded = try serializer.decode(InitData.self, from: encoded)

        // Assert
        XCTAssertEqual(decoded.id, Constants.testStringId)
        XCTAssertEqual(decoded.idle_timeout, Constants.idleTimeout)
    }
}
