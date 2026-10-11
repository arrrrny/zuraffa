// Spec 976 (issue #976) — CreateStateCapability outputSchema must
// describe the actual return shape.
//
// The schema said `files: string[]` while `execute` actually returns an
// ExecutionResult carrying `files` (string paths) AND
// `data.generatedFiles` (GeneratedFile objects with path/type/action/
// content). Schema drift misleads every manifest/AI consumer that plans
// against the declared output. This suite pins the schema against a
// REAL execute() result (order 5).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/state/capabilities/create_state_capability.dart';
import 'package:zuraffa/src/plugins/state/state_plugin.dart';

void main() {
  late Directory tempDir;
  late String outputDir;
  late CreateStateCapability capability;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_state_schema_');
    outputDir = p.join(tempDir.path, 'lib', 'src');
    await Directory(outputDir).create(recursive: true);
    final plugin = StatePlugin(
      outputDir: outputDir,
      options: const GeneratorOptions(force: true),
    );
    capability = CreateStateCapability(plugin);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('order 5: outputSchema declares the full actual return shape '
      '(success / files: string[] / data.generatedFiles objects)', () {
    final schema = capability.outputSchema;

    expect(schema['type'], 'object');

    final props = schema['properties'] as Map<String, dynamic>;
    expect(props.containsKey('success'), isTrue);
    expect((props['success'] as Map)['type'], 'boolean');

    // files stays an array of paths.
    final files = props['files'] as Map<String, dynamic>;
    expect(files['type'], 'array');
    expect((files['items'] as Map)['type'], 'string');

    // The schema must describe the generatedFiles objects execute
    // actually returns — exactly what the old schema missed.
    final data = props['data'] as Map<String, dynamic>;
    expect(data['type'], 'object');
    final dataProps = data['properties'] as Map<String, dynamic>;
    final generated = dataProps['generatedFiles'] as Map<String, dynamic>;
    expect(generated['type'], 'array');
    final item = generated['items'] as Map<String, dynamic>;
    expect(item['type'], 'object');
    final itemProps = item['properties'] as Map<String, dynamic>;
    for (final key in ['path', 'type', 'action', 'content']) {
      expect(
        itemProps.containsKey(key),
        isTrue,
        reason: 'GeneratedFile.$key must be described by the schema',
      );
      expect((itemProps[key] as Map)['type'], 'string');
    }
  });

  test('order 5: a real execute() result validates against the declared '
      'schema shape', () async {
    final result = await capability.execute({
      'name': 'Product',
      'methods': ['get', 'getList'],
    });
    expect(result.success, isTrue);

    // The consumer's view of the result: the wire shapes the
    // capability actually returns (files as paths, generatedFiles as
    // GeneratedFile.toJson maps).
    final generatedFiles =
        result.data?['generatedFiles'] as List<GeneratedFile>;
    final liveView = <String, dynamic>{
      'success': result.success,
      'files': result.files,
      'data': {
        'generatedFiles': generatedFiles
            .map((f) => f.toJson())
            .toList(growable: false),
      },
    };

    final problems = _validateAgainstSchema(liveView, capability.outputSchema);
    expect(
      problems,
      isEmpty,
      reason:
          'the declared outputSchema must match what execute() actually '
          'returns:\n${problems.join('\n')}',
    );

    // And the concrete drift the issue named: data.generatedFiles
    // objects exist in the real result.
    expect(generatedFiles, isNotEmpty);
    expect(generatedFiles.first, isA<GeneratedFile>());
    expect(generatedFiles.first.content, isNotNull);
  });
}

/// Minimal structural validator: checks the value against the declared
/// JSON-Schema-lite shape (type, array item types, object properties).
List<String> _validateAgainstSchema(
  Map<String, dynamic> value,
  Map<String, dynamic> schema,
) {
  final problems = <String>[];
  final props =
      (schema['properties'] as Map?)?.cast<String, dynamic>() ??
      const <String, dynamic>{};
  for (final entry in props.entries) {
    if (!value.containsKey(entry.key)) continue;
    problems.addAll(
      _validateValue(value[entry.key], entry.key, entry.value as Map),
    );
  }
  return problems;
}

List<String> _validateValue(Object? value, String key, Map schema) {
  final problems = <String>[];
  switch (schema['type']) {
    case 'object':
      if (value is! Map) {
        problems.add('$key: expected object, got ${value.runtimeType}');
        break;
      }
      final nested = (schema['properties'] as Map?)?.cast<String, Map>();
      if (nested != null) {
        for (final entry in nested.entries) {
          if (!value.containsKey(entry.key)) continue;
          problems.addAll(
            _validateValue(value[entry.key], '$key.${entry.key}', entry.value),
          );
        }
      }
    case 'array':
      if (value is! List) {
        problems.add('$key: expected array, got ${value.runtimeType}');
        break;
      }
      final items = schema['items'] as Map?;
      if (items != null) {
        for (var i = 0; i < value.length; i++) {
          problems.addAll(_validateValue(value[i], '$key[$i]', items));
        }
      }
    case 'string':
      if (value is! String) {
        problems.add('$key: expected string, got ${value.runtimeType}');
      }
    case 'boolean':
      if (value is! bool) {
        problems.add('$key: expected boolean, got ${value.runtimeType}');
      }
  }
  return problems;
}
