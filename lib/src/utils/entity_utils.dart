import 'zuraffa_barrel_exports.dart';

class EntityUtils {
  /// Extracts entity types from a field type string (e.g. List Product -> [Product])
  static List<String> extractEntityTypes(String fieldType) {
    final types = <String>[];
    var baseType = fieldType.replaceAll('?', '');

    if (baseType.startsWith('List<') && baseType.endsWith('>')) {
      baseType = baseType.substring(5, baseType.length - 1);
    } else if (baseType.startsWith('Map<') && baseType.endsWith('>')) {
      final innerTypes = baseType.substring(4, baseType.length - 1);
      final typeParts = innerTypes.split(',').map((s) => s.trim()).toList();
      if (typeParts.length == 2) {
        baseType = typeParts[1];
      } else {
        return types;
      }
    }

    if (baseType.startsWith('\$')) {
      baseType = baseType.substring(1);
    }

    // #1198 follow-up (spec-1003 finding #7): strip framework param
    // wrappers BEFORE flattening generics. `QueryParams<Product>` used to
    // flatten to the phantom `QueryParamsProduct`, and generated code (mock
    // provider in the service lane, triad lanes) emitted imports for a
    // `query_params_product` entity file that does not exist — caught for
    // real by the template self-hosting loop's compile tier while driving
    // the canonical `zfa make` plugin order. A wrapper is a zuraffa
    // param/contract type, not an entity; the entity is its type argument.
    for (final wrapper in const [
      'QueryParams',
      'ListQueryParams',
      'UpdateParams',
      'DeleteParams',
      'InitializationParams',
      'Params',
      'Filter',
      'Sort',
    ]) {
      if (baseType.startsWith('$wrapper<') && baseType.endsWith('>')) {
        baseType = baseType
            .substring(wrapper.length + 1, baseType.length - 1)
            .trim();
        break;
      }
    }

    baseType = baseType
        .replaceAll('<', '')
        .replaceAll('>', '')
        .split(',')[0]
        .trim();

    if (baseType.isNotEmpty &&
        ![
          'String',
          'int',
          'double',
          'bool',
          'DateTime',
          // `Duration` is a dart:core type (already listed in
          // KnownTypes.dartTypes). Without it here, a field declared as
          // `x:Duration` was treated as a custom entity reference and
          // rejected by EntityTypeValidator (issue #411).
          'Duration',
          'Object',
          'dynamic',
          'void',
          'NoParams',
          'Params',
          'QueryParams',
          'ListQueryParams',
          'UpdateParams',
          'DeleteParams',
          'InitializationParams',
        ].contains(baseType) &&
        baseType[0].toUpperCase() == baseType[0]) {
      types.add(baseType);
    }

    return types;
  }

  /// The entity's own symbols a generated file must hide from the
  /// framework barrel it imports alongside the entity file (issue #942).
  ///
  /// A generated datasource/mock imports the entity file AND
  /// `package:zuraffa/zuraffa.dart` (or `package:zuraffa/mock.dart`)
  /// unprefixed. When the entity's name matches a zuraffa core export
  /// (e.g. an entity named `Credentials` — the framework exports its own
  /// `Credentials` params class), every use of the name in the generated
  /// file is an `ambiguous_import` error and the generated tree does not
  /// compile. The generator knows the entity's own symbol set — the
  /// zorphy concrete class and its `Patch` pair — so the barrel import
  /// carries a `hide` clause for exactly those symbols, and the entity's
  /// own definitions win resolution.
  /// Issue #1176: the hide list is filtered to names the resolved
  /// zuraffa barrel actually exports — hiding a name the barrel never
  /// exports is an `undefined_hidden_name` warning, and `zfa build`'s
  /// analyze gate fails on warnings. Unresolved (no seed) → legacy
  /// unconditional hide.
  static List<String> barrelHideNames(String entityName) =>
      ZuraffaBarrelExports.filter(<String>[entityName, '${entityName}Patch']);
}
