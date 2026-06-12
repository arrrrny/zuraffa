import '../utils/string_utils.dart';

/// Resolves use case names to entity names and builds related identifiers.
class UseCaseNameResolver {
  /// Known CRUD and common verb prefixes that can appear at the start
  /// of a use case class name.
  static const List<String> knownVerbPrefixes = [
    'Get',
    'Create',
    'Update',
    'Delete',
    'Toggle',
    'Watch',
    'List',
    'Resolve',
    'Search',
    'Fetch',
    'Submit',
    'Validate',
    'Process',
    'Generate',
    'Import',
    'Export',
    'Calculate',
    'Find',
    'Count',
    'Send',
    'Remove',
    'Archive',
  ];

  /// Extracts the entity name from a use case name.
  ///
  /// Examples:
  /// - `GetProduct` → `Product`
  /// - `CreateProductUseCase` → `Product`
  /// - `ResolveInAppLink` → `InAppLink`
  /// - `CustomAction` → `CustomAction`
  static String extractEntityName(String useCaseName) {
    var name = useCaseName;

    // Strip 'UseCase' suffix if present
    if (name.endsWith('UseCase')) {
      name = name.substring(0, name.length - 'UseCase'.length);
    }

    // Strip known verb prefix if present
    for (final prefix in knownVerbPrefixes) {
      if (name.startsWith(prefix) && name.length > prefix.length) {
        // Ensure the next character is uppercase (word boundary)
        final nextChar = name[prefix.length];
        if (nextChar.toUpperCase() == nextChar) {
          return name.substring(prefix.length);
        }
      }
    }

    // No prefix matched, return as-is
    return name;
  }

  /// Extracts the verb prefix from a use case name.
  ///
  /// Examples:
  /// - `GetProduct` → `Get`
  /// - `CreateProductUseCase` → `Create`
  /// - `CustomAction` → `null`
  static String? extractVerbPrefix(String useCaseName) {
    var name = useCaseName;

    // Strip 'UseCase' suffix if present
    if (name.endsWith('UseCase')) {
      name = name.substring(0, name.length - 'UseCase'.length);
    }

    for (final prefix in knownVerbPrefixes) {
      if (name.startsWith(prefix) && name.length > prefix.length) {
        final nextChar = name[prefix.length];
        if (nextChar.toUpperCase() == nextChar) {
          return prefix;
        }
      }
    }

    return null;
  }

  /// Builds the field name (camelCase, prefixed with underscore) from an entity name.
  ///
  /// Example: `Product` → `_product`
  static String buildFieldName(String verbPrefix, String entityName) {
    return '_${StringUtils.pascalToCamel(verbPrefix + entityName)}';
  }

  /// Builds the use case class name from a verb prefix and entity name.
  ///
  /// Example: `Get`, `Product` → `GetProductUseCase`
  static String buildUseCaseClassName(String verbPrefix, String entityName) {
    return '$verbPrefix${entityName}UseCase';
  }

  /// Extracts the use case short name (without UseCase suffix).
  ///
  /// Example: `GetProductUseCase` → `GetProduct`
  static String extractShortName(String fullClassName) {
    if (fullClassName.endsWith('UseCase')) {
      return fullClassName.substring(
        0,
        fullClassName.length - 'UseCase'.length,
      );
    }
    return fullClassName;
  }

  /// Extracts the verb prefix from a use case name and returns both prefix
  /// and entity name.
  ///
  /// Returns a record with `verbPrefix` and `entityName`.
  static ({String? verbPrefix, String entityName}) resolve(String useCaseName) {
    final verbPrefix = extractVerbPrefix(useCaseName);
    final entityName = extractEntityName(useCaseName);
    return (verbPrefix: verbPrefix, entityName: entityName);
  }
}
