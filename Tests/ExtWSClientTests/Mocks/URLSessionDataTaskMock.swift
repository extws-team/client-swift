//
//  URLSessionDataTaskMock.swift
//  ExtWSClient
//
//  Created by d.kotina on 28.04.2025.
//

import XCTest
@testable import ExtWSClient

final class URLSessionDataTaskMock: URLSessionDataTask, @unchecked Sendable {

    var completionHandler: ((Data?, URLResponse?, Error?) -> Void)?

    override func resume() {
        let data = Data()
        let response = HTTPURLResponse(
            url: URL(string: "http://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        completionHandler?(data, response, nil)
    }
}

