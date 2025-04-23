
# WebSocket клиент для Swift

[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://developer.apple.com/ios/)

**WebSocketClient** — Swift-клиент для работы с WebSocket, поддерживающий автоматическое переподключение, очереди сообщений и расширяемую архитектуру.

## Возможности

- 🚀 **Автоматическое переподключение** с экспоненциальной задержкой
- 📦 **Очередь сообщений** при потере соединения
- 💓 **Ping/Pong** для поддержания активности соединения
- 🎭 **Подписка на события** (подключение, сообщения, ошибки)
- 🧩 **Интеграция с URLSession** и кастомными реализациями
- 🧪 **Полная поддержка тестирования**

## Установка

Для интеграции этого WebSocket клиента в Ваш проект на Swift, вы можете либо клонировать репозиторий, либо вручную добавить исходные файлы.

```bash
git clone https://github.com/extws-team/client-swift.git
```

### Swift Package Manager

Добавьте в `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/extws-team/client-swift.git", from: "1.0.0")
]
```

## Использование

### Инициализация

```swift
let url = URL(string: "wss://example.com/socket")!
let client = WebSocketClient(url: url)
client.connect()
```

### Базовый сценарий

```swift
// Подключение
await client.connect()

// Отправка сообщения
struct ChatMessage: PayloadData {
    let text: String
    let author: String
}

client.send(
    type: .message,
    event: "chat",
    data: ChatMessage(text: "Hello!", author: "iOS")
)

// Подписка на события
client.on("message") { data in
    let message = try! JSONDecoder().decode(ChatMessage.self, from: data)
    print("New message: \(message.text)")
}

// Отключение
await client.disconnect()
```
## Расширенные настройки

### Кастомизация переподключения

```swift
client.reconnectDelay = { attempts in
    min(pow(2, Double(attempts)), 60) // Макс. задержка 60 сек
}
```

### Использование кастомной сессии

```swift
class CustomSession: URLSessionProtocol {
    func webSocketTask(with url: URL) -> WebSocketTaskProtocol {
        // Ваша реализация
    }
}

let client = WebSocketClient(
    url: url,
    session: CustomSession()
)
```
## Архитектура

### Основные компоненты

- **WebSocketClient**
- **Основной класс для управления соединением.**
- **WebSocketTaskProtocol**
- **Абстракция над WebSocket-задачей.**
- **PayloadSerializer**
- **Сериализация/десериализация сообщений.**
- **EventEmitter**
- **Система подписки на события.**
