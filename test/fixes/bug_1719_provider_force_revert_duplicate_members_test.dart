import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generated_file.dart';
import 'package:zuraffa/src/plugins/provider/capabilities/create_provider_capability.dart';
import 'package:zuraffa/src/plugins/provider/provider_plugin.dart';
import 'package:zuraffa/src/plugins/service/capabilities/create_service_capability.dart';
import 'package:zuraffa/src/plugins/service/service_plugin.dart';

/// Bug 1719 — provider create: `--force`/`--revert` flags are no-ops and
/// the generated provider has duplicate members when the service has
/// `--init` (+ appended methods).
///
/// Three defects, one regression suite:
///
/// D1 — `zfa provider create ... --force` skipped the existing provider
///      and still printed "use --force to overwrite"; `--revert` demanded
///      `--force` too and never deleted. Root cause: the fresh-file write
///      read the flag from the plugin-level `GeneratorOptions` (const
///      default false) instead of the per-invocation `GeneratorConfig`,
///      and the create capability never forwarded the CLI `revert` flag
///      into the config at all.
/// D2 — with `--init` on both sides, the provider emitted the interface
///      members `isInitialized`/`initialize`/`dispose` as
///      signature-mangled methods (getter became `isInitialized(params)`,
///      `dispose()` became `dispose(NoParams params)`) AND the init block
///      emitted them again — `duplicate_definition` compile errors. The
///      fix: exactly one implementation member per interface member,
///      matching the interface signature (getter stays a getter,
///      parameter-less methods keep no `params`).
/// D3 — `zfa service create ... --force` also refused to overwrite (same
///      `options.force` vs `config.force` root cause in the service
///      plugin's interface write).
///
/// The plugin fixtures are constructed with the DEFAULT `GeneratorOptions`
/// (force false) — that is the configuration the CLI actually uses, and
/// the exact reason earlier tests (which passed `GeneratorOptions(force:
/// true)`) never caught the flag being dropped.
void main() {
  late Directory tempDir;
  late String outputDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zuraffa_bug_1719_');
    outputDir = Directory('${tempDir.path}/lib/src').path;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.delete(recursive: true);
    }
  });

  // Default plugin options: the CLI's real configuration. force/dryRun
  // must therefore travel on the GeneratorConfig, per invocation.
  ProviderPlugin providerPlugin() =>
      ProviderPlugin(outputDir: outputDir, options: const GeneratorOptions());

  CreateProviderCapability providerCapability() =>
      CreateProviderCapability(providerPlugin(), projectRoot: tempDir.path);

  ServicePlugin servicePlugin() =>
      ServicePlugin(outputDir: outputDir, options: const GeneratorOptions());

  CreateServiceCapability serviceCapability() =>
      CreateServiceCapability(servicePlugin(), projectRoot: tempDir.path);

  /// The service interface `zfa service create Auth --params=AuthRequest
  /// --returns=User --type=usecase --init` produces (plus an appended
  /// `auth` usecase member) — a getter, a one-param method and a
  /// parameter-less method among its members.
  void writeInitServiceInterface() {
    final file = File('$outputDir/domain/services/auth_service.dart');
    file.createSync(recursive: true);
    file.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

abstract class AuthService {
  Future<User> auth(AuthRequest params);
  Stream<bool> get isInitialized;
  Future<void> initialize(InitializationParams params);
  Future<void> dispose();
}
''');
  }

  String providerPath() => '$outputDir/data/providers/auth/auth_provider.dart';

  String servicePath() => '$outputDir/domain/services/auth_service.dart';

  List<GeneratedFile> generated(Map<String, dynamic> result) =>
      (result['generatedFiles'] as List).cast<GeneratedFile>();

  group('bug 1719 / D1 — provider create --force overwrites', () {
    test(
      '--force overwrites the existing provider file (no skip hint)',
      () async {
        writeInitServiceInterface();

        // First run creates the provider.
        final first = await providerCapability().execute({
          'name': 'Auth',
          'params': 'AuthRequest',
          'returns': 'User',
          'init': true,
        });
        expect(first.success, isTrue, reason: 'first generation must succeed');
        expect(File(providerPath()).existsSync(), isTrue);

        // Hand-edit the file so the overwrite is observable.
        File(providerPath()).writeAsStringSync(
          '// hand edit — must disappear\n${File(providerPath()).readAsStringSync()}',
        );

        // Re-run WITH --force: must overwrite, not skip.
        final result = await providerCapability().execute({
          'name': 'Auth',
          'params': 'AuthRequest',
          'returns': 'User',
          'init': true,
          'force': true,
        });

        expect(result.success, isTrue);
        final files = generated(result.data ?? {});
        expect(files, hasLength(1));
        expect(
          files.single.action,
          'overwritten',
          reason:
              'an existing provider file with --force must be overwritten, '
              'not reported as skipped (the old behavior printed "use --force '
              'to overwrite" even though the flag was passed)',
        );
        expect(
          File(providerPath()).readAsStringSync(),
          isNot(startsWith('// hand edit')),
          reason: 'the overwrite must actually replace the file content',
        );
      },
    );
  });

  group('bug 1719 / D1 — provider create --revert deletes without --force', () {
    test('--revert deletes the existing provider file', () async {
      writeInitServiceInterface();

      await providerCapability().execute({
        'name': 'Auth',
        'params': 'AuthRequest',
        'returns': 'User',
        'init': true,
      });
      expect(File(providerPath()).existsSync(), isTrue);

      final result = await providerCapability().execute({
        'name': 'Auth',
        'params': 'AuthRequest',
        'returns': 'User',
        'revert': true,
      });

      expect(result.success, isTrue);
      final files = generated(result.data ?? {});
      expect(files, hasLength(1));
      expect(
        files.single.action,
        'deleted',
        reason:
            '--revert must delete the generated provider without demanding '
            '--force (the old behavior skipped with "use --force to '
            'overwrite")',
      );
      expect(File(providerPath()).existsSync(), isFalse);
    });
  });

  group('bug 1719 / D2 — one implementation member per interface member', () {
    test('provider create --init against an --init service emits exactly one '
        'member per interface member, matching interface signatures', () async {
      writeInitServiceInterface();

      final result = await providerCapability().execute({
        'name': 'Auth',
        'params': 'AuthRequest',
        'returns': 'User',
        'init': true,
      });

      expect(result.success, isTrue);
      final content = File(providerPath()).readAsStringSync();

      // `Stream<bool> get isInitialized` must be implemented as a getter.
      expect(
        RegExp(r'Stream<bool> get isInitialized').allMatches(content),
        hasLength(1),
        reason: 'exactly one isInitialized member, as a getter',
      );
      expect(
        content.contains('isInitialized('),
        isFalse,
        reason:
            'the interface getter must not additionally be emitted as a '
            'method `Stream<bool> isInitialized(NoParams params)` '
            '(duplicate_definition)',
      );

      // `initialize` appears exactly once, with InitializationParams.
      expect(
        RegExp(r'\binitialize\s*\(').allMatches(content),
        hasLength(1),
        reason: 'exactly one initialize member (was emitted twice)',
      );
      expect(content.contains('initialize(InitializationParams'), isTrue);

      // `dispose()` keeps its parameter-less interface signature.
      expect(
        RegExp(r'\bdispose\s*\(').allMatches(content),
        hasLength(1),
        reason: 'exactly one dispose member',
      );
      expect(
        content.contains('Future<void> dispose()'),
        isTrue,
        reason:
            'the interface declares Future<void> dispose() with no '
            'parameters — the implementation must match, not '
            '`dispose(NoParams params)`',
      );
      expect(
        content.contains('dispose(NoParams'),
        isFalse,
        reason: 'the signature-mangled dispose(NoParams params) must be gone',
      );

      // The regular interface member is untouched.
      expect(content.contains('Future<User> auth(AuthRequest params)'), isTrue);
    });

    test('provider create without --init still mirrors interface signatures '
        '(getter stays a getter, dispose stays parameter-less)', () async {
      writeInitServiceInterface();

      final result = await providerCapability().execute({'name': 'Auth'});

      expect(result.success, isTrue);
      final content = File(providerPath()).readAsStringSync();

      expect(
        RegExp(r'Stream<bool> get isInitialized').allMatches(content),
        hasLength(1),
      );
      expect(
        content.contains('isInitialized('),
        isFalse,
        reason: 'interface getters are never emitted as methods',
      );
      expect(RegExp(r'\bdispose\s*\(').allMatches(content), hasLength(1));
      expect(content.contains('Future<void> dispose()'), isTrue);
      expect(content.contains('dispose(NoParams'), isFalse);
      expect(RegExp(r'\binitialize\s*\(').allMatches(content), hasLength(1));
    });
  });

  group('bug 1719 / D3 — service create --force (and --revert) work', () {
    test(
      '--force overwrites the existing service file (no "re-run with --force")',
      () async {
        final first = await serviceCapability().execute({
          'name': 'Auth',
          'params': 'AuthRequest',
          'returns': 'User',
          'init': true,
        });
        expect(first.success, isTrue);
        expect(File(servicePath()).existsSync(), isTrue);

        File(servicePath()).writeAsStringSync(
          '// hand edit — must disappear\n${File(servicePath()).readAsStringSync()}',
        );

        final result = await serviceCapability().execute({
          'name': 'Auth',
          'params': 'AuthRequest',
          'returns': 'User',
          'init': true,
          'force': true,
        });

        expect(result.success, isTrue);
        final files = generated(result.data ?? {});
        expect(
          files.single.action,
          'overwritten',
          reason:
              'zfa service create --force used to report "Re-run with --force '
              'to overwrite" while the flag was already passed — the write '
              'read force from the plugin-level options, not the config',
        );
        expect(
          File(servicePath()).readAsStringSync(),
          isNot(startsWith('// hand edit')),
        );
      },
    );

    test('--revert deletes the generated service file', () async {
      await serviceCapability().execute({
        'name': 'Auth',
        'params': 'AuthRequest',
        'returns': 'User',
        'init': true,
      });
      expect(File(servicePath()).existsSync(), isTrue);

      final result = await serviceCapability().execute({
        'name': 'Auth',
        'params': 'AuthRequest',
        'returns': 'User',
        'revert': true,
      });

      expect(result.success, isTrue);
      final files = generated(result.data ?? {});
      expect(files.single.action, 'deleted');
      expect(File(servicePath()).existsSync(), isFalse);
    });
  });
}
