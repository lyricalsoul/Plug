# 🔌 Plug
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat)](https://swift.org)
[![License](https://img.shields.io/github/license/lyricalsoul/Plug.svg?style=flat)]
[![Documentation](https://img.shields.io/badge/Documentation-yes-blue.svg?style=flat)](https://lyricalsoul.github.io/Plug/)

Plug is a library for developing plugins for Swift applications. By using macros, it allows you to have simple and clean code and still keep the flexibility of a plugin system. You can load, reload and unload plugins at runtime, change the code used between the plugin and the app, and more.

Refer to the [documentation](https://lyricalsoul.github.io/Plug/) for more information.

This is what a plugin looks like:
```swift
import Plug

@Plugin
struct ExamplePlugin : PluginInterface {
    var version = "1.0.0"
    var author = "John Doe"

    func on(event: PluginLifecycleEvent) -> Void {
        switch event {
        case .load:
            // plugin loaded
            break
        case .unload:
            // plugin unloaded
            break
        }
    }

    func on(event: String, data: Any?) async -> Void {
        if event == "ping" {
            send(name: "pong", data: data)
        }
    }
}
```

And this is how you load it:
```swift
import Plug

let manager = PluginManager()
try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin") { plugin in
    plugin.on(name: "pong") { (text: String) in
        print("Received pong event from plugin with text: \(text)")
    }
}

await manager.send(event: "ping", data: "hello world", to: { $0.name == "ExamplePlugin" })
```

## Installation
### Swift Package Manager
```swift
        .package(url: "https://github.com/lyricalsoul/Plug.git", from: "1.0.0")
```
