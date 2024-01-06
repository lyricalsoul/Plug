import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PlugMacros : CompilerPlugin {
    var providingMacros: [Macro.Type] = [
        PluginBuilderMacro.self
    ]
}