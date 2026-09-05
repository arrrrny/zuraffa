@Tags(['slow'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/plugin_system/capability_invocation_wrapper.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
import 'package:zuraffa/src/models/generated_file.dart';

import '../../helpers/run_zfa_source.dart';

/// Spec 0996 (issue #996), FR-004 — `zfa proof check` on a standalone
/// capability receipt validates: exit 0 with `valid: true` in the
/// machine verdict (JSON format).
///
/// Driven through a real subprocess ([runZfaSource]) so the exit-code
/// protocol is exercised exactly as CI consumes it (issue #506 pattern).
void main() {
  setUpAll(initZfaSourceBin);

  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('zfa_996_proof_');
  });

  tearDown(() {
    exitCode = 0;
    if (workspace.existsSync()) {
      try {
        workspace.deleteSync(recursive: true);
      } on PathNotFoundException {
        // Already gone.
      }
    }
  });

  /// Persists a standalone capability receipt exactly the way a real
  /// `zfa di create Product` run does (issue #996): via the wrapper.
  Future<void> seedCapabilityReceipt() async {
    final artifact = File(
      p.join(workspace.path, 'lib', 'src', 'domain', 'product_di.dart'),
    );
    await artifact.parent.create(recursive: true);
    const content = '// generated DI wiring for Product\n';
    await artifact.writeAsString(content);

    final capability = _PlainCapability();
    final wrapper = CapabilityInvocationWrapper(
      capability: capability,
      pluginId: 'di',
      projectRoot: workspace.path,
    );
    final saved = await wrapper.persistReceipt(
      args: {
        'name': 'Product',
        'methods': ['get', 'update'],
      },
      result: ExecutionResult(
        success: true,
        files: ['lib/src/domain/product_di.dart'],
        data: {
          'generatedFiles': [
            GeneratedFile(
              path: 'lib/src/domain/product_di.dart',
              type: 'di',
              action: 'created',
            ),
          ],
        },
      ),
    );
    expect(saved, isNotNull, reason: 'the seeded receipt must exist');
  }

  group('zfa proof check on a standalone capability receipt (FR-004)', () {
    test('validates: exit 0, JSON verdict valid: true', () async {
      await seedCapabilityReceipt();

      final result = await runZfaSource([
        'proof',
        'check',
        '--format',
        'json',
      ], workingDirectory: workspace.path);

      expect(
        result.stderr,
        isEmpty,
        reason: 'proof check must not error on a capability receipt',
      );
      expect(result.exitCode, 0, reason: 'a valid receipt exits 0');

      final verdict =
          jsonDecode(_lastJsonLine(result.stdout)) as Map<String, dynamic>;
      expect(verdict['schema'], 'proof.v1');
      expect(verdict['valid'], isTrue, reason: 'issue #996: valid: true');
      expect(verdict['ok'], isTrue);
      expect(verdict['receipts'], 1);
      expect(verdict['filesChecked'], 1);
      expect((verdict['findings'] as List), isEmpty);
    });

    test('drift on a capability receipt fails: valid: false, exit 1', () async {
      await seedCapabilityReceipt();
      await File(
        p.join(workspace.path, 'lib', 'src', 'domain', 'product_di.dart'),
      ).writeAsString('// drifted\n');

      final result = await runZfaSource([
        'proof',
        'check',
        '--format',
        'json',
      ], workingDirectory: workspace.path);

      expect(result.exitCode, 1);
      final verdict =
          jsonDecode(_lastJsonLine(result.stdout)) as Map<String, dynamic>;
      expect(verdict['valid'], isFalse);
      expect(verdict['ok'], isFalse);
      expect((verdict['findings'] as List), isNotEmpty);
    });
  });
}

/// The last non-empty stdout line holds the JSON verdict object.
String _lastJsonLine(String stdout) {
  final lines = stdout.trim().split('\n').where((l) => l.trim().isNotEmpty);
  return lines.last;
}

/// Minimal capability view — [CapabilityInvocationWrapper.persistReceipt]
/// only needs name/schema identity, never execution.
class _PlainCapability implements ZuraffaCapability {
  @override
  String get name => 'create';

  @override
  String get description => 'plain capability';

  @override
  JsonSchema get inputSchema => {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
    },
    'required': ['name'],
  };

  @override
  JsonSchema get outputSchema => const {};

  @override
  Future<EffectReport> plan(Map<String, dynamic> args) async => EffectReport(
    planId: 'plan',
    pluginId: 'di',
    capabilityName: name,
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      throw UnimplementedError('not executed in this test');
}
