import 'package:zuraffa/zuraffa.dart';

/// Configuration for mapping GraphQL union error variants to
/// Zuraffa's [AppFailure] taxonomy.
///
/// ```json
/// // .zfa.json
/// {
///   "graphql": {
///     "errorMapping": {
///       "global": {
///         "InsufficientStockError": "business",
///         "NoActiveOrderError": "session",
///         "*Error": "unknown"
///       },
///       "perOperation": {
///         "addItemToOrder": {
///           "InsufficientStockError": "business",
///           "NegativeQuantityError": "validation"
///         }
///       }
///     }
///   }
/// }
/// ```
///
/// A variant is treated as an error unless its category is `success`.
/// Unmapped variants whose name ends in `*Error` fall back to the wildcard
/// `*Error` category (or `unknown`); every other unmapped variant is a
/// success variant.
class ErrorMappingConfig {
  ErrorMappingConfig({
    this.globalMappings = const {},
    this.perOperationMappings = const {},
  });

  /// Global error code → AppFailure category mapping.
  /// Keys are GraphQL type names (e.g. `InsufficientStockError`).
  /// Values are failure categories: `success`, `business`, `session`,
  /// `validation`, `network`, `unknown`.
  final Map<String, String> globalMappings;

  /// Per-operation override mappings.
  /// Outer key is the GraphQL field name (e.g. `addItemToOrder`).
  final Map<String, Map<String, String>> perOperationMappings;

  /// Parse from `.zfa.json` (or any JSON with a `graphql.errorMapping`
  /// section).
  factory ErrorMappingConfig.fromJson(Map<String, dynamic> json) {
    final graphql = json['graphql'] as Map<String, dynamic>? ?? {};
    final errorMapping = graphql['errorMapping'] as Map<String, dynamic>? ?? {};

    final global = (errorMapping['global'] as Map<String, dynamic>? ?? {})
        .cast<String, String>();

    final perOp = <String, Map<String, String>>{};
    final perOpRaw =
        errorMapping['perOperation'] as Map<String, dynamic>? ?? {};
    for (final entry in perOpRaw.entries) {
      perOp[entry.key] = (entry.value as Map<String, dynamic>)
          .cast<String, String>();
    }

    return ErrorMappingConfig(
      globalMappings: global,
      perOperationMappings: perOp,
    );
  }

  /// Get the failure category for [errorTypeName] in [operationName].
  ///
  /// Resolution order:
  /// 1. Per-operation override (if [operationName] is provided)
  /// 2. Global mapping
  /// 3. Wildcard `*Error` pattern (only for names ending in `Error`)
  /// 4. `unknown` for error-suffixed names, `success` otherwise
  String getCategory(String errorTypeName, {String? operationName}) {
    // Per-operation override
    if (operationName != null) {
      final opMap = perOperationMappings[operationName];
      if (opMap != null) {
        final category = opMap[errorTypeName];
        if (category != null) return category;
      }
    }

    // Global mapping
    final globalCategory = globalMappings[errorTypeName];
    if (globalCategory != null) return globalCategory;

    // Wildcard pattern: *Error → wildcard category, or unknown by default
    if (errorTypeName.endsWith('Error')) {
      return globalMappings['*Error'] ?? 'unknown';
    }

    // Unmapped, non-error-suffixed variants are success variants.
    return 'success';
  }

  /// Whether [typeName] is mapped as an error (any category other than
  /// `success`).
  bool isError(String typeName, {String? operationName}) {
    final category = getCategory(typeName, operationName: operationName);
    return category != 'success';
  }

  /// Build an [AppFailure] from [errorTypeName] with optional [message].
  ///
  /// The GraphQL error type name is preserved as the failure's [AppFailure.code]
  /// so callers can distinguish e.g. `InsufficientStockError` from
  /// `NegativeQuantityError`.
  AppFailure toFailure(
    String errorTypeName, {
    String? message,
    String? operationName,
  }) {
    final category = getCategory(errorTypeName, operationName: operationName);
    final msg = message ?? errorTypeName;

    return switch (category) {
      'business' || 'validation' => ValidationFailure(msg, code: errorTypeName),
      'session' => UnauthorizedFailure(msg, code: errorTypeName),
      'network' => NetworkFailure(msg, code: errorTypeName),
      _ => UnknownFailure(msg, code: errorTypeName),
    };
  }
}
