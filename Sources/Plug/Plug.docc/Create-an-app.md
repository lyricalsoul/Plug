# Creating an app

This tutorial will walk you through creating a simple app that uses `Plug` to load and create plugins.

## Create a new project
> Note: This tutorial does not cover the process on macOS, but it shouldn't be much different.

First things first, let's create a new project. We'll be using the Swift Package Manager for this. Create a new folder for your project and run the following commands:

```bash
mkdir MyApp
cd MyApp
swift package init --type executable
```

## Add the Plug dependency
Next, add `Plug` as a dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/lyricalsoul/Plug.git", from: "0.1.0")
```

Then add `Plug` as a dependency to your target:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "Plug", package: "plug")
])
```

## Set up the app
Now that we have a project, we can start writing some code. What we'll be going is pretty simple: we'll create a `PluginManager` instance and load a plugin with it. This class is the basis for all plugin management in `Plug`. It handles loading plugins, creating instances of them, and sending events to them.

```swift
let manager = PluginManager()
try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin") { plugin in
    plugin.on(name: "pong") { (text: String) in
        print("Received pong event from plugin with text: \(text)")
    }
}

await manager.send(event: "ping", data: "hello world", to: { $0.name == "ExamplePlugin" })
```

Let's break this down a bit. 

- First, we create a `PluginManager` instance. This is the class that handles the plugin management.
- Next, we load a plugin. This is done using the `loadPlugin(pathWithoutExtension:closure:)` method. The method takes a path to our plugin, a dynamic library, and a closure that will be called when the plugin is loaded. The closure takes a `LoadedPluginBuilder` instance as its only argument. This instance is a wrapper around the plugin interface. It allows us to listen to events more conveniently.
> Note: We used the `loadPlugin(pathWithoutExtension:closure:)` method here, but there's also `loadPlugin(path:closure:)`. The former method doesn't require you to specify the extension of the plugin (recommended, since it ensures your code is cross-platform without having to edit anything), while the latter method does not try to guess the extension and requires you to specify it yourself.
> Also note the `.build/debug/libExamplePlugin` path. The path to the plugin is relative to root of the project if you're using the Swift Package Manager, but it's relative to the executable if you're running the executable directly.

- Next, we send an event to the plugin. This is done using the `send(event:data:to:)` method. This method takes the name of the event, the data to send, and a closure that will be used to determine which plugins to send the event to. This closure takes a `PluginDetails` instance as its only argument. This instance contains information about the plugin, such as its name and version. In this case, we're sending the event to the plugin with the name "ExamplePlugin".

## Create the plugin
Now that we have an app, we need a plugin to load. For simplicity's sake, we'll put the plugin in the same project as the app. Create a new folder called `ExamplePlugin` on the same level as the `Sources` folder. Inside this folder, create a new `Plugin.swift` file with the following contents (and don't forget to import `Plug`!):

```swift
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

Again, let's dissect this a bit.

- First, we apply the `@Plugin` macro to our plugin structure. This macro does a few things:
    - It adds missing methods so that our plugin conforms to the `PluginInterface` protocol, such as the `name` property, which is the name of the struct and is used to identify the plugin. It also adds the `send(name:data:)` method, the `builder` property, etc.
    - It adds the `ExportedPluginBuilder` class to the file. This class is the interface between the plugin and the host application. It controls the event system, manages the plugin's lifecycle, frees memory when needed (reloading). It inherits from the `PluginBuilder` class.
    - It adds the `createPlugin()` method to the file. This method is what allows the host application to create an instance of the plugin. It returns an instance of the `ExportedPluginBuilder` class.

- Next, we actually create the plugin. We do this by creating a struct that conforms to the `PluginInterface` protocol. This protocol defines the basic requirements for a plugin, such as the name, version, and author. In our implementation, we have 2 methods: `on(event:)` and `on(event:data:)`. The first method is called when the plugin is loaded or unloaded. The second method is called when an event is sent to the plugin. In this case, we're sending the "pong" event back to the host application with the same data that was sent to us.

## Add the plugin to Package.swift

Now that we have a plugin, we need to add it to our `Package.swift` file. This is done by adding a new target to the `targets` array:

```swift
.target(name: "ExamplePlugin", dependencies: [
    .product(name: "Plug", package: "plug")
])
```

We also need to add the plugin to the `products` array:

```swift
.product(name: "ExamplePlugin", type: .dynamic, targets: ["ExamplePlugin"])
```

## Build and run the app

We have everything we need to run the app. Let's do that now:


```bash
swift run
```

If everything went well, you should see the following output:

```
Received pong event from plugin with text: hello world
```

You are ready to go now! You can use this as a starting point for your own projects. Have fun!