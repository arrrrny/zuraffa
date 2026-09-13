import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/plugin_loader.dart';
import 'package:zuraffa/src/config/zfa_config.dart';

/// Bug #1586 — `zfa plugin enable <id>` / `disable <id>` crashes with
/// `Unsupported operation: Cannot change an unmodifiable set` in every
/// project that has a `.zfa.json`.
///
/// Root cause (three hops):
///   1. `ZfaConfig` stores the disabled set as an unmodifiable view
///      (`Set.unmodifiable(...)` in its constructor).
///   2. `PluginConfig.load()` passes that set by reference into
///      `PluginConfig({Set<String>? disabled}) : disabled = disabled ?? {}`.
///   3. `plugin_command.dart` mutates it (`config.disabled.remove(id)` /
///      `config.disabled.add(id)`) → throws on every project with config.
///
/// Fix contract: `PluginConfig` must OWN a mutable copy of the set taken at
/// the ownership boundary (its constructor). `ZfaConfig` stays immutable.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zfa_bug_1586_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('bug #1586 — PluginConfig owns a mutable disabled set', () {
    test('A-1586-1: enable path — remove() on a loaded config does not throw '
        '(fresh scaffold: empty disabled array)', () async {
      await ZfaConfig.save(ZfaConfig(), projectRoot: tempDir.path);

      final config = PluginConfig.load(projectRoot: tempDir.path);

      // The exact mutation `plugin_command.dart` performs for `enable`.
      expect(
        () => config.disabled.remove('state'),
        returnsNormally,
        reason:
            'zfa plugin enable <id> mutates config.disabled; the set loaded '
            'from .zfa.json must be a mutable copy owned by PluginConfig',
      );
    });

    test('A-1586-2: disable path — add() on a loaded config does not throw '
        '(non-empty disabled array)', () async {
      await ZfaConfig.save(
        ZfaConfig(disabledPlugins: const {'route', 'cache'}),
        projectRoot: tempDir.path,
      );

      final config = PluginConfig.load(projectRoot: tempDir.path);
      expect(config.disabled, containsAll(['route', 'cache']));

      // The exact mutation `plugin_command.dart` performs for `disable`.
      expect(() => config.disabled.add('state'), returnsNormally);
    });

    test(
      'A-1586-3: round trip — mutate + save persists, reload reflects it',
      () async {
        await ZfaConfig.save(
          ZfaConfig(disabledPlugins: const {'state', 'route'}),
          projectRoot: tempDir.path,
        );

        final config = PluginConfig.load(projectRoot: tempDir.path);
        config.disabled.remove('state'); // enable state
        config.disabled.add('cache'); // disable cache
        // Issue #1586: save() is awaitable and, once awaited, the mutation
        // is durably persisted (the CLI runner exits right after the command
        // returns, so a fire-and-forget save never landed).
        await config.save(projectRoot: tempDir.path);

        final configFile = File('${tempDir.path}/.zfa.json');
        final json =
            jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
        final plugins = json['plugins'] as Map<String, dynamic>?;
        final persisted =
            (plugins?['disabled'] as List<dynamic>? ?? const <dynamic>[])
                .map((e) => e.toString())
                .toSet();
        expect(
          persisted,
          isNot(contains('state')),
          reason:
              'enabled plugin must be removed from the persisted '
              'disabled array',
        );
        expect(persisted, containsAll(['cache', 'route']));

        final reloaded = PluginConfig.load(projectRoot: tempDir.path);
        expect(reloaded.disabled, isNot(contains('state')));
        expect(reloaded.disabled, contains('cache'));
        expect(reloaded.disabled, contains('route'));
      },
    );

    test('A-1586-4: defensive copy — caller-owned set/const set is copied, '
        'mutation of the copy does not leak back', () {
      final caller = <String>{'route'};
      final config = PluginConfig(disabled: caller);
      config.disabled.add('state');

      expect(config.disabled, contains('state'));
      expect(
        caller,
        isNot(contains('state')),
        reason: 'PluginConfig must own a copy, not alias the caller set',
      );
    });

    test('A-1586-5: the must-not-break guard — ZfaConfig.disabledPlugins '
        'stays an unmodifiable view (immutability contract intact)', () async {
      await ZfaConfig.save(
        ZfaConfig(disabledPlugins: const {'route'}),
        projectRoot: tempDir.path,
      );

      final zfaConfig = ZfaConfig.load(projectRoot: tempDir.path);
      expect(
        () => zfaConfig!.disabledPlugins.add('x'),
        throwsUnsupportedError,
        reason:
            'the fix lands at the PluginConfig ownership boundary; '
            'ZfaConfig must remain immutable',
      );
    });
  });
}
