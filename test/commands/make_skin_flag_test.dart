// Issue #1166 (stage 3/4 of #1111): `zfa make --skin` — the skin flag is
// a first-class make flag and reaches the view plugin's context data,
// so every generated skin view mounts the runtime auditor at `view`
// (the wrap itself is pinned by test/plugins/view/view_skin_audit_wrap_test.dart).
//
// Fast structural pins: the flag exists on make, and buildContext maps a
// parsed --skin into `data['skin']` through the view plugin's schema —
// no subprocess needed.
library;

import 'package:test/test.dart';
import 'dart:io';

import 'package:zuraffa/src/commands/make_command.dart';
import 'package:zuraffa/src/core/plugin_system/plugin_registry.dart';
import 'package:zuraffa/src/plugins/view/view_plugin.dart';

void main() {
  group('issue #1166 — zfa make --skin', () {
    test('the make command exposes a --skin flag', () {
      final command = MakeCommand(PluginRegistry.instance);
      expect(command.argParser.options, contains('skin'));
    });

    test('the view plugin schema declares skin (buildContext merges it)', () {
      final schema = ViewPlugin(
        outputDir: Directory.systemTemp.path,
      ).configSchema;
      final properties = schema['properties'] as Map<String, dynamic>;
      final skin = properties['skin'] as Map<String, dynamic>?;
      expect(skin, isNotNull);
      expect(skin!['type'], 'boolean');
      expect(skin['default'], isFalse);
    });
  });
}
