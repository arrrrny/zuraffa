import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/project/project_context_store.dart';

void main() {
  group('ProjectContextStore', () {
    late Directory tempDir;
    late ProjectContextStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zfa_project_context_');
      store = ProjectContextStore(projectRoot: tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists context.json under .zfa', () async {
      final context = ProjectContextStore.defaultContext();
      await store.save(context);

      final loaded = await store.load();
      expect(loaded, isNotNull);
      expect(loaded!['version'], '5.0');
      expect(loaded['domain_root'], 'lib/src/domain');
      expect(loaded['zorphy_only'], isTrue);
      expect(loaded['workflow'], contains('zfa entity create'));

      expect(Directory(path.join(tempDir.path, '.zfa')).existsSync(), isTrue);
      expect(
        Directory(path.join(tempDir.path, '.zfa', 'decisions')).existsSync(),
        isTrue,
      );
      expect(
        Directory(path.join(tempDir.path, '.zfa', 'manifests')).existsSync(),
        isTrue,
      );
    });

    test('creates .zfa directory structure', () async {
      final context = ProjectContextStore.defaultContext();
      await store.save(context);

      expect(Directory(path.join(tempDir.path, '.zfa')).existsSync(), isTrue);
      expect(
        Directory(path.join(tempDir.path, '.zfa', 'plans')).existsSync(),
        isTrue,
      );
      expect(
        Directory(path.join(tempDir.path, '.zfa', 'runs')).existsSync(),
        isTrue,
      );
    });
  });
}
