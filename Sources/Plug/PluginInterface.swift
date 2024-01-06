/// These represent the events on the plugin lifecycle.
public enum PluginLifecycleEvent {
    /// Called when the plugin is loaded.
    case load
    
    /// Called when the plugin is unloaded. The plugin is unloaded manually or when the application exits.
    case unload
}

/// Implement this interface to create a plugin.
public protocol PluginInterface {
    /// The associated plugin builder.
    associatedtype Builder: Plug.PluginBuilder
    
    /// The name of the plugin.
    var name: String { get }
    
    /// The version of the plugin.
    var version: String { get }
    
    /// The author of the plugin.
    var author: String { get }

    /// Handles the plugin's lifecycle events.
    func on(event: PluginLifecycleEvent) -> Void

    /// Handles the plugin's custom events, emitted by the application.
    func on(event: String, data: Any?) async -> Void

    /// This function shouldn't be implemented by the plugin directly.
    /// It is added by the `@Plugin` macro.
    /// It initializes the plugin with the builder.
    init(_ builder: Builder)

    /// This function shouldn't be implemented by the plugin directly.
    /// It is added by the `@Plugin` macro.
    /// It is used to send events to the application.
    func send(name: String, data: Any?) -> Void

    /// This function shouldn't be implemented by the plugin directly.
    /// It is added by the `@Plugin` macro.
    /// `PluginBuilder` reference.
    /// WARNING: In the default implementation, this is an unowned reference. This means that ARC will assume the builder outlives the plugin. Therefore, if you forget to stop a task and it ends up consuming the builder when it has been deinitialized already, the whole application will crash.
    var builder: Builder? { get set }
}
