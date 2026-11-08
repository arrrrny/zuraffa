import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/agent/plugin/agent_plugin.dart';
import 'package:zuraffa/src/agent/plugin/tool_params_registry.dart';
import 'package:zuraffa/src/models/generator_config.dart';

/// A typed params value class in the shape zfa-generated usecases take
/// (zuraffa#2061): NOT a map, so a raw pass-through crashes the call.
class IdentifierLookupParams {
  final String code;
  const IdentifierLookupParams({required this.code});
}

void main() {
  group('ToolParamsRegistry (zuraffa#2061)', () {
    test(
      'returns null when no fromWire is registered — pass-through stays',
      () {
        ToolParamsRegistry.fromWire.remove('IdentifierLookupParams');
        expect(
          ToolParamsRegistry.coerce('IdentifierLookupParams', {'code': 'abc'}),
          isNull,
        );
      },
    );

    test('coerces the wire map through the registered fromWire factory', () {
      ToolParamsRegistry.fromWire['IdentifierLookupParams'] = (wire) =>
          IdentifierLookupParams(code: wire['code'] as String);

      final coerced = ToolParamsRegistry.coerce('IdentifierLookupParams', {
        'code': 'abc',
      });

      expect(coerced, isA<IdentifierLookupParams>());
      expect((coerced as IdentifierLookupParams).code, equals('abc'));

      ToolParamsRegistry.fromWire.remove('IdentifierLookupParams');
    });

    test('keys are independent per params type', () {
      ToolParamsRegistry.fromWire['IdentifierLookupParams'] = (wire) =>
          IdentifierLookupParams(code: wire['code'] as String);

      expect(
        ToolParamsRegistry.coerce('SomeOtherParams', {'code': 'abc'}),
        isNull,
      );

      ToolParamsRegistry.fromWire.remove('IdentifierLookupParams');
    });
  });

  group('tool wrapper emission consults the coercion seam (zuraffa#2061)', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('tool_params_coercion_');
    });

    tearDown(() async {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    });

    test(
      'a typed-params wrapper coerces instead of passing the map through',
      () async {
        // A usecase whose params are a TYPED class, not a map (the #2061
        // repro shape: zfa usecase create --params=<Entity>).
        final usecaseDir = p.join(
          tmp.path,
          'lib',
          'src',
          'domain',
          'usecases',
          'identifier_lookup',
        );
        Directory(usecaseDir).createSync(recursive: true);
        File(
          p.join(usecaseDir, 'get_identifier_lookup_usecase.dart'),
        ).writeAsStringSync('''
class GetIdentifierLookupUseCase extends UseCase<BarcodeLookupResult, IdentifierLookupParams> {
  @override
  Future<BarcodeLookupResult> call(IdentifierLookupParams params) async => BarcodeLookupResult();
}
''');

        await File(p.join(tmp.path, 'pubspec.yaml')).writeAsString('''
name: zuraffa_tool_params_e2e
environment:
  sdk: ^3.0.0
''');

        final outputDir = p.join(tmp.path, 'lib', 'src');
        final plugin = AgentPlugin(
          outputDir: outputDir,
          namespaceOverride: 'app',
          projectRootOverride: tmp.path,
        );
        final config = GeneratorConfig(
          name: 'IdentifierLookup',
          outputDir: outputDir,
          force: true,
        );
        await plugin.generate(config);

        final toolSrc = File(
          p.join(
            outputDir,
            'agent',
            'tools',
            'identifier_lookup_get_tool.dart',
          ),
        ).readAsStringSync();

        // The seam must be consulted with the wrapper's own params type...
        expect(toolSrc, contains('ToolParamsRegistry.coerce('));
        expect(toolSrc, contains("'IdentifierLookupParams',"));
        // ...and the import must ride along so the emitted file compiles.
        expect(
          toolSrc,
          contains(
            "import 'package:zuraffa/src/agent/plugin/tool_params_registry.dart';",
          ),
        );
        // ...and the unregistered path still passes the raw map through
        // (Map-params usecases keep their behavior).
        expect(toolSrc, contains('if (coerced != null) return coerced;'));
        expect(toolSrc, contains('return arguments;'));
      },
    );
  });
}
