# ``Plug``

@Metadata {
    @DisplayName("Plug")
}

## Overview

A library for creating painless plugins for Swift applications. 

Just add `@Plugin` to your plugin and use the library's event system to communicate with the host application. Tested on macOS and Linux.

To get started, add the dependency to your `Package.swift` file:

```swift
.package(url: "https://github.com/lyricalsoul/Plug.git", from: "0.1.0")
```

Then add `Plug` as a dependency to your target:

```swift
.product(name: "Plug", package: "plug")
```

> Please note that `Plug` is only compatible with Swift 5.9 and above.

## Topics

### Getting Started

  - <doc:Create-an-app>

### Advanced

- nothing yet!