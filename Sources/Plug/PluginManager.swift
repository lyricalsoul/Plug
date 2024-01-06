import Foundation

// find out what extension to use. .dylib on macOS, .so on Linux and .dll on Windows
#if os(macOS)
let extensionName = "dylib"
#elseif os(Linux)
let extensionName = "so"
#elseif os(Windows)
let extensionName = "dll"
#endif

/// Errors related to plugin management.
public enum PluginError : Error, CustomStringConvertible, Equatable {
    /// The plugin is already loaded.
    case alreadyLoaded
    /// The path to the plugin is invalid.
    case invalidPath(path: String)
    /// The symbol (`createPlugin` by default) was not found in the plugin.
    case loadingSymbolNotFound(sym: String)
    /// Unknown error while loading the plugin.
    case unknownError(message: String)
    /// Security error while loading the plugin.
    case securityError

    public var description: String {
        switch self {
        case .alreadyLoaded:
            return "The plugin is already loaded."
        case .invalidPath(let path):
            return "The path \(path) does not contain a redable file"
        case .loadingSymbolNotFound(let sym):
            return "The symbol \(sym) was not found in the plugin."
        case .unknownError(let message):
            return "Unknown error while loading the plugin: \(message)"
        case .securityError:
            return "Security error while loading the plugin. Please refer to the documentation for more information."
        }
    }
}

/// The `PluginManager` is a class responsible for plugin management. This is what you use in your application to load and unload plugins.
public class PluginManager {
    public init() {}
    typealias InitFunction = @convention(c) () -> UnsafeMutableRawPointer

    /// The symbol used to initialize the plugin. Don't change this unless you've changed it in the plugin (or if your plugin doesn't use the `@Plugin` macro).
    /// Be aware that changing this will break compatibility with plugins that use the default symbol. Also, if you have to change this because a plugin doesn't use Plug, you should probably not the plugin in the first place.
    public static let initSymbol = "createPlugin"

    /// The list of loaded plugins.
    private var loadedPlugins: [LoadedPlugin] = []

    /// Finds a loaded plugin by any of its details.
    /// - Parameters:
    ///    - closure: The closure to use to find the plugin.
    /// - Returns: The plugin, if found.
    public func findPluginInformation(where closure: (PluginDetails) -> Bool) -> LoadedPlugin? {
        return loadedPlugins.first(where: { closure($0.details) })
    }

    /// Same thing as `findPlugin(closure:)`, but returns multiple plugins.
    /// - Parameters:
    ///   - closure: The closure to use to find the plugins.
    /// - Returns: The plugins, if found.
    public func findPluginsInformation(where closure: (PluginDetails) -> Bool) -> [LoadedPlugin] {
        return loadedPlugins.filter({ closure($0.details) })
    }

    /// Loads a plugin from a path.
    /// - Parameters:
    ///   - path: The path of the plugin.
    ///   - closure (optional): The closure to use when the plugin is loaded.
    /// - Returns: The loaded plugin.
    /// - Throws: `PluginError` if the plugin could not be loaded (or if it is already loaded).
    public func loadPlugin(path: String, closure: ((LoadedPluginBuilder) async -> Void)? = nil) async throws {
        if findPluginInformation(where: { $0.path == path }) != nil {
            throw PluginError.alreadyLoaded
        }

        if !FileManager.default.isReadableFile(atPath: path) {
            throw PluginError.invalidPath(path: path)
        }

        let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL)
        if handle == nil {
            throw PluginError.unknownError(message: String(cString: dlerror()!))
        }
        
        let symbol = dlsym(handle, PluginManager.initSymbol)
        if symbol == nil {
            throw PluginError.loadingSymbolNotFound(sym: PluginManager.initSymbol)
        }

        let initFunction = unsafeBitCast(symbol!, to: InitFunction.self)
        let pointer = initFunction()
        let builder: PluginBuilder = Unmanaged<PluginBuilder>.fromOpaque(pointer).takeRetainedValue()
        builder.build()

        var wrapper: LoadedPluginBuilder? = LoadedPluginBuilder(builder)
        await closure?(wrapper!)
        

        let details = PluginDetails(
            name: wrapper!.name ?? "unknown",
            version: wrapper!.version ?? "unknown",
            author: wrapper!.author ?? "unknown",
            path: path
        )
        wrapper = nil

        let loadedPlugin = LoadedPlugin(builder: builder, details: details, dylibReference: handle!)
        loadedPlugins.append(loadedPlugin)
    }

    /// Loads all plugins from a directory.
    /// - Parameters:
    ///  - path: The path of the directory.
    /// - closure (optional): The closure to use when a plugin is loaded.
    /// - Returns: The loaded plugins.
    /// - Throws: `PluginError` if a plugin could not be loaded (or if it is already loaded).
    /// - Note: This method will ignore any file that does not have the extension for dynamic libraries (`.dylib` on macOS, `.so` on Linux and `.dll` on Windows).
    public func loadPlugins(path: String, closure: ((LoadedPluginBuilder) async -> Void)? = nil) async throws {
        let files = try FileManager.default.contentsOfDirectory(atPath: path)
        for file in files {
            if file.hasSuffix(".\(extensionName)") {
                try await loadPlugin(path: "\(path)/\(file)", closure: closure)
            }
        }
    }

    /// Loads a plugin, except it doesn't require for an extension to be present in the path.
    /// - Parameters:
    /// - path: The path of the plugin.
    /// - closure (optional): The closure to use when the plugin is loaded.
    /// - Returns: The loaded plugin.
    /// - Throws: `PluginError` if the plugin could not be loaded (or if it is already loaded).
    public func loadPlugin(pathWithoutExtension path: String, closure: ((LoadedPluginBuilder) async -> Void)? = nil) async throws {
        try await loadPlugin(path: "\(path).\(extensionName)", closure: closure)
    }

    /// Unloads a plugin.
    /// - Parameters:
    ///  - closure: The closure to select the plugin to unload.
    public func unloadPlugin(where closure: (PluginDetails) -> Bool) {
        if let index = loadedPlugins.firstIndex(where: { closure($0.details) }) {
            loadedPlugins[index].builder.destroy()
            dlclose(loadedPlugins[index].dylibReference)
            loadedPlugins.remove(at: index)
        }
    }

    /// Unloads all plugins.
    public func unloadAllPlugins() {
        for plugin in loadedPlugins {
            plugin.builder.destroy()
        }
        loadedPlugins = []
    }

    /// Reloads a plugin.
    /// - Parameters:
    ///     - closure: The closure to select the plugin to reload.
    /// - Returns: Bool indicating whether the plugin was reloaded. False it the plugin was not found.
    /// - Throws: `PluginError` if the plugin could not be reloaded.
    public func reloadPlugin(where closure: (PluginDetails) -> Bool) async throws -> Bool {
        if let index = loadedPlugins.firstIndex(where: { closure($0.details) }) {
            let path = loadedPlugins[index].details.path
            unloadPlugin(where: closure)
            let _ = try await loadPlugin(path: path)
            return true
        }
        return false
    }

    /// Finds all plugins matching a closure and sends an event to them.
    /// - Parameters:
    ///   - event: The name of the event.
    ///   - data: The data to send with the event.
    ///   - closure: The closure to select the plugins to send the event to.
    public func send(event: String, data: Any?, to closure: (PluginDetails) -> Bool) async {
        for plugin in loadedPlugins {
            if closure(plugin.details) {
                await plugin.builder.receive(event: event, data: data)
            }
        }
    }
}