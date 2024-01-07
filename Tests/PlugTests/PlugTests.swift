import XCTest
import MacroTesting
import Crypto
@testable import Plug
@testable import PlugMacros

#if os(macOS)
let extensionName = "dylib"
#elseif os(Linux)
let extensionName = "so"
#elseif os(Windows)
let extensionName = "dll"
#endif

final class PlugMacroTests: XCTestCase {
    override func invokeTest() {
        withMacroTesting(
            macros: ["Plugin": PluginBuilderMacro.self]
        ) {
            super.invokeTest()
        }
    }

    func testPluginBuilderGeneration() throws {
        assertMacro {
            """
            @Plugin
            struct ExamplePlugin : PluginInterface {
            }
            """
        } expansion: {
            """
            struct ExamplePlugin : PluginInterface {

                typealias Builder = ExportedPluginBuilder
                var name = "ExamplePlugin"

                init (_ builder: Builder) {
                    self.builder = builder
                }

                func send(name: String, data: Any?) -> Void {
                    builder!.send(name: name, data: data)
                }

                unowned var builder: Builder? = nil
            }

            final class ExportedPluginBuilder : PluginBuilder {
                override func build() {
                    self.storePlugin(ExamplePlugin(self))
                }
            }

            @_cdecl("createPlugin")
            func createPlugin() -> UnsafeMutableRawPointer {
                return Unmanaged.passRetained(ExportedPluginBuilder()).toOpaque()
            }
            """
        }
    }
    
    func testNoBuilderGeneration() throws {
        assertMacro {
            """
            @Plugin(Custom)
            struct ExamplePlugin : PluginInterface {
            }
            """
        } expansion: {
            """
            struct ExamplePlugin : PluginInterface {

                typealias Builder = Custom
                var name = "ExamplePlugin"

                init (_ builder: Builder) {
                    self.builder = builder
                }

                func send(name: String, data: Any?) -> Void {
                    builder!.send(name: name, data: data)
                }

                unowned var builder: Builder? = nil
            }

            @_cdecl("createPlugin")
            func createPlugin() -> UnsafeMutableRawPointer {
                return Unmanaged.passRetained(Custom()).toOpaque()
            }
            """
        }
    }
}

final class PlugManagerTests : XCTestCase {
    func testLoadPlugin() async throws {
        let manager = PluginManager()
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
    }

