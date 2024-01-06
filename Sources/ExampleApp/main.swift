import Plug

// This app is an example of how to use Plug from the application side.
// It loads the ExemplePlugin from the build directory and sends it a custom event.
// It also sends a custom event to the application from the plugin.
let manager = PluginManager()
try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin") { plugin in
    plugin.on(name: "pong") { (text: String) in
        print("Received pong event from plugin with text: \(text)")
    }
}

await manager.send(event: "ping", data: "hello world", to: { $0.name == "ExamplePlugin" })