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