    func testPluginInformation() async throws {
        let manager = PluginManager()
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin") { plugin in
            XCTAssertEqual(plugin.name, "ExamplePlugin")
            XCTAssertEqual(plugin.version, "1.0.0")
            XCTAssertEqual(plugin.author, "John Doe")
        }
    }

    func testPluginEvent() async throws {
        let manager = PluginManager()
        let expectation = XCTestExpectation(description: "Plugin event received")
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin") { plugin in
            plugin.on(name: "pong") { (text: String) in
                XCTAssertEqual(text, "hello world")
                expectation.fulfill()
            }
        }

        await manager.send(event: "ping", data: "hello world", to: { $0.name == "ExamplePlugin" })
        await fulfillment(of: [expectation], timeout: 1)
    }

    func testPluginEventWithNoData() async throws {
        let manager = PluginManager()
        let expectation = XCTestExpectation(description: "Plugin event received")
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin") { plugin in
            plugin.on(name: "pong") {
                expectation.fulfill()
            }
        }

        await manager.send(event: "ping", data: nil, to: { $0.name == "ExamplePlugin" })
        await fulfillment(of: [expectation], timeout: 1)
    }

    func testPluginEventWithNoDataAndNoHandler() async throws {
        let manager = PluginManager()
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
        await manager.send(event: "ping", data: nil, to: { $0.name == "ExamplePlugin" })
    }

    func testManagerDoubleLoad() async throws {
        let manager = PluginManager()
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
        await assertThrowsAsyncError(try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")) { error in
            XCTAssertEqual(error as? PluginError, PluginError.alreadyLoaded)
        }
    }

    func testManagerUnload() async throws {
        let manager = PluginManager()
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
        manager.unloadPlugin(where: { $0.name == "ExamplePlugin" })
    }

    func testManagerUnloadAll() async throws {
        let manager = PluginManager()
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
        manager.unloadAllPlugins()
    }

    func testManagerReload() async throws {
        let manager = PluginManager()
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
        let result = try await manager.reloadPlugin(where: { $0.name == "ExamplePlugin" })
        XCTAssertTrue(result)
    }

    func testManagerReloadWithNoPlugin() async throws {
        let manager = PluginManager()
        let result = try await manager.reloadPlugin(where: { $0.name == "ExamplePlugin" })
        XCTAssertFalse(result)
    }

    func testNoMemoryLeakAfterReload() async throws {
        let manager = PluginManager()
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
        weak var builder = manager.findPluginInformation(where: { $0.name == "ExamplePlugin" })!.builder
        manager.unloadPlugin(where: { $0.name == "ExamplePlugin" })
        // test if the builder is deinited
        XCTAssertNil(builder)
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
    }

    func testSimplePluginWhitelistName() async throws {
        let whitelist = SimplePluginWhitelist([
            .allowName("ExamplePlugin")
        ])

        let manager = PluginManager(whitelist: whitelist)
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
    }

    func testSimplePluginWhitelistNameThrows() async throws {
        let whitelist = SimplePluginWhitelist([
            .allowName("ExamplePlugin2")
        ])

        let manager = PluginManager(whitelist: whitelist)
        await assertThrowsAsyncError(try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")) { error in
            XCTAssertEqual(error as? PluginError, PluginError.securityError)
        }
    }

    func testSimplePluginWhitelistMD5() async throws {
        let md5 = try md5OfFile(path: ".build/debug/libExamplePlugin.\(extensionName)")
        
        let whitelist = SimplePluginWhitelist([
            .allowMD5(md5)
        ])

        let manager = PluginManager(whitelist: whitelist)
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
    }

    func testSimplePluginWhitelistMD5Throws() async throws {
        let whitelist = SimplePluginWhitelist([
            .allowMD5("1234567890")
        ])

        let manager = PluginManager(whitelist: whitelist)
        await assertThrowsAsyncError(try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")) { error in
            XCTAssertEqual(error as? PluginError, PluginError.securityError)
        }
    }

    func testFileBasedPluginWhitelistName() async throws {
        let md5 = try md5OfFile(path: ".build/debug/libExamplePlugin.\(extensionName)")
        try createWhitelistFile(md5: md5)

        let whitelist = FileBasedPluginWhitelist(filePath: ".build/debug/plugin-whitelist.json")
        
        let manager = PluginManager(whitelist: whitelist)
        try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")
    }

    func testFileBasedPluginWhitelistNameThrows() async throws {
        try createWhitelistFile(md5: "1234567890")

        let whitelist = FileBasedPluginWhitelist(filePath: ".build/debug/plugin-whitelist.json")

        let manager = PluginManager(whitelist: whitelist)
        await assertThrowsAsyncError(try await manager.loadPlugin(pathWithoutExtension: ".build/debug/libExamplePlugin")) { error in
            XCTAssertEqual(error as? PluginError, PluginError.securityError)
        }
    }
}

/// generate the md5 hash of a file
func md5OfFile(path: String) throws -> String {
    let file = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    let data = file.readDataToEndOfFile()
    file.closeFile()
    return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
}

/// Creates a whitelist file for testing
func createWhitelistFile(md5: String) throws {
    let whitelist = FileBasedPluginWhitelist.WhitelistFile(plugins: [
        .init(name: "ExamplePlugin", version: "1.0.0", author: "John Doe", md5: md5)
    ])
    let data = try JSONEncoder().encode(whitelist)
    try data.write(to: URL(fileURLWithPath: ".build/debug/plugin-whitelist.json"))
}
/// Asserts that an asynchronous expression throws an error.
/// (Intended to function as a drop-in asynchronous version of `XCTAssertThrowsError`.)
/// Taken from https://stackoverflow.com/a/76649847. Thanks, kind stranger ^^
///
/// Example usage:
///
///     await assertThrowsAsyncError(
///         try await sut.function()
///     ) { error in
///         XCTAssertEqual(error as? MyError, MyError.specificError)
///     }
///
/// - Parameters:
///   - expression: An asynchronous expression that can throw an error.
///   - message: An optional description of a failure.
///   - file: The file where the failure occurs.
///     The default is the filename of the test case where you call this function.
///   - line: The line number where the failure occurs.
///     The default is the line number where you call this function.
///   - errorHandler: An optional handler for errors that expression throws.
func assertThrowsAsyncError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        // expected error to be thrown, but it was not
        let customMessage = message()
        if customMessage.isEmpty {
            XCTFail("Asynchronous call did not throw an error.", file: file, line: line)
        } else {
            XCTFail(customMessage, file: file, line: line)
        }
    } catch {
        errorHandler(error)
    }
}