//
//  EventEmitterTests.swift
//  ExtWSClient
//
//  Created by d.kotina on 22.04.2025.
//

import XCTest
@testable import ExtWSClient

final class EventEmitterTests: XCTestCase {

    // MARK: - Constants

    private enum Constants {
        static let testEventData = Data([0x01, 0x02, 0x03])
        static let multiEventData = Data([0xFF])
        static let emptyData = Data()

        static let callbackWaitTimeout: TimeInterval = 1.0
        static let invertedCallbackWaitTimeout: TimeInterval = 0.5
        static let concurrentOperationsCount: Int = 100

        static let testEventName: String = "testEvent"
        static let multiEventName: String = "multiEvent"
        static let testOffEventName: String = "testOff"
        static let threadSafeEventName: String = "threadSafeEvent"

        static let callbackCalled: String = "Callback should be called"
        static let firstCallback: String = "First callback"
        static let secondCallback: String = "Second callback"
        static let callbackNotCalled: String = "Callback should not be called"
        static let callbackAddedSafely: String = "All callbacks should be added safely"
        static let concurrentTestQueue: String = "test.concurrent.queue"
    }

    // MARK: - Private properties

    private var eventEmitter: EventEmitter!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        eventEmitter = EventEmitter()
    }

    override func tearDown() {
        eventEmitter = nil
        super.tearDown()
    }

    // MARK: - Тест подписки и вызова события

    func testEmitCallsRegisteredCallback() {
        // arrange
        let expectation = XCTestExpectation(description: Constants.callbackCalled)
        let testData = Constants.testEventData

        // act
        eventEmitter.on(Constants.testEventName) { data in
            XCTAssertEqual(data, testData)
            expectation.fulfill()
        }

        eventEmitter.emit(Constants.testEventName, data: testData)

        // assert
        wait(for: [expectation], timeout: Constants.callbackWaitTimeout)
    }

    // MARK: - Тест множественных подписчиков

    func testMultipleCallbacksAreCalled() {
        // arrange
        let expectation1 = XCTestExpectation(description: Constants.firstCallback)
        let expectation2 = XCTestExpectation(description: Constants.secondCallback)
        let testData = Constants.multiEventData

        // act
        eventEmitter.on(Constants.multiEventName) { _ in expectation1.fulfill() }
        eventEmitter.on(Constants.multiEventName) { _ in expectation2.fulfill() }
        eventEmitter.emit(Constants.multiEventName, data: testData)

        // assert
        wait(for: [expectation1, expectation2], timeout: Constants.callbackWaitTimeout)
    }

    // MARK: - Тест отписки (`off`)

    func testOffRemovesAllCallbacks() {
        // arrange
        let callbackCalled = XCTestExpectation(description: Constants.callbackNotCalled)
        callbackCalled.isInverted = true

        // act
        eventEmitter.on(Constants.testOffEventName) { _ in
            callbackCalled.fulfill()
        }

        eventEmitter.off(Constants.testOffEventName)
        eventEmitter.emit(Constants.testOffEventName, data: Data())

        // assert
        wait(for: [callbackCalled], timeout: Constants.invertedCallbackWaitTimeout)
    }

    // MARK: - Тест потокобезопасности

    func testThreadSafetyWhenAddingListeners() {
        // arrange
        let concurrentQueue = DispatchQueue(label: Constants.concurrentTestQueue, attributes: .concurrent)
        let group = DispatchGroup()

        // act
        for _ in .zero..<Constants.concurrentOperationsCount {
            concurrentQueue.async(group: group) {
                self.eventEmitter.on(Constants.threadSafeEventName) { _ in }
            }
        }

        group.wait()

        // assert
        let listenersCount = eventEmitter.listeners[Constants.threadSafeEventName]?.count ?? .zero
        XCTAssertEqual(listenersCount, Constants.concurrentOperationsCount, Constants.callbackAddedSafely)
    }
}
