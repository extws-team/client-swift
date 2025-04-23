//
//  WebSocketClient.swift
//  ExtWSClient
//
//  Created by d.kotina on 19.04.2025.
//

import Foundation

/// Клиент для работы с WebSocket соединением
public final class WebSocketClient {

    // MARK: - Constants

    private enum Constants {
        /// Максимальная задержка переподключения в секундах
        static let maxReconnectDelay: TimeInterval = 30
        /// Интервал отправки ping-сообщений
        static let pingInterval: TimeInterval = 20
        /// Базовое значение для экспоненциальной задержки
        static let initialReconnectDelayBase: Double = 2.0
        /// Коэффициент перевода секунд в наносекунды
        static let nanosecondsPerSecond: Double = 1_000_000_00

        /// Событие подключения
        static let connectEvent = "connect"
        /// Событие отключения
        static let disconnectEvent = "disconnect"
        /// Событие получения сообщения
        static let messageEvent = "message"

        // Логи
        enum Log {
            static let connectionClosed = "[WebSocketClient] ❌ Send failed: no active connection"
            static let alreadyConnected = "[WebSocketClient] Already connected, aborting"
            static let pingFailed = "Ping failed: %@"
            static let receiveFailed = "Receive failed: %@"
            static let encodingError = "Encoding error: %@"
            static let sendFaild = "Send failed: %@"
        }
    }

    // MARK: - WebSocketError
    /// Ошибки WebSocket клиента
    enum WebSocketError: Error {
        /// Соединение закрыто
        case connectionClosed
        /// Ошибка кодирования данных
        case encodingFailed(Error)
        /// Ошибка отправки данных
        case sendFailed(Error)
        /// Локализованное описание ошибки
        var localizedDescription: String {
            switch self {
            case .connectionClosed:
                return Constants.Log.connectionClosed
            case .encodingFailed(let error):
                return String(format: Constants.Log.encodingError, error.localizedDescription)
            case .sendFailed(let error):
                return String(format: Constants.Log.sendFaild, error.localizedDescription)
            }
        }
    }

    // MARK: - Public properties

    /// URL сервера WebSocket
    public let url: URL
    /// Флаг текущего состояния подключения
    public var isConnected: Bool {
        get async { await state.isConnected }
    }

    // MARK: - Private properties

    /// Состояние WebSocket соединения
    private let state = WebSocketState()
    /// Сессия для создания WebSocket задач
    private let session: URLSessionProtocol
    /// Сериализатор полезной нагрузки
    private let payloadSerializer: PayloadSerializerProtocol = PayloadSerializer()
    /// Эмиттер событий
    private let eventEmitter = EventEmitter()
    /// Текущая задача WebSocket
    private var webSocketTask: WebSocketTaskProtocol?
    /// Таймер для ping-сообщений
    private var pingTimer: Timer?
    /// Максимальная задержка переподключения
    private let maxReconnectDelay: TimeInterval = Constants.maxReconnectDelay

    // MARK: - Lifecycle

    /// Инициализация WebSocket клиента
    /// - Parameters:
    ///   - url: URL сервера WebSocket
    ///   - session: Сессия для создания соединения
    public init(url: URL, session: URLSessionProtocol = URLSession.shared) {
        self.url = url
        self.session = session
    }

    deinit {
        disconnectSync()
    }

    // MARK: - Public methods

    /// Устанавливает соединение с сервером WebSocket
    public func connect() async {
        guard !(await state.isConnected) else {
            print(Constants.Log.alreadyConnected)
            return
        }

        await MainActor.run {
            webSocketTask = session.webSocketTask(with: url)
            webSocketTask?.resume()
            startPing()
            listen()
        }

        await state.updateConnectionStatus(true)
        eventEmitter.emit(Constants.connectEvent, data: Data())
        await flushQueue()
    }

    /// Разрывает соединение с сервером WebSocket
    public func disconnect() async {
        await MainActor.run {
            pingTimer?.invalidate()
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }
        await state.updateConnectionStatus(false)
        eventEmitter.emit(Constants.disconnectEvent, data: Data())
    }

    /// Отправляет структурированное сообщение
    /// - Parameters:
    ///   - type: Тип сообщения
    ///   - event: Название события
    ///   - data: Данные для отправки
    public func send<T: PayloadData>(type: PayloadType, event: String? = nil, data: T?) {
        Task {
            do {
                let message = try payloadSerializer.build(type: type, event: event, data: data)
                try await sendInternal(data: message)
            } catch {
                throw WebSocketError.encodingFailed(error)
            }
        }
    }

    /// Подписывается на получение событий WebSocket
    /// - Parameters:
    ///   - event: Название события
    ///   - callback: Обработчик события
    public func on(_ event: String, callback: @escaping (Data) -> Void) {
        eventEmitter.on(event, callback: callback)
    }

    // MARK: - Private methods

    /// Синхронное отключение от сервера
    private func disconnectSync() {
        pingTimer?.invalidate()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    /// Внутренняя реализация отправки данных
    /// - Parameter data: Данные для отправки
    private func sendInternal(data: Data) async throws {
        guard let task = webSocketTask else {
            print(Constants.Log.connectionClosed)
            throw WebSocketError.connectionClosed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(.data(data)) { [weak self] error in
                if let error = error {
                    self?.reconnect()
                    continuation.resume(throwing: WebSocketError.sendFailed(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Запускает периодическую отправку ping-сообщений
    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.pingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.sendPing()
        }
    }

    /// Отправляет ping-сообщение
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                let wsError = WebSocketError.encodingFailed(error)
                print(wsError.localizedDescription)
                self?.reconnect()
            }
        }
    }

    /// Начинает прослушивание входящих сообщений
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(.data(let data)):
                self.handleMessage(data)
                self.listen()
            case .success:
                self.listen()
            case .failure(let error):
                let wsError = WebSocketError.encodingFailed(error)
                print(wsError.localizedDescription)
                self.reconnect()
            }
        }
    }

    /// Обрабатывает полученное сообщение
    /// - Parameter data: Полученные данные
    private func handleMessage(_ data: Data) {
        eventEmitter.emit(Constants.messageEvent, data: data)
    }

    /// Выполняет процедуру переподключения
    private func reconnect() {
        Task {
            await disconnect()
            let attempts = await state.reconnectAttempts
            let delay = min(pow(Constants.initialReconnectDelayBase, Double(attempts)), maxReconnectDelay)
            try? await Task.sleep(nanoseconds: UInt64(delay * Constants.nanosecondsPerSecond))
            await MainActor.run { webSocketTask = nil }
            await connect()
        }
    }

    /// Отправляет все сообщения из очереди
    private func flushQueue() async {
        let queue = await state.flushQueue()
        for data in queue { try? await sendInternal(data: data) }
    }
}
