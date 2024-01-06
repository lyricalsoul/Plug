import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

/// Error thrown when a macro expansion fails.
public enum MacroExpansionError: CustomStringConvertible, Error {
    /// The macro expansion was not applied to a struct declaration.
    case notStructDecl
    /// The struct declaration does not conform to `PluginInterface`.
    case doesNotConformToProtocol
    /// The macro was called with an invalid number of arguments (only 0 or 1 arguments are allowed). The argument must also be an identifier.
    case invalidArgumentCount
    /// The macro was called with an invalid argument type. The argument must be an identifier.
    case invalidArgumentType(gotType: String)

    public var description: String {
        switch self {
        case .notStructDecl:
            return "@Plugin can only be applied to a struct declaration."
        case .doesNotConformToProtocol:
            return "@Plugin can only be applied to a struct declaration that conforms to PluginInterface."
        case .invalidArgumentCount:
            return "@Plugin can only be called with 0 or 1 arguments. The argument must also be an identifier."
        case .invalidArgumentType(let gotType):
            return "@Plugin can only be called with an identifier as the argument. Got \(gotType)."
        }
    }
}

/// Implementation of the `@Plugin` peer macro, which takes a struct declaration
/// and generates a `PluginBuilder` class and a `createPlugin` function.
/// The `PluginBuilder` class is used to initialize the `PluginInterface` struct. It is also used for communication between the plugin and the application.
/// The `createPlugin` function is used to create an instance of the `PluginBuilder` class, and is the entrypoint of the plugin.
/// The macro also adds a `init(_ builder: PluginBuilder)` function to the targeted struct. This function is used to initialize the plugin with the builder.
/// It also adds a `send(name: String, data: Any?)` function to the struct that sends events to the application.
/// Optionally, the macro can be called with a parameter. This will replace the default `ExportedPluginBuilder` class with the specified class.
/// Note that the default builder WILL NOT be generated if a custom builder is specified. Make sure to implement the `PluginBuilder` protocol in your custom builder.
/// The `createPlugin` will still be generated, though.
/// Example (without custom builder):
/// ```
/// @Plugin
/// struct MyPlugin: PluginInterface {
///     ...
/// }
/// ```
/// Example (with custom builder):
/// ```
/// @Plugin(MyPluginBuilder)
/// struct MyPlugin: PluginInterface {
///     ...
/// }
/// ```
public struct PluginBuilderMacro: PeerMacro, MemberMacro {
    // PeerMacro impl
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let builderName = try getFirstArgument(node: node, in: context) {
            // return just the createPlugin function
            return [DeclSyntax(stringLiteral: """
            @_cdecl("createPlugin")
            func createPlugin() -> UnsafeMutableRawPointer {
                return Unmanaged.passRetained(\(builderName)()).toOpaque()
            }
            """)]
        }

        let pluginName = try precheck(node: node, declaration: declaration, in: context)
        return [DeclSyntax(stringLiteral: """
        final class ExportedPluginBuilder : PluginBuilder {
            override func build() {
                self.storePlugin(\(pluginName)(self))
            }
        }

        @_cdecl("createPlugin")
        func createPlugin() -> UnsafeMutableRawPointer {
            return Unmanaged.passRetained(ExportedPluginBuilder()).toOpaque()
        }
        """)]
    }

    // MemberMacro impl
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // check if there's a custom builder. if so, get its name. default to ExportedPluginBuilder
        let builderName = try getFirstArgument(node: node, in: context) ?? "ExportedPluginBuilder"
        // get the struct declaration
        let decl = declaration.as(StructDeclSyntax.self)!
        // get the struct name
        let pluginName = decl.name.text.trimmingCharacters(in: .whitespaces)

        return [DeclSyntax(stringLiteral: """
        typealias Builder = \(builderName)
        var name = "\(pluginName)"

        init (_ builder: Builder) {
            self.builder = builder
        }

        func send(name: String, data: Any?) -> Void {
            builder!.send(name: name, data: data)
        }

        unowned var builder: Builder? = nil
        """)]
    }
}


func precheck(
    node: AttributeSyntax,
    declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
) throws -> String {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
        throw MacroExpansionError.notStructDecl
    }

    guard structDecl.inheritanceClause?.inheritedTypes.contains(where: {
        $0.type.as(IdentifierTypeSyntax.self)?.name.text == "PluginInterface"
    }) ?? false else {
        throw MacroExpansionError.doesNotConformToProtocol
    }

    // trim ending space on the struct declaration name (if the struct decl has a space between the name and the :, the name will have a trailing space)
    // is this supposed to happen?
    let pluginName = structDecl.name.text.trimmingCharacters(in: .whitespaces)

    return pluginName
}

func getFirstArgument(
    node: AttributeSyntax,
    in context: some MacroExpansionContext
) throws -> String? {
    switch node.arguments {
        case .argumentList(let args):
            if let arg = args.first?.expression.description.trimmingCharacters(in: .whitespaces) {
                return arg
            } else {
                // invalid argument type
                throw MacroExpansionError.invalidArgumentType(gotType: args.first!.expression.description)
            }
        case _:
            return nil
    }
}