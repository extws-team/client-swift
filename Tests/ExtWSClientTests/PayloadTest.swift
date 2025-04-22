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
        static let event: String = "event"
        static let message: String = "message"
        static let error: String = "error"
        static let XCTFail: String = "Decoded date should not be nil"
        static let invalidJSON: Data = "{\"invalid\":}".data(using: .utf8)!
        static let accuracy: TimeInterval = 1
        static let testId: Int = 123
    }

    // MARK: - Private properties

    private var serializer: PayloadSerializer!
    private struct EmptyData: PayloadData {}

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
        // assert

        XCTAssertEqual(PayloadType.event.rawValue, Constants.event)
        XCTAssertEqual(PayloadType.message.rawValue, Constants.message)
        XCTAssertEqual(PayloadType.error.rawValue, Constants.error)
    }

    func testPayloadTypeCodable() throws {
        // arrange & act
        let types: [PayloadType] = [.event, .message, .error]
        let encoded = try JSONEncoder().encode(types)
        let decoded = try JSONDecoder().decode([PayloadType].self, from: encoded)

        // assert
        XCTAssertEqual(types, decoded)
    }

    // MARK: - Payload Struct Tests

    func testPayloadInitialization() {
        // arrange & act
        let testData = TestData(id: Constants.testId, name: Constants.testName)
        let payload = Payload(type: .event, event: Constants.testEventName, data: testData)

        // assert
        XCTAssertEqual(payload.type, .event)
        XCTAssertEqual(payload.event, Constants.testEventName)
        XCTAssertEqual(payload.data?.id, Constants.testId)
        XCTAssertEqual(payload.data?.name, Constants.testName)
    }

    func testPayloadWithNilData() {
        // arrange & act
        let payload = Payload<TestData>(type: .message, event: nil, data: nil)

        // assert
        XCTAssertEqual(payload.type, .message)
        XCTAssertNil(payload.event)
        XCTAssertNil(payload.data)
    }

    // MARK: - PayloadSerializer Tests

    func testBuildWithData() throws {
        // arrange & act
        let testData = TestData(id: Constants.testId, name: Constants.testName)
        let data = try serializer.build(
            type: .event,
            event: Constants.testEventName,
            data: testData
        )

        // assert
        XCTAssertFalse(data.isEmpty)

        let decoded = try JSONDecoder().decode(Payload<TestData>.self, from: data)
        XCTAssertEqual(decoded.type, .event)
        XCTAssertEqual(decoded.event, Constants.testEventName)
        XCTAssertEqual(decoded.data?.id, Constants.testId)
        XCTAssertEqual(decoded.data?.name, Constants.testName)
    }

    func testBuildWithNilData() throws {
        // arrange & act
        let data = try serializer.build(
            type: .message,
            event: nil,
            data: nil as TestData?
        )

        // assert
        XCTAssertFalse(data.isEmpty)

        let decoded = try JSONDecoder().decode(Payload<TestData>.self, from: data)
        XCTAssertEqual(decoded.type, .message)
        XCTAssertNil(decoded.event)
        XCTAssertNil(decoded.data)
    }

    func testParseValidPayload() throws {
        // arrange & act
        let original = Payload(
            type: .event,
            event: Constants.testEventName,
            data: TestData(id: Constants.testId, name: Constants.testName)
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try serializer.parse(encoded) as Payload<TestData>

        // assert
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.event, original.event)
        XCTAssertEqual(decoded.data?.id, original.data?.id)
        XCTAssertEqual(decoded.data?.name, original.data?.name)
    }

    func testParseEmptyPayload() throws {
        // arrange & act
        let original = Payload<EmptyData>(type: .error, event: nil, data: nil)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try serializer.parse(encoded) as Payload<EmptyData>

        // assert
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertNil(decoded.event)
        XCTAssertNil(decoded.data)
    }

    func testParseInvalidDataThrowsError() {
        // assert
        XCTAssertThrowsError(try serializer.parse(Constants.invalidJSON) as Payload<TestData>) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testDateEncodingStrategy() throws {
        // arrange & act
        struct DateData: PayloadData {
            let date: Date
        }

        let testDate = Date()
        let testData = DateData(date: testDate)
        let data = try serializer.build(type: .message, event: nil, data: testData)
        let decoded = try serializer.parse(data) as Payload<DateData>

        // assert
        XCTAssertNotNil(decoded.data)

        if let decodedDate = decoded.data?.date {
            XCTAssertEqual(decodedDate.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: Constants.accuracy)
        } else {
            XCTFail(Constants.XCTFail)
        }
    }
}
