/// First-party benchmark scenarios shipped with the benchmark plugin.
///
/// Issue #1149 (kill list — fix list): `zfa benchmark list/run` used to be
/// empty ("No benchmark scenarios registered.") because the plugin shipped
/// the framework but no scenarios. These scenarios exercise real zuraffa
/// utility work through public APIs only (FR-015: scenarios depend on the
/// contract surface, never on a plugin's internals), are pure-Dart
/// (FR-012) and use deterministic in-memory inputs so a run is
/// reproducible.
library;

import 'package:code_builder/code_builder.dart';

import '../../core/benchmark/benchmark_contract.dart';
import '../../core/builder/shared/spec_library.dart';
import '../../core/benchmark/benchmark_result.dart';
import '../../utils/string_utils.dart';
import 'scenario_provider.dart';

/// A fixed corpus of entity-shaped names — deterministic input for the
/// string-transform scenarios (no RNG, no I/O, no wall-clock dependence).
const List<String> kFirstPartyEntityNameCorpus = [
  'Product',
  'UserProfile',
  'OrderLineItem',
  'InvoicePaymentStatus',
  'AuditLogEntry',
  'CustomerAddressBook',
  'WarehouseStockLevel',
  'PaymentMethodToken',
  'ShipmentTrackingEvent',
  'ProductCategoryNode',
];

/// Measures the casing utilities every generator leans on
/// (`StringUtils.camelToSnake`, `convertToPascalCase`, `pascalToCamel`).
class StringUtilsCasingScenario extends BenchmarkScenario {
  const StringUtilsCasingScenario();

  @override
  String get id => 'string-utils-casing';

  @override
  String get name => 'StringUtils casing transforms';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'camelToSnake / convertToPascalCase / pascalToCamel over a fixed '
      'entity-name corpus — the hot path of every code generator.';

  @override
  List<String> get tags => const ['utils', 'string', 'first-party'];

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    final iterations = _positiveInt(config['iterations'], defaultValue: 2000);
    final operations = <String, int>{};
    final stopwatch = Stopwatch()..start();
    var sink = 0;
    for (var i = 0; i < iterations; i++) {
      for (final name in kFirstPartyEntityNameCorpus) {
        final snake = StringUtils.camelToSnake(name);
        final pascal = StringUtils.convertToPascalCase(snake);
        final camel = StringUtils.pascalToCamel(pascal);
        // Deterministic checksum: guards against the optimizer eliding the
        // work, and is reported as a metric for cross-run comparison.
        sink = (sink + snake.length + pascal.length + camel.length) % 65521;
      }
    }
    stopwatch.stop();
    operations['operations'] =
        iterations * kFirstPartyEntityNameCorpus.length * 3;
    operations['checksum'] = sink;
    operations['micros_elapsed'] = stopwatch.elapsedMicroseconds;
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: operations,
      thresholdViolations: const [],
      duration: stopwatch.elapsed,
      timestamp: DateTime.now().toUtc(),
    );
  }
}

/// Measures `SpecLibrary.emitSpec` — the shared emission seam behind the
/// repository / usecase / graphql builders.
class SpecLibraryEmitScenario extends BenchmarkScenario {
  const SpecLibraryEmitScenario();

  @override
  String get id => 'spec-library-field-emit';

  @override
  String get name => 'SpecLibrary field emission';

  @override
  String get version => '1.0.0';

  @override
  String get description =>
      'code_builder Field construction + SpecLibrary.emitSpec over the '
      'entity-name corpus — the shared seam of the file generators.';

  @override
  List<String> get tags => const ['codegen', 'spec-library', 'first-party'];

  @override
  Future<BenchmarkResult> run(Map<String, dynamic> config) async {
    final iterations = _positiveInt(config['iterations'], defaultValue: 500);
    const specLibrary = SpecLibrary();
    final stopwatch = Stopwatch()..start();
    var sink = 0;
    for (var i = 0; i < iterations; i++) {
      for (final name in kFirstPartyEntityNameCorpus) {
        final field = Field(
          (f) => f
            ..name = 'const ${StringUtils.pascalToCamel(name)}Value'
            ..type = refer('String')
            ..modifier = FieldModifier.constant
            ..assignment = Code("'${name.toLowerCase()}'"),
        );
        final emitted = specLibrary.emitSpec(field);
        sink = (sink + emitted.length) % 65521;
      }
    }
    stopwatch.stop();
    return BenchmarkResult(
      scenarioId: id,
      scenarioName: name,
      scenarioVersion: version,
      status: BenchmarkStatus.passed,
      metrics: {
        'operations': iterations * kFirstPartyEntityNameCorpus.length,
        'checksum': sink,
        'micros_elapsed': stopwatch.elapsedMicroseconds,
      },
      thresholdViolations: const [],
      duration: stopwatch.elapsed,
      timestamp: DateTime.now().toUtc(),
    );
  }
}

/// Positive-int coercion for scenario configuration: bad config values are
/// rejected loudly (FormatException) instead of silently clamped.
int _positiveInt(dynamic value, {required int defaultValue}) {
  if (value == null) return defaultValue;
  if (value is int) {
    if (value <= 0) {
      throw FormatException('iterations must be a positive int, got $value');
    }
    return value;
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null || parsed <= 0) {
    throw FormatException(
      'iterations must be a positive int, got "${value.toString()}"',
    );
  }
  return parsed;
}

/// Ships the plugin's own scenarios; registered by default in
/// [BenchmarkPlugin]'s constructor so `zfa benchmark list` is never empty.
class FirstPartyBenchmarkProvider implements BenchmarkScenarioProvider {
  const FirstPartyBenchmarkProvider();

  @override
  List<BenchmarkContract> provideScenarios() => const [
    StringUtilsCasingScenario(),
    SpecLibraryEmitScenario(),
  ];
}
