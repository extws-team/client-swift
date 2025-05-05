//
//  Payload.swift
//  ExtWSClient
//
//  Created by d.kotina on 19.04.2025.
//

import Foundation

struct InitData: PayloadData, Codable {
    let id: String
    let idle_timeout: Int
}

struct EmptyPayload: PayloadData {
    init() {}
}

/// Типы полезной нагрузки WebSocket сообщения
public enum PayloadType: Int, Codable {
    case error = -1
    case timeout = 1
    case ping = 2
    case pong = 3
    case message = 4
}

/// Протокол, который должны реализовать все типы данных, передаваемые в Payload.
/// Гарантирует, что данные можно закодировать/декодировать.
public protocol PayloadData: Codable {}

/// Универсальная структура полезной нагрузки
public struct Payload<T: PayloadData>: Codable {
    let type: PayloadType
    let event: String?
    public let data: T?
}

public protocol PayloadSerializerProtocol {
    func build<T: PayloadData>(type: PayloadType, event: String?, data: T?) throws -> Data
    func parse<T: PayloadData>(_ data: Data) throws -> Payload<T>
    func parseHeader(from data: Data) throws -> (PayloadType, String?, Data?)
    func decode<T: PayloadData>(_ type: T.Type, from data: Data?) throws -> T
}

/// Класс для сериализации и десериализации Payload.
/// Отвечает за упаковку и распаковку сообщений в формате JSON.
public final class PayloadSerializer: PayloadSerializerProtocol {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    /// Кодирует данные в формате Payload и возвращает JSON-Data.
    public func build<T: PayloadData>(type: PayloadType, event: String?, data: T?) throws -> Data {
        let payload = Payload(type: type, event: event, data: data)
        return try encoder.encode(payload)
    }

    /// Декодирует JSON-Data в структуру Payload с заданным типом данных.
    public func parse<T: PayloadData>(_ data: Data) throws -> Payload<T> {
        return try decoder.decode(Payload<T>.self, from: data)
    }

    /// Декодирует заголовки сообщений
    public func parseHeader(from data: Data) throws -> (PayloadType, String?, Data?) {
        let string = String(data: data, encoding: .utf8) ?? Ln.emptyString

        guard let typeChar = string.first else {
            Logger().log("[PayloadSerializer] Missing type character", error: true)
            throw WebSocketError.invalidPayload
        }

        guard let typeValue = Int(String(typeChar)) else {
            Logger().log("[PayloadSerializer] Invalid type character: \(typeChar)", error: true)
            throw WebSocketError.invalidPayload
        }

        guard let type = PayloadType(rawValue: typeValue) else {
            Logger().log("[PayloadSerializer] Unknown type value: \(typeValue)", error: true)
            throw WebSocketError.invalidPayload
        }

        let content = String(string.dropFirst())

        guard let jsonStart = content.firstIndex(where: { ["{", "["].contains($0) }) else {
            Logger().log("[PayloadSerializer] JSON start not found", error: true)
            return (type, nil, nil)
        }

        let event = String(content[..<jsonStart])
        let jsonString = String(content[jsonStart...])

        guard let jsonData = jsonString.data(using: .utf8) else {
            Logger().log("[PayloadSerializer] Failed to convert JSON string to Data", error: true)
            throw WebSocketError.invalidPayload
        }

        return (type, event.isEmpty ? nil : event, jsonData)
    }

    public func decode<T: PayloadData>(_ type: T.Type, from data: Data?) throws -> T {
        guard let data = data else { throw WebSocketError.missingData }
        return try decoder.decode(type, from: data)
    }
}
