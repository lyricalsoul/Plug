/// Creates the plugin builder and adds other essential functions to the code.
@attached(peer, names: named(createPlugin), named(ExportedPluginBuilder))
@attached(member, names: named(init), named(send), named(builder), named(Builder), named(name))
public macro Plugin() = #externalMacro(module: "PlugMacros", type: "PluginBuilderMacro")