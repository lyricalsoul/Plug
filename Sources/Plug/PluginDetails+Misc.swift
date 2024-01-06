import Foundation

/// Struct that contains the details of a plugin, such as its name, version, author, path, etc.
public struct PluginDetails {
    /// The name of the plugin.
    public var name: String
    /// The version of the plugin.
    public var version: String
    /// The author of the plugin.
    public var author: String
    /// The path of the plugin.
    public var path: String
    /// The filename of the plugin, without the extension.
    public var filename: String {
        return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}

/// Struct containing data related to a loaded plugin, such as its builder instance, details, etc.
public struct LoadedPlugin {
    /// The plugin's builder instance.
    public var builder: PluginBuilder
    /// The plugin's details.
    public var details: PluginDetails
    /// The plugin's dynamic library reference.
    var dylibReference: UnsafeMutableRawPointer
}