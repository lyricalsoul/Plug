import Foundation

/// This protocol defines the security requirements for a plugin.
public protocol PluginIntegrity {
    /// Receives the MD5 hash of the plugin's binary. Return true if the hash is valid.
    func canOpenPlugin(withHash hash: String) -> Bool
    /// Receives the loaded plugin data. Return true if the plugin is valid.
    func acceptPlugin(_ plugin: LoadedPluginBuilder) -> Bool
}

/// A simple implementation of `PluginIntegrity`. Should be used for testing purposes only.
public struct SimplePluginWhitelist: PluginIntegrity {
    /// The directives for the plugin loader.
    public enum PluginLoadDirective {
        /// Allow a plugin with a specific MD5 hash.
        case allowMD5(_ md5: String)
        /// Allow a plugin with a specific name.
        /// Warning: This is not a secure way to load plugins. Using it in combination with `allow(md5:)` is pointless, since it will load the plugin anyways.
        case allowName(_ name: String)
    }

    public var directives: [PluginLoadDirective]

    public init(_ directives: [PluginLoadDirective]) {
        self.directives = directives
    }

    public func canOpenPlugin(withHash hash: String) -> Bool {
        // if there are no MD5 directives, we allow all plugins.
        // however, if there are MD5 directives, we only allow plugins with the specified MD5 hashes.
        var failed = false
        directives.forEach { directive in
            switch directive {
            case .allowMD5(let md5):
                if md5 == hash {
                    break
                } else {
                    failed = true
                }
            default:
                break
            }
        }

        return !failed
    }

    public func acceptPlugin(_ plugin: LoadedPluginBuilder) -> Bool {
        // if there are no name directives, we allow all plugins.
        // however, if there are name directives, we only allow plugins with the specified names.
        var failed = false
        directives.forEach { directive in
            switch directive {
            case .allowName(let name):
                if name == plugin.name {
                    break
                } else {
                    failed = true
                }
            default:
                break
            }
        }

        return !failed
    }
}

/// A file-based implementation of `PluginIntegrity`. Recommended for production use.
public struct FileBasedPluginWhitelist : PluginIntegrity {
    /// The JSON object used in the whitelist file.
    public struct WhitelistFile: Codable {
        /// The data of the plugins.
        public var plugins: [WhitelistedPluginData]
    }

    /// The data of a whitelisted plugin.
    public struct WhitelistedPluginData: Codable {
        /// The name of the plugin.
        public var name: String
        /// The version of the plugin.
        public var version: String
        /// The author of the plugin.
        public var author: String
        /// The MD5 hash of the plugin's binary.
        public var md5: String
    }

    /// The path to the whitelist file.
    public var whitelistPath: String = "./plugin-whitelist.json"
    /// The loaded whitelist file.
    public var whitelist: WhitelistFile? = nil

    // if we're running with WHITELIST_PLUGINS=1
    private var whitelistPlugins: Bool {
        return ProcessInfo.processInfo.environment["WHITELIST_PLUGINS"] == "1"
    }

    /// Creates a new instance of `FileBasedPluginWhitelist`.
    /// - Parameters:
    ///  - filePath: Optional. The path to the whitelist file.
    public init(filePath: String? = nil) {
        if let filePath = filePath {
            whitelistPath = filePath
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: whitelistPath))
            whitelist = try JSONDecoder().decode(WhitelistFile.self, from: data)
        } catch {
            fatalError("Failed to load the whitelist file. Error: \(error)")
        }
    }

    public func canOpenPlugin(withHash hash: String) -> Bool {
        if whitelistPlugins {
            return true
        }

        return whitelist?.plugins.contains { $0.md5 == hash } ?? false
    }

    public func acceptPlugin(_ plugin: LoadedPluginBuilder) -> Bool {
        if whitelistPlugins {
            appendPlugin(plugin)
            return true
        }

        return whitelist?.plugins.contains { $0.name == plugin.name && $0.version == plugin.version && $0.author == plugin.author } ?? false
    }

    private func appendPlugin(_ plugin: LoadedPluginBuilder) {
        let pluginData = WhitelistedPluginData(name: plugin.name!, version: plugin.version!, author: plugin.author!, md5: plugin.md5)
        saveFile(whitelist!.plugins + [pluginData])
    }

    private func saveFile(_ whitelist: [WhitelistedPluginData]) {
        do {
            let data = try JSONEncoder().encode(whitelist)
            try data.write(to: URL(fileURLWithPath: whitelistPath))
        } catch {
            fatalError("Failed to save the whitelist file. Error: \(error)")
        }
    }
}
