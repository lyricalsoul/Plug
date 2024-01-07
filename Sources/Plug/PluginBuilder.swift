/// This protocol defines the interface for a plugin builder.
/// Normally, you don't need to implement your own builder, since the `@Plugin` macro
/// does that for you. However, if you need to implement your own builder,
/// you can do so by implementing this protocol and passing it to the macro.
open class PluginBuilder {
    /// Dictionary of event callbacks.
    var eventCallbacks: [String: (Any?) -> Void]  = [:]

    /// The associated plugin instance.
    /// - Note: Please implement a deinitializer that emits the `unload` event to avoid memory leaks.
    public var associatedPlugin: (any PluginInterface)? = nil

    /// Registers an event callback. This callback will be used when the plugin emits an event.
    /// - Parameters:
    ///    - name: The name of the event.
    ///    - callback: The callback to call when the event is emitted.
    /// - Returns: Void.
    /// - Throws: None.
    func register(name: String, callback: @escaping ((Any?) -> Void)) {
        eventCallbacks[name] = callback
    }

    /// Sends an event from the plugin to the application.
    /// - Parameters:
    ///     - name: The name of the event.
    ///     - data: The data to send with the event.
    /// - Returns: Void.
    /// - Throws: None.
    public func send(name: String, data: Any?) {
        if let callback = self.eventCallbacks[name] {
            callback(data)
        }
    }

    /// Receives an event from the application.
    /// - Parameters:
    ///    - event: The name of the event.
    ///    - data: The data to send with the event.
    /// - Returns: Void.
    /// - Throws: None.
    public func receive(event: String, data: Any?) async {
        await associatedPlugin?.on(event: event, data: data)
    }

    /// Builds the plugin. This has to be overriden if you're implementing your own builder.
    /// - Parameters: None.
    /// - Returns: None.
    /// - Throws: None.
    open func build() {
        fatalError("Please implement the build() method in your custom builder.")
    }

    /// Destroys the plugin.
    /// - Parameters: None.
    /// - Returns: Void.
    /// - Throws: None.
    /// - Note: This method is called automatically when the plugin is deinitialized.
    public func destroy() {
        associatedPlugin?.on(event: .unload)
        associatedPlugin = nil
        eventCallbacks = [:]
    }

    deinit {
        if associatedPlugin != nil {
            destroy()
        }
    }

    public init () {}

    /// Stores the plugin instance.
    /// - Parameters:
    ///    - plugin: The plugin instance to store.
    /// - Returns: Void.
    public func storePlugin(_ plugin: (any PluginInterface)) {
        associatedPlugin = plugin
        associatedPlugin!.on(event: .load)
    }
}

/// Wrapper providing some syntactic sugar for registering events on a loaded builder.
public struct LoadedPluginBuilder {
    /// The loaded plugin.
    private var builder: PluginBuilder
    /// The MD5 hash of the plugin's binary.
    public var md5: String

    /// Initializes the wrapper with a loaded plugin.
    init (_ builder: PluginBuilder, md5: String) {
        self.builder = builder
        self.md5 = md5
    }

    /// Get the plugin's name.
    var name: String? {
        return builder.associatedPlugin?.name
    }

    /// Get the plugin's version.
    var version: String? {
        return builder.associatedPlugin?.version
    }

    /// Get the plugin's author.
    var author: String? {
        return builder.associatedPlugin?.author
    }

    /// Registers an event callback. This callback will be used when the plugin emits an event.
    /// - Parameters:
    ///   - name: The name of the event.
    ///   - callback: The callback to call when the event is emitted.
    /// - Returns: Void.
    /// - Throws: None.
    public func on<T: Any>(name: String, callback: @escaping ((T) -> Void)) -> Void {
        builder.register(name: name) { data in
            callback((data as? T)!)
        }
    }

    public func on(name: String, callback: @escaping (() -> Void)) -> Void {
        builder.register(name: name) { _ in
            callback()
        }
    }
}