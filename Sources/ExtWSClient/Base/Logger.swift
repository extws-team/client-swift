//
//  Logger.swift
//  m1
//
//  Created by d.kotina on 30.04.2025.
//

import Foundation

/// Протокол для системы логирования сообщений
/// Определяет базовый метод для записи логов
protocol LoggerProtocol {
    /// Записывает сообщение в лог
    /// - Parameter message: Текст сообщения для логирования
    /// - Parameter error: флаг определения ошибки
    func log(_ message: String, error: Bool)
}

/// Реализация логгера с возможностью наблюдения через SwiftUI
/// Сохраняет историю сообщений и выводит их в консоль
final class Logger: LoggerProtocol, ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var messages: [String] = [] // Массив сохраненных лог-сообщений

    // MARK: - Public Methods

    /// Добавляет новое сообщение в лог
    /// - Parameter message: Текст сообщения для добавления
    func log(_ message: String, error: Bool) {
        let formatter = DateFormatter()
        formatter.dateFormat = Constants.logDateFormat
        let timestamp = formatter.string(from: Date())

        DispatchQueue.main.async {
            let fullMessage = self.formatMessage(message, timestamp: timestamp)
            self.addNewMessage(fullMessage)
            self.printToConsole(fullMessage, error: error)
            self.trimMessageBufferIfNeeded()
        }
    }

    // MARK: - Private Methods

    /// Форматирует сообщение для лога
    /// - Parameters:
    ///   - message: Исходное сообщение
    ///   - timestamp: Временная метка
    /// - Returns: Отформатированное сообщение
    private func formatMessage(_ message: String, timestamp: String) -> String {
        return "[\(timestamp)] \(message)"
    }

    /// Добавляет сообщение в буфер
    /// - Parameter message: Сообщение для добавления
    private func addNewMessage(_ message: String) {
        messages.append(message)
    }

    /// Выводит сообщение в консоль
    /// - Parameter message: Сообщение для вывода
    private func printToConsole(_ message: String, error: Bool) {
        let message = error ? "🔴 \(message)" : "🟢 \(message)"
        debugPrint(message)
    }

    /// Ограничивает размер буфера сообщений
    private func trimMessageBufferIfNeeded() {
        if messages.count > Constants.maxLogMessages {
            messages.removeFirst()
        }
    }

    // MARK: - Constants

    private enum Constants {
        static let logDateFormat = "HH:mm:ss.SSS"
        static let maxLogMessages = 100
    }
}
