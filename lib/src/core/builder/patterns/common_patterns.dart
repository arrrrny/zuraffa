import 'package:code_builder/code_builder.dart';

import '../../../core/constants/known_types.dart';
import '../../../models/generator_config.dart';
import '../../../utils/string_utils.dart';

class CommonPatterns {
  static List<String> entityImports(
    List<String?> types,
    GeneratorConfig config, {
    int depth = 1,
  }) {
    final entities = <String>{};
    for (final type in types) {
      if (type == null) continue;
      final baseTypes = _extractBaseTypes(type);
      for (final baseType in baseTypes) {
        if (!KnownTypes.isExcluded(baseType)) {
          entities.add(baseType);
        }
      }
    }

    final domainSnake = config.domain != null
        ? StringUtils.camelToSnake(config.domain!)
        : null;
    final prefix = List.generate(depth, (_) => '..').join('/');

    return entities.map((entity) {
      final entitySnake = StringUtils.camelToSnake(entity);
      if (domainSnake != null && entitySnake.contains(domainSnake)) {
        return '$prefix/entities/$domainSnake/$entitySnake.dart';
      }
      return '$prefix/entities/$entitySnake/$entitySnake.dart';
    }).toList();
  }

  static List<String> _extractBaseTypes(String type) {
    // 1. Remove nullable marker
    final cleanType = type.replaceAll('?', '').trim();
    if (cleanType.isEmpty || cleanType == 'void') return [];

    final results = <String>[];

    // 2. Handle generic types like Stream<BarcodeListing?> or List<User>
    final genericMatch = RegExp(r'^(\w+)<(.+)>$').firstMatch(cleanType);
    if (genericMatch != null) {
      final outerType = genericMatch.group(1);
      if (outerType != null) {
        results.add(outerType);
      }
      final innerTypes = genericMatch.group(2);
      if (innerTypes != null) {
        // Split by comma but respect nested generics
        final parts = _splitByComma(innerTypes);
        for (final part in parts) {
          results.addAll(_extractBaseTypes(part));
        }
      }
    } else {
      // 3. Simple type (e.g., Barcode, BarcodeListing)
      results.add(cleanType);
    }

    return results;
  }

  static List<String> _splitByComma(String input) {
    final results = <String>[];
    var bracketCount = 0;
    var current = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '<') bracketCount++;
      if (char == '>') bracketCount--;
      if (char == ',' && bracketCount == 0) {
        results.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    if (current.isNotEmpty) {
      results.add(current.toString().trim());
    }
    return results;
  }

  static Field finalField(String name, String type, {bool isLate = false}) {
    return Field(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..modifier = FieldModifier.final$
        ..late = isLate,
    );
  }

  static Parameter requiredNamedParam(String name, String type) {
    return Parameter(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..named = true
        ..required = true,
    );
  }

  static Parameter optionalNamedParam(
    String name,
    String type, {
    Code? defaultTo,
  }) {
    return Parameter(
      (b) => b
        ..name = name
        ..type = refer(type)
        ..named = true
        ..defaultTo = defaultTo,
    );
  }

  static Constructor constructor({
    String? name,
    bool isConst = false,
    Iterable<Parameter> parameters = const [],
    Iterable<Code> initializers = const [],
    Code? body,
  }) {
    return Constructor((b) {
      b
        ..name = name
        ..constant = isConst
        ..initializers.addAll(initializers)
        ..body = body;
      for (final parameter in parameters) {
        if (parameter.named) {
          b.optionalParameters.add(parameter);
        } else {
          b.requiredParameters.add(parameter);
        }
      }
    });
  }

  static Method abstractMethod({
    required String name,
    required String returnType,
    Iterable<Parameter> parameters = const [],
  }) {
    return Method((b) {
      b
        ..name = name
        ..returns = refer(returnType);
      for (final parameter in parameters) {
        if (parameter.named) {
          b.optionalParameters.add(parameter);
        } else {
          b.requiredParameters.add(parameter);
        }
      }
    });
  }
}
