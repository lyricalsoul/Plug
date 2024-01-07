# Using a plugin whitelist

Arbitrary code execution poses a security risk, but there are ways to mitigate it. One of these ways is to use a plugin whitelist.

## Overview

A plugin whitelist is a list of plugins that are allowed to be loaded by the host application. If a plugin is not in the whitelist, it will not be loaded and a `securityError` will be thrown during its loading.

The library offers a `PluginIntegrity` protocol that can be used to implement a structure that will be used to dictate which plugins are allowed to be loaded. This protocol has 2 methods.

The first method is `canOpenPlugin(withHash:)`. This method receives a string with the MD5 hash of the plugin's file. The method should return `true` if the plugin is allowed to be loaded, or `false` if it should not be loaded. If the method returns `false`, the plugin will not be loaded and a `securityError` will be thrown.

The second method is `acceptPlugin(_:)`. This method receives the already loaded `PluginInterfaceBuilder`, which contains all the plugin data, such as its name, its version, its author, etc. This method should return `true` if the plugin is allowed to be loaded, or `false` if it should not be loaded. It it returns `false`, the plugin will be unloaded and a `securityError` will be thrown.

> Note: In order to gather plugin information for the `acceptPlugin(_:)` method, the plugin must be loaded. This means that if you were to have a harmful plugin present, its code would be executed and your application would be compromised. To ensure the integrity of your app, you should use the `canOpenPlugin(withHash:)` method to prevent malicious code from being loaded in the first place.

## Using the default implementations

Plug offers 2 implementations of the `PluginIntegrity` protocol: `SimplePluginWhitelist` and `FileBasedPluginWhitelist`.
- The first one is a basic implementation that allows you to add plugins to the whitelist manually.
- The second one is a more advanced implementation that will automatically add plugins to the whitelist when the `WHITELIST_PLUGINS` environment variable is set to `1`. When the variable is not set, the implementation will look for a file called `plugin_whitelist.json` in the root of the application. If the file exists, it will use the data in it to populate the whitelist. If the file does not exist, the implementation will throw a fatal error indicating that the whitelist file could not be found.

The first implementation is useful for testing purposes, while the second one is more suited for production.

## Using SimplePluginWhitelist

> Attention: This implementation is not meant to be used in production. It is only meant to be used for testing purposes.

To use the `SimplePluginWhitelist` implementation, all you have to do is create an instance of it and pass it to the `PluginManager` instance when you create it:

```swift
let whitelist = SimplePluginWhitelist([
    // this will check the MD5 hash of the plugin file. if it doesn't match and there's an `allow` call which takes a name, the plugin will be loaded anyways so its name can be checked.
    .allowMD5("d41d8cd98f00b204e9800998ecf8427e"),
    // this is unsafe and should not be used in production.
    .allowName("ExamplePlugin")
)

let manager = PluginManager(whitelist: whitelist)
```

## Using FileBasedPluginWhitelist
To use the `FileBasedPluginWhitelist` implementation, all you have to do is create an instance of it and pass it to the `PluginManager` instance when you create it:

```swift
let whitelist = FileBasedPluginWhitelist()

let manager = PluginManager(whitelist: whitelist)
```

Then, run your application with the `WHITELIST_PLUGINS` environment variable set to `1` and load all the plugins you want to whitelist. When you're done, the whitelist file will be created in the root of your application. You can then remove the `WHITELIST_PLUGINS` environment variable and run your app normally.

You can also change the path to the whitelist file by passing a filePath to the `FileBasedPluginWhitelist` initializer:

```swift
let whitelist = FileBasedPluginWhitelist(filePath: "/path/to/whitelist.json")
```

> Note: The whitelist file is not meant to be edited manually. If you want to add or remove plugins from the whitelist, you should do so by loading (or not loading) the plugins with the `WHITELIST_PLUGINS` var.