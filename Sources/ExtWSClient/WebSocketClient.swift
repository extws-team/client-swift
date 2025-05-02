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
        static let maxReconnectDelay: TimeInterval = 30
        static let pingInterval: TimeInterval = 20
        static let initialReconnectDelayBase: Double = 2.0
        static let nanosecondsPerSecond: Double = 1_000_000_000
        static let connectEvent = "connect"
        static let disconnectEvent = "disconnect"
        static let messageEvent = "message"
        static let webSocketRequestLog =
                """
                [WebSocketClient] 🛠️ WebSocket Request:
                - URL: %@
                - Headers: %@
                """
    }

    // MARK: - Public properties

    public let url: URL                        // URL сервера WebSocket
    public var isConnected: Bool {             // Флаг текущего состояния подключения
        get async { await state.isConnected }
    }

    // MARK: - Event Handlers

    public var beforeConnect: ((URLRequest) -> URLRequest)?       // Обработчик модификации запроса перед подключением
    public var onUpgradeError: ((HTTPURLResponse) -> Void)?       // Обработчик ошибок обновления соединения
    public var onConnectionStatusChanged: ((Bool) -> Void)?       // Обработчик изменения статуса подключения
    public var onHTTPResponse: ((HTTPURLResponse) -> Void)?       // Обработчик HTTP ответов

    // MARK: - Private properties

    private let payloadSerializer: PayloadSerializerProtocol = PayloadSerializer()  // Сериализатор полезной нагрузки
    private let maxReconnectDelay: TimeInterval = Constants.maxReconnectDelay       // Максимальная задержка переподключения
    private let state = WebSocketState()                                            // Состояние WebSocket соединения
    private let eventEmitter = EventEmitter()                                       // Эмиттер событий
    private var webSocketTask: WebSocketTaskProtocol?                               // Текущая задача WebSocket
    private var pingTimer: Timer?                                                   // Таймер для ping-сообщений

    private let delegate = WebSocketTaskDelegate()

    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }()

    // MARK: - Lifecycle

    /// Инициализирует WebSocket клиент
    /// - Parameter url: URL сервера WebSocket
    public init(url: URL) {
        self.url = url
    }

    deinit {
        disconnectSync()
    }

    // MARK: - Connection Management

    /// Устанавливает соединение с сервером WebSocket
    public func connect() async {
        guard !(await state.isConnected) else {
            return
        }

        await MainActor.run {
            var request = URLRequest(url: url)

            if let beforeConnect = beforeConnect {
                request = beforeConnect(request)
            }

            debugPrint(String(
                format: Constants.webSocketRequestLog,
                request.url?.absoluteString ?? "nil",
                request.allHTTPHeaderFields ?? [:]))

            webSocketTask = session.webSocketTask(with: request)
            webSocketTask?.resume()
            startPing()
            listen()
        }

        await state.updateConnectionStatus(true)
        onConnectionStatusChanged?(true)
        eventEmitter.emit(Constants.connectEvent, data: Data())

        Task {
            await flushQueue()
        }
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

    // MARK: - Message Handling

    /// Отправляет структурированное сообщение
    /// - Parameters:
    ///   - type: Тип сообщения
    ///   - event: Название события
    ///   - data: Данные для отправки
    public func send<T: PayloadData>(type: PayloadType, event: String? = nil, data: T?) {
        Task {
            do {
                let message = try payloadSerializer.build(type: type, event: event, data: data)

                if await state.isConnected, webSocketTask != nil {
                    try await sendInternal(data: message)
                } else {
                    print("[send] Queuing message because not connected")
                    await state.enqueue(data: message)
                }

            } catch {
                print("[send] Failed to build message: \(error)")
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

    /// Внутренняя реализация отправки данных
    /// - Parameter data: Данные для отправки
    private func sendInternal(data: Data) async throws {
        guard let task = webSocketTask else {
            print("[sendInternal] webSocketTask is nil")
            throw WebSocketError.connectionClosed
        }
        print("[sendInternal] Attempting to send message")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(.data(data)) { [weak self] error in
                if let error = error {
                    print("[sendInternal] Send failed: \(error)")
                    self?.reconnect()
                    continuation.resume(throwing: WebSocketError.sendFailed(error))
                } else {
                    print("[sendInternal] Send succeeded")
                    continuation.resume()
                }
            }
        }
    }

    /// Синхронное отключение от сервера
    private func disconnectSync() {
        pingTimer?.invalidate()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        onConnectionStatusChanged?(false)
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

            if let task = self.webSocketTask,
               let httpResponse = self.getHTTPResponse(for: task) {
                self.onHTTPResponse?(httpResponse)
            }
            switch result {
            case .success(.data(let data)):
                self.handleMessage(data)
                self.listen()
            case .success(.string(let text)):
                if let data = text.data(using: .utf8) {
                    self.handleMessage(data)
                }
                self.listen()
            case .success:
                self.listen()
            case .failure:
                if let task = self.webSocketTask,
                   let httpResponse = self.getHTTPResponse(for: task),
                   httpResponse.statusCode == 401 {
                    self.onUpgradeError?(httpResponse)
                } else {
                    self.reconnect()
                }
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
        print("[flushQueue] Queue count = \(queue.count)")
        for data in queue {
            print("[flushQueue] Sending message...")
            try? await sendInternal(data: data)
        }
    }

    // MARK: - Response Handling

    /// Получает HTTP-ответ для текущей WebSocket задачи
    /// - Parameter task: Задача WebSocket соединения, реализующая протокол WebSocketTaskProtocol
    /// - Returns: HTTPURLResponse, если задача является URLSessionWebSocketTask и ответ доступен, иначе nil
    private func getHTTPResponse(for task: WebSocketTaskProtocol) -> HTTPURLResponse? {
        guard let urlSessionTask = task as? URLSessionWebSocketTask else { return nil }
        return delegate.getResponse(for: urlSessionTask)
    }
}

