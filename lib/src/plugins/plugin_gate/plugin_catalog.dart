/// The optional-capability catalog (spec 1653-trim-heavy-deps, issue
/// #1661).
///
/// Core carries ONLY the catalog — names, backing packages, and the gate
/// logic. The heavyweight implementations live in the companion packages
/// (`packages/zuraffa_graphql`, `packages/zuraffa_storage`,
/// `packages/zuraffa_observability`), which the developer adds to THEIR
/// project when they enable a capability. One source of truth for the
/// `zfa plugin` listing, the enable action's package guidance, and the
/// gated commands' refusal text.
library;

/// One optional capability and the package that backs it.
class OptionalPlugin {
  const OptionalPlugin({required this.name, required this.package});

  /// The capability id used on the CLI and in `.zfa.json`
  /// `capabilities:`.
  final String name;

  /// The companion package the developer adds to their project.
  final String package;
}

/// The static catalog of optional capabilities.
class PluginCatalog {
  PluginCatalog._();

  /// Every optional capability, in listing order.
  static const List<OptionalPlugin> all = [
    OptionalPlugin(name: 'graphql', package: 'zuraffa_graphql'),
    OptionalPlugin(name: 'storage', package: 'zuraffa_storage'),
    OptionalPlugin(name: 'observability', package: 'zuraffa_observability'),
  ];

  /// The entry for [name], or `null` when the id is not a capability.
  static OptionalPlugin? find(String name) {
    for (final entry in all) {
      if (entry.name == name) return entry;
    }
    return null;
  }
}
