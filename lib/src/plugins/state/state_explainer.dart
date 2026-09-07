/// Spec 1126 (order 3) — `--explain` on the state create path.
///
/// Builds the plan `zfa state create <Entity> --explain` prints INSTEAD
/// of generating: which state class is output (`<Entity>State`), the
/// output file, the emission mode, which state members the builder
/// generates (copyWith, the isLoading getter, hasError, ==, hashCode,
/// toString — the entity-mode surface), and which derivation methods
/// are included — each requested method mapped to the `is<Continuous>`
/// state member it generates, via the same `StringUtils.toContinuous`
/// derivation `_boolFieldsForMethods` feeds, so the explain block
/// cannot drift from the emission.
library;

import 'package:path/path.dart' as p;

import '../../models/generator_config.dart';
import '../../utils/string_utils.dart';

/// The state `--explain` plan builder. Stateless; instantiate freely.
class StateExplainer {
  const StateExplainer();

  /// The machine explain payload (also the source of the prose block,
  /// so both surfaces show the same facts).
  Map<String, dynamic> explain({
    required GeneratorConfig config,
    String? projectRoot,
  }) {
    final entityName = config.name;
    final stateClass = '${entityName}State';
    final snake = config.nameSnake;
    final domainSnake = config.effectiveDomain;
    final file = _posixJoin([
      config.outputDir,
      'presentation',
      'pages',
      domainSnake,
      '${snake}_state.dart',
    ]);

    final derivation = <Map<String, String>>[
      for (final method in config.methods)
        {
          'method': method,
          'stateMember': 'is${StringUtils.toContinuous(method)}',
        },
    ];

    final members = <String>[
      'copyWith',
      if (config.methods.isNotEmpty) 'isLoading',
      'hasError',
      '==',
      'hashCode',
      'toString',
    ];

    final fields = <Map<String, String>>[
      {'name': 'error', 'type': 'AppFailure?'},
      if (_needsEntityField(config))
        {'name': config.nameCamel, 'type': entityName},
      if (_needsEntityListField(config)) ...[
        {'name': '${config.nameCamel}List', 'type': 'List<$entityName>'},
        {'name': 'offset', 'type': 'int'},
        {'name': 'limit', 'type': 'int'},
        {'name': 'hasMore', 'type': 'bool'},
      ],
      for (final d in derivation) {'name': d['stateMember']!, 'type': 'bool'},
    ];

    return {
      'stateClass': stateClass,
      'file': file,
      'mode': _modeOf(config),
      'flavorNote': _flavorNote(),
      'methods': config.methods,
      'derivation': derivation,
      'members': members,
      'fields': fields,
      'receipt':
          '.zfa/receipts/state-${StringUtils.camelToSnake(entityName)}.json',
    };
  }

  /// The human-readable block (prose mode).
  String format(Map<String, dynamic> plan) {
    final out = StringBuffer()
      ..writeln('State plan for `${plan['stateClass']}`')
      ..writeln()
      ..writeln('  state class : ${plan['stateClass']}')
      ..writeln('  output file : ${plan['file']}')
      ..writeln('  mode        : ${plan['mode']}')
      ..writeln();

    out
      ..writeln('Generated state members:')
      ..writeln('  - copyWith() — immutable field patching')
      ..writeln('  - isLoading — whether any derivation is in progress')
      ..writeln('  - hasError — whether error is set')
      ..writeln('  - == / hashCode / toString — value identity')
      ..writeln();

    final derivation = plan['derivation'] as List<Map<String, String>>;
    out.writeln(
      'Derivation methods (${(plan['methods'] as List).join(', ')}):',
    );
    if (derivation.isEmpty) {
      out.writeln(
        '  (none — no-entity/custom mode: pass --methods get,create,... '
        'to derive members)',
      );
    } else {
      for (final d in derivation) {
        out.writeln(
          '  - ${d['method']} → ${d['stateMember']} (each method '
          'generates a state_${d['method']} member: the '
          'is-continuous flag the builder derives)',
        );
      }
    }
    out.writeln();

    out.writeln('Fields:');
    for (final f in (plan['fields'] as List<Map<String, String>>)) {
      out.writeln('  - ${f['name']}: ${f['type']}');
    }
    out
      ..writeln()
      ..writeln('Receipt: ${plan['receipt']}')
      ..writeln(plan['flavorNote']);
    return out.toString().trimRight();
  }

  String _modeOf(GeneratorConfig config) {
    if (config.isOrchestrator) return 'orchestrator';
    if (config.isCustomUseCase) return 'custom';
    return 'entity';
  }

  String _flavorNote() =>
      'The core import follows the target project flavor '
      '(zuraffa core on pure-Dart, zuraffa_flutter on Flutter) — #512.';

  String _posixJoin(List<String> parts) {
    final joined = p.joinAll(parts.where((part) => part.isNotEmpty));
    return joined.replaceAll('\\', '/');
  }

  // The same derivation the builder's _resolveEntityFieldNeeds feeds —
  // mirrored here so explain reports what WOULD be emitted. Kept in
  // sync by the make-drift gate.
  bool _needsEntityField(GeneratorConfig config) =>
      !config.noEntity &&
      (config.generateState ||
          config.methods.any(
            (m) => [
              'get',
              'watch',
              'create',
              'update',
              'toggle',
              'delete',
            ].contains(m),
          ));

  bool _needsEntityListField(GeneratorConfig config) =>
      !config.noEntity &&
      config.methods.any((m) => ['getList', 'watchList'].contains(m));
}
