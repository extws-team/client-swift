
# WebSocketClient

[![Swift](https://img.shields.io/badge/Swift-5.5+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-13.0+-blue.svg)](https://developer.apple.com/ios/)

Профессиональный WebSocket клиент для Swift, поддерживающий автоматическое переподключение, сериализацию данных и обработку событий.

## Возможности

- 📡 Установка и разрыв соединения с WebSocket сервером.
- 🔄 Автоматическое переподключение с экспоненциальной задержкой.
- 📨 Отправка структурированных сообщений (JSON).
- 🔊 Подписка на события: подключение, отключение, сообщения.
- ⏲️ Периодические ping-сообщения для поддержания соединения.
- 🛠️ Кастомизация запросов перед подключением.
- 🚀 Поддержка async/await.

## Установка

Для интеграции этого WebSocket клиента в Ваш проект на Swift, вы можете либо клонировать репозиторий, либо вручную добавить исходные файлы.

```bash
git clone https://github.com/extws-team/client-swift.git
```

### Swift Package Manager

Добавьте в `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/extws-team/client-swift.git", from: "1.1.0")
]
```

## Быстрый старт

### Инициализация клиента

```swift
let url = URL(string: "wss://your-websocket-server.com")!
let client = WebSocketClient(url: url)
```

## Подключение и отключение

```swift
// Установка соединения
Task {
    await client.connect()
}

// Разрыв соединения
Task {
    await client.disconnect()
}
```

## Использование

### Отправка сообщений

```swift
struct Message: PayloadData {
    let text: String
}

// Отправка кастомного события
client.send(
    type: .event,
    event: "user_message",
    data: Message(text: "Hello World!")
)
```

### Подписка на события

```swift
// Обработка входящих сообщений
client.on("message") { data in
    let payload = try? client.payloadSerializer.parse(data) as Payload<Message>
    print("Received: \(payload?.data?.text ?? "")")
}

// Событие подключения
client.on("connect") { _ in
    print("Connected to server")
}

// Событие отключения
client.on("disconnect") { _ in
    print("Disconnected from server")
}
```

## Дополнительные настройки

### Модификация запроса перед подключением

```swift
client.beforeConnect = { request in
    var modifiedRequest = request
    modifiedRequest.setValue("Bearer token", forHTTPHeaderField: "Authorization")
    return modifiedRequest
}
```

### Обработка HTTP-ответов

```swift
client.onHTTPResponse = { response in
    print("HTTP Status Code: \(response.statusCode)")
}
```

## Автоматическое переподключение

Клиент автоматически переподключается с экспоненциальной задержкой:

- Начальная задержка: 2 секунды
- Максимальная задержка: 30 секунд

```swift
// Отключить автоматическое переподключение (если нужно)
client.reconnect = false
```

## Сериализация данных

Используйте структуры, реализующие PayloadData:

```swift
struct CustomData: PayloadData {
    let id: Int
    let timestamp: Date
}

// Сериализация и отправка
client.send(
    type: .message,
    data: CustomData(id: 42, timestamp: Date())
)
```

## Обработка ошибок

```swift
// Глобальный обработчик ошибок
client.onConnectionStatusChanged = { isConnected in
    if !isConnected {
        print("Connection lost. Reconnecting...")
    }
}

// Ошибки авторизации
client.onUpgradeError = { response in
    if response.statusCode == 401 {
        print("Authentication required")
    }
}
```

## Лицензия
Проект доступен под лицензией MIT. Подробности см. в файле LICENSE.
