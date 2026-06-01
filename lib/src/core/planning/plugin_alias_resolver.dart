class PluginAliasResolver {
  static const Map<String, List<String>> _aliases = {
    'data': ['repository', 'datasource'],
    'vpc': ['view', 'presenter', 'controller'],
    'full-ui': ['view', 'presenter', 'controller', 'state', 'route'],
    'quality': ['test', 'mock', 'di'],
  };

  const PluginAliasResolver._();

  static bool hasAlias(String id, {Map<String, List<String>>? customAliases}) =>
      _merged(customAliases).containsKey(id);

  static List<String> expandAll(
    Iterable<String> ids, {
    Map<String, List<String>>? customAliases,
  }) {
    final expanded = <String>[];
    final seen = <String>{};
    final aliases = _merged(customAliases);

    void addExpanded(String id) {
      final normalized = id.trim();
      if (normalized.isEmpty) return;

      final aliasTargets = aliases[normalized];
      if (aliasTargets != null) {
        for (final target in aliasTargets) {
          addExpanded(target);
        }
        return;
      }

      if (seen.add(normalized)) {
        expanded.add(normalized);
      }
    }

    for (final id in ids) {
      addExpanded(id);
    }

    return expanded;
  }

  static Map<String, List<String>> _merged(
    Map<String, List<String>>? customAliases,
  ) {
    if (customAliases == null || customAliases.isEmpty) {
      return _aliases;
    }
    return {..._aliases, ...customAliases};
  }
}
