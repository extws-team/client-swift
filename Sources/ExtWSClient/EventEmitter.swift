//
//  EventEmitter.swift
//  ExtWSClient
//
//  Created by d.kotina on 19.04.2025.
//

import Foundation

/// Простая реализация системы событий.
/// Позволяет подписываться на события по строковому ключу и вызывать их при необходимости.
final class EventEmitter {

    // MARK: - Constants

    private enum Constants {
        static let queueLabel = "com.eventemitter.queue"
    }

    // MARK: - Typealias

    typealias EventCallback = (Data) -> Void

    // MARK: - Private properties

    private let queue = DispatchQueue(label: Constants.queueLabel, attributes: .concurrent)
    private var _listeners: [String: [EventCallback]] = [:]

    private(set) var listeners: [String: [EventCallback]] {
        get { queue.sync { _listeners } }
        set { queue.async(flags: .barrier) { self._listeners = newValue } }
    }

    // MARK: - Public methods

    /// Добавляет слушателя на определенное событие.
    func on(_ event: String, callback: @escaping EventCallback) {
        queue.async(flags: .barrier) {
            self._listeners[event, default: []].append(callback)
        }
    }

    /// Вызывает все слушатели для конкретного события.
    func emit(_ event: String, data: Data) {
        queue.sync {
            self._listeners[event]?.forEach { $0(data) }
        }
    }

    /// Удаляет всех слушателей конкретного события.
    func off(_ event: String) {
        queue.async(flags: .barrier) {
            self._listeners.removeValue(forKey: event)
        }
    }
}
