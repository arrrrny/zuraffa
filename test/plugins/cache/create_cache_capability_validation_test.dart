import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/cache/cache_plugin.dart';
import 'package:zuraffa/src/plugins/cache/capabilities/create_cache_capability.dart';

/// Regression tests for issue #772: `zfa cache create --name <X>` reported
/// `✅ Success! (No changes required)` for an entity that does not exist —
/// zero files, no validation, exit 0. The sibling `cache adapter` capability
/// correctly fails with `Entity '<X>' not found.` + an `Available entities:`
/// list; this pins the same contract on `cache create`.
void main() {
  late Directory workspace;
  late CreateCacheCapability capability;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('cache_create_772_');
    final plugin = CachePlugin(outputDir: workspace.path);
    capability = CreateCacheCapability(plugin);
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<void> addEntity(String name) async {
    final dir = Directory('${workspace.path}/domain/entities/${_snake(name)}');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/${_snake(name)}.dart',
    ).writeAsString('class $name {}\n');
  }

  test('nonexistent entity fails instead of false success (#772)', () async {
    final result = await capability.execute({'name': 'Ghost', 'dryRun': false});

    // Pre-fix this was success:true with zero files — the false success.
    expect(result.success, isFalse);
    expect(result.message, contains("Entity 'Ghost' not found."));
    expect(result.files, isEmpty);
  });

  test('failure lists available entities (sibling adapter parity)', () async {
    await addEntity('Auth');

    final result = await capability.execute({'name': 'Ghost', 'dryRun': false});

    expect(result.success, isFalse);
    expect(result.message, contains('Available entities:'));
    expect(result.message, contains('- Auth'));
  });

  test('existing entity is not rejected by validation (guard)', () async {
    await addEntity('Product');

    final result = await capability.execute({
      'name': 'Product',
      'dryRun': false,
    });

    // Whatever the generator produces for a minimal entity, validation must
    // not reject a real entity with the not-found error.
    final notFound = (result.message ?? '').contains(
      "Entity 'Product' not found",
    );
    expect(notFound, isFalse, reason: 'result: ${result.message}');
    if (result.success) {
      // Generation ran; validation did not block it.
      expect(result.success, isTrue);
    }
  });
}

String _snake(String name) {
  final buffer = StringBuffer();
  for (var i = 0; i < name.length; i++) {
    final c = name[i];
    if (c.toUpperCase() == c &&
        c.toLowerCase() != c &&
        i > 0 &&
        name[i - 1].toLowerCase() != name[i - 1].toUpperCase()) {
      buffer.write('_');
    }
    buffer.write(c.toLowerCase());
  }
  return buffer.toString();
}
