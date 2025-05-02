//
//  Payload.swift
//  ExtWSClient
//
//  Created by d.kotina on 19.04.2025.
//

import Foundation

/// Типы полезной нагрузки WebSocket сообщения
public enum PayloadType: String, Codable {
    /// Событие (например, "user_joined")
    case event
    /// Текстовое/бинарное сообщение
    case message
    /// Ошибка (например, "invalid_format")
    case error
}

/// Протокол, который должны реализовать все типы данных, передаваемые в Payload.
/// Гарантирует, что данные можно закодировать/декодировать.
public protocol PayloadData: Codable {}

/// Универсальная структура полезной нагрузки
public struct Payload<T: PayloadData>: Codable {
    let type: PayloadType
    let event: String?
    let data: T?
}
 
public protocol PayloadSerializerProtocol {
    func build<T: PayloadData>(type: PayloadType, event: String?, data: T?) throws -> Data
    func parse<T: PayloadData>(_ data: Data) throws -> Payload<T>
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
}