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
        static let timeout: TimeInterval = 5
        static let maxReconnectDelay: TimeInterval = 30
        static let initialReconnectDelayBase: Double = 2.0
        static let idleTimeout: TimeInterval = 60
        static let maxConcurrentOperationCount: Int =  1
        static let nanosecondsPerSecond: Double = 1_000_000_000
        static let unauthorizedStatusCode = 401
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
    private var pongTimer: Timer?                                                   // Таймер для pong-сообщений
    private let delegate = WebSocketTaskDelegate()                                  // Делегат для обработки ответа
    private let session: URLSessionProtocol                                         // Сессия
    private var idleTimeout: TimeInterval = Constants.idleTimeout                   // Таймаут
    private let logger: LoggerProtocol = Logger()                                   // Логгер

    // MARK: - Lifecycle

    /// Инициализирует клиент с указанными параметрами
    /// - Parameters:
    ///   - url: URL сервера WebSocket
    ///   - session: Опциональная пользовательская сессия URLSession
    public init(
        url: URL,
        session: URLSessionProtocol? = nil
    ) {
        self.url = url

        if let session = session {
            self.session = session
        } else {
            let dispatchQueue = DispatchQueue(label: Ln.delegateQueueName)
            let operationQueue = OperationQueue()
            operationQueue.underlyingQueue = dispatchQueue
            operationQueue.maxConcurrentOperationCount = Constants.maxConcurrentOperationCount

            self.session = SessionWrapper(
                configuration: .default,
                delegate: delegate,
                delegateQueue: operationQueue
            )
        }
    }

    deinit {
        disconnectSync()
    }

    // MARK: - Connection Management

    /// Устанавливает соединение с WebSocket сервером
    public func connect() async {
        guard !(await state.isConnected) else {
            return
        }

        await MainActor.run {
            var request = URLRequest(url: url)

            if let beforeConnect = beforeConnect {
                request = beforeConnect(request)
            }

            logger.log(
                String(
                    format: Constants.webSocketRequestLog,
                    request.url?.absoluteString ?? Ln.emptyString,
                    request.allHTTPHeaderFields ?? [:]),
                error: false)

            webSocketTask = session.webSocketTask(with: request)
            webSocketTask?.resume()
            listen()
        }

        await state.updateConnectionStatus(true)
        onConnectionStatusChanged?(true)
        eventEmitter.emit(Ln.connectEvent, data: Data())

        Task {
            await flushQueue()
        }
    }

    /// Разрывает текущее соединение с сервером
    public func disconnect() async {
        await MainActor.run {
            pingTimer?.invalidate()
            pongTimer?.invalidate()
            webSocketTask?.cancel(with: .goingAway, reason: nil)
            webSocketTask = nil
        }

        await state.updateConnectionStatus(false)
        eventEmitter.emit(Ln.disconnectEvent, data: Data())
    }

    // MARK: - Message Handling

    /// Отправляет сообщение через WebSocket
    /// - Parameters:
    ///   - type: Тип полезной нагрузки
    ///   - event: Название события (опционально)
    ///   - data: Данные для отправки (опционально)
    public func send<T: PayloadData>(type: PayloadType, event: String? = nil, data: T?) {
        Task {
            do {
                let message = try payloadSerializer.build(type: type, event: event, data: data)

                if await state.isConnected, webSocketTask != nil {
                    try await sendInternal(data: message)
                } else {
                    logger.log("[WebSocketClient send] Queuing message because not connected", error: true)
                    await state.enqueue(data: message)
                }

            } catch {
                logger.log("[WebSocketClient send] Failed to build message: \(error)", error: true)
            }
        }
    }

    /// Регистрирует обработчик для указанного события
    /// - Parameters:
    ///   - event: Название события
    ///   - callback: Коллбэк для обработки данных события
    public func on(_ event: String, callback: @escaping (Data) -> Void) {
        eventEmitter.on(event, callback: callback)
    }

    // MARK: - Private methods

    /// Внутренний метод для отправки данных
    private func sendInternal(data: Data) async throws {
        guard let task = webSocketTask else {
            logger.log("[WebSocketClient sendInternal] webSocketTask is nil", error: true)
            throw WebSocketError.connectionClosed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.send(.data(data)) { [weak self] error in
                if let error = error {
                    self?.logger.log("[WebSocketClient sendInternal] Send failed: \(error)", error: true)
                    self?.reconnect()
                    continuation.resume(throwing: WebSocketError.sendFailed(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Синхронно разрывает соединение
    private func disconnectSync() {
        pingTimer?.invalidate()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        onConnectionStatusChanged?(false)
    }

    /// Отправляет ping-сообщение
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                self?.logger.log("[WebSocketClient sendPing] error: \(error)", error: true)
                self?.reconnect()
            } else {
            }
        }
    }

    /// Отправляет pong-сообщение
    private func sendPong() {
        do {
            let pongData = try payloadSerializer.build(
                type: .pong,
                event: nil,
                data: EmptyPayload?.none
            )

            webSocketTask?.send(
                .data(pongData),
                completionHandler: { [weak self] error in
                    if let error = error {
                        self?.logger.log("[WebSocketClient sendPong] error: \(error)", error: true)
                        self?.reconnect()
                    }
                }
            )
        } catch {
            logger.log("Failed to create pong: \(error)", error: true)
        }
    }

    /// Запускает таймер для отправки ping-сообщений
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(
            withTimeInterval: idleTimeout - Constants.timeout,
            repeats: true) { [weak self] _ in
            self?.sendPing()
            self?.startPongTimer()
        }
    }

    /// Запускает таймер ожидания pong-ответа
    private func startPongTimer() {
        pongTimer?.invalidate()
        pongTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.timeout,
            repeats: false
        ) { [weak self] _ in
            self?.reconnect()
        }
    }

    /// Отменяет таймер ожидания pong-ответа
    private func cancelPongTimer() {
        pongTimer?.invalidate()
        pongTimer = nil
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
                   httpResponse.statusCode == Constants.unauthorizedStatusCode {
                    self.onUpgradeError?(httpResponse)
                } else {
                    self.reconnect()
                }
            }
        }
    }

    /// Обрабатывает входящее сообщение
    private func handleMessage(_ data: Data) {
        cancelPongTimer()

        do {
            let (type, _, payloadData) = try payloadSerializer.parseHeader(from: data)

            switch type {
                case .ping:
                    sendPong()
                case .timeout:
                    let initData = try payloadSerializer.decode(InitData.self, from: payloadData)
                handleTimeoutMessage(initData)
                case .message:
                    eventEmitter.emit(Ln.messageEvent, data: data)
                case .pong:
                    sendPing()
                case .error:
                    logger.log("[WebSocketClient handleMessage type: Error]", error: true)
            }
        } catch {
            logger.log("[WebSocketClient handleMessage] Error parsing message: \(error)", error: true)
        }
    }

    /// Обрабатывает данные timeout
    private func handleTimeoutMessage(_ data: InitData) {
        self.idleTimeout = TimeInterval(data.idle_timeout)
        startPingTimer()
    }

    /// Выполняет переподключение с экспоненциальной задержкой
    private func reconnect() {
        logger.log("[WebSocketClient reconnect] Initiating reconnect", error: false)
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
        logger.log("[WebSocketClient flushQueue] Queue count = \(queue.count)", error: false)

        for data in queue {
            logger.log("[WebSocketClient flushQueue] Sending message...", error: false)
            try? await sendInternal(data: data)
        }
    }

    // MARK: - Response Handling

    /// Возвращает HTTP ответ для задачи WebSocket
    private func getHTTPResponse(for task: WebSocketTaskProtocol) -> HTTPURLResponse? {
        guard let urlSessionTask = task as? URLSessionWebSocketTask else { return nil }

        if let saved = delegate.getResponse(for: urlSessionTask) {
            return saved
        }

        if let direct = urlSessionTask.response as? HTTPURLResponse {
            return direct
        }

        return nil
    }
}
