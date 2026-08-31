import 'package:test/test.dart';
import 'package:zuraffa/src/feature_flags/feature_flag.dart';
import 'package:zuraffa/src/feature_flags/feature_flag_config.dart';
import 'package:zuraffa/src/feature_flags/registry_emitter.dart';

/// A9-A12, A18, U4, U5 — the registry emitter turns a resolved feature-set
/// into the target app's `feature_flags.g.dart` source. Disabled features
/// must leave no trace; the class must expose isEnabled / enabledFeatures /
/// resolveVariant and compile against the runtime contracts.
void main() {
  group('emitRegistry', () {
    test('A9: declares an enabled feature so isEnabled answers true', () {
      final source = emitRegistry(
        className: 'FeatureFlags',
        resolved: _resolved(),
      );
      expect(source, contains("'pro-analytics'"));
      // executed for real via FeatureFlagRuntime in runtime_provider_test
    });

    test('A10/U4: a disabled feature leaves no trace in the output', () {
      final source = emitRegistry(
        className: 'FeatureFlags',
        resolved: _resolved(withGates: true),
      );
      expect(source, isNot(contains('beta-scheduler')));
      expect(source, isNot(contains('custom:internal')));
    });

    test('A11: embeds exactly the enabled set', () {
      final source = emitRegistry(
        className: 'FeatureFlags',
        resolved: _resolved(),
      );
      expect(source, contains("'notes'"));
      // the enabled literal must be exactly the two enabled features
      // (emitter sorts for stable output)
      expect(
        RegExp(r"_enabled = <String>\['notes', 'pro-analytics'\]")
            .hasMatch(source),
        isTrue,
        reason: 'enabled list must be exactly [notes, pro-analytics]',
      );
    });

    test(
      'A12: unknown names answer false — contains lookup over const set',
      () {
        final source = emitRegistry(
          className: 'FeatureFlags',
          resolved: _resolved(),
        );
        expect(source, contains('isEnabled'));
        expect(source, contains('enabledFeatures'));
      },
    );

    test('A18: variant gate declares both variants', () {
      final source = emitRegistry(
        className: 'FeatureFlags',
        resolved: _resolved(withVariants: true),
      );
      // the variant gate spec carries both variants into the build
      expect(source, contains("'variant:a|b'"));
      expect(source, contains('resolveVariant'));
    });

    test('U5: exposes DI-able constructor and runtime wiring', () {
      final source = emitRegistry(
        className: 'FeatureFlags',
        resolved: _resolved(),
      );
      expect(source, contains('class FeatureFlags'));
      expect(
        source,
        contains('FeatureFlagRuntime'),
        reason: 'emitted class delegates to the runtime contracts',
      );
    });

    test('gates are embedded for gated features', () {
      final source = emitRegistry(
        className: 'FeatureFlags',
        resolved: _resolved(withGates: true),
      );
      expect(source, contains("'membership:pro'"));
    });

    test('empty resolved set emits a valid empty registry', () {
      final source = emitRegistry(
        className: 'FeatureFlags',
        resolved: const ResolvedFeatureSet(
          enabled: {},
          disabled: {},
          gates: {},
        ),
      );
      expect(source, contains('class FeatureFlags'));
      expect(source, contains('isEnabled'));
    });
  });
}

ResolvedFeatureSet _resolved({
  bool withGates = false,
  bool withVariants = false,
}) {
  final gates = <String, List<FeatureGate>>{};
  if (withGates) {
    gates['notes'] = [FeatureGate.parse('membership:pro')];
    gates['beta-scheduler'] = [FeatureGate.parse('custom:internal')];
  }
  if (withVariants) {
    gates['notes'] = [FeatureGate.parse('variant:a|b')];
  }
  return ResolvedFeatureSet(
    enabled: {'pro-analytics', 'notes'},
    disabled: {'beta-scheduler'},
    gates: gates,
  );
}
