import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/exit_protocol.dart';
import 'package:zuraffa/src/commands/capability_command.dart';
import 'package:zuraffa/src/commands/service_create_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/core/plugin_system/capability.dart';
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
///
/// Review follow-up (the PR's own review thread):
/// R1 — the provider DELETE path still read `options.dryRun`/`verbose`
///      (const, always false), so `--revert --dry-run` — and a plan()
///      run with revert: true — deleted the provider for real.
/// R2 — the init-member dedup compared NAMES only: a hand-modified
///      interface member with a deviating signature was silently replaced
///      by the canonical `--init` stub. Now the interface's own shape
///      wins and the canonical member is dropped.
/// R3 — a revert of a MISSING file printed "use --force to overwrite";
///      the messaging now keys on revert and says "nothing to revert".
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

  group('bug 1719 review / R1 — a dry-run revert must never delete for real', () {
    test(
      'provider --revert --dry-run reports the delete but the file survives',
      () async {
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
          'dryRun': true,
        });

        expect(result.success, isTrue);
        expect(
          generated(result.data ?? {}).single.action,
          'deleted',
          reason: 'the dry-run still REPORTS the delete it previews',
        );
        expect(
          File(providerPath()).existsSync(),
          isTrue,
          reason:
              'the delete path read dryRun from the plugin-level const '
              'GeneratorOptions (always false), so `--revert --dry-run` '
              'deleted the provider for real',
        );
      },
    );

    test(
      'plan() with revert: true (the --dry-run surface) is a preview, not a deletion',
      () async {
        writeInitServiceInterface();
        await providerCapability().execute({
          'name': 'Auth',
          'params': 'AuthRequest',
          'returns': 'User',
          'init': true,
        });

        final report = await providerCapability().plan({
          'name': 'Auth',
          'revert': true,
        });

        expect(report.changes.single.action, 'deleted');
        expect(
          File(providerPath()).existsSync(),
          isTrue,
          reason:
              'plan() hardcodes dryRun: true — a planned revert must '
              'not destroy the file it previews',
        );
      },
    );
  });

  group(
    'bug 1719 review / R2 — init-member dedup compares signatures, not just names',
    () {
      test('a hand-modified initialize(MyParams) keeps its own shape — the '
          'canonical InitializationParams stub must not replace it', () async {
        final file = File('$outputDir/domain/services/auth_service.dart');
        file.createSync(recursive: true);
        file.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

abstract class AuthService {
  Future<User> auth(AuthRequest params);
  Stream<bool> get isInitialized;
  Future<void> initialize(MyParams params);
  Future<void> dispose();
}
''');

        final result = await providerCapability().execute({
          'name': 'Auth',
          'params': 'AuthRequest',
          'returns': 'User',
          'init': true,
        });

        expect(result.success, isTrue);
        final content = File(providerPath()).readAsStringSync();

        expect(
          RegExp(r'\binitialize\s*\(').allMatches(content),
          hasLength(1),
          reason: 'still exactly one initialize member',
        );
        expect(
          content.contains('initialize(MyParams params)'),
          isTrue,
          reason:
              'the interface\'s own parameter type must win — the '
              'canonical stub does not implement the interface',
        );
        expect(
          content.contains('InitializationParams'),
          isFalse,
          reason:
              'the canonical InitializationParams stub must be dropped '
              'when the interface shape deviates',
        );
        // Signature-matching neighbors keep the canonical semantic bodies.
        expect(
          RegExp(r'Stream<bool> get isInitialized').allMatches(content),
          hasLength(1),
        );
        expect(content.contains('Future<void> dispose()'), isTrue);
      });

      test(
        'a hand-modified isInitialized METHOD (not a getter) keeps its own shape',
        () async {
          final file = File('$outputDir/domain/services/auth_service.dart');
          file.createSync(recursive: true);
          file.writeAsStringSync('''
import 'package:zuraffa/zuraffa.dart';

abstract class AuthService {
  Future<User> auth(AuthRequest params);
  Stream<bool> isInitialized();
  Future<void> initialize(InitializationParams params);
  Future<void> dispose();
}
''');

          final result = await providerCapability().execute({
            'name': 'Auth',
            'params': 'AuthRequest',
            'returns': 'User',
            'init': true,
          });

          expect(result.success, isTrue);
          final content = File(providerPath()).readAsStringSync();

          expect(
            RegExp(r'\bisInitialized\s*\(').allMatches(content),
            hasLength(1),
            reason: 'exactly one isInitialized member (as a method)',
          );
          expect(
            content.contains('Stream<bool> isInitialized()'),
            isTrue,
            reason:
                'the interface declares a method — the implementation '
                'must be a method, not the canonical getter',
          );
          expect(
            content.contains('Stream<bool> get isInitialized'),
            isFalse,
            reason:
                'the canonical getter must be dropped when the interface '
                'shape deviates',
          );
        },
      );
    },
  );

  group(
    'bug 1719 review / R3 — revert-nothing runs say so instead of pointing at --force',
    () {
      test(
        'service create --revert on a missing file prints "nothing to revert" (prose)',
        () async {
          final runner = CommandRunner<void>('zfa', 'test')
            ..addCommand(
              ServiceCreateCommand(servicePlugin(), projectRoot: tempDir.path),
            );
          exitCode = 0;
          late int code;
          await expectLater(
            () => runner.run(['create', 'Auth', '--revert']).then((_) {
              code = exitCode;
            }),
            prints(contains('Nothing to revert')),
          );
          exitCode = 0; // hermetic: never leak a failure code into the suite
          expect(
            code,
            ExitProtocol.failure,
            reason:
                'reverting nothing still refuses (unchanged semantics) — '
                'only the misleading --force advice was wrong',
          );
          expect(File(servicePath()).existsSync(), isFalse);
        },
      );

      test('service create --revert --json on a missing file carries a '
          'nothing-to-revert fix slot', () async {
        final runner = CommandRunner<void>('zfa', 'test')
          ..addCommand(
            ServiceCreateCommand(servicePlugin(), projectRoot: tempDir.path),
          );
        exitCode = 0;
        await expectLater(
          () => runner.run(['create', 'Auth', '--revert', '--json']).then((_) {
            exitCode = 0;
          }),
          prints(contains('nothing to revert')),
        );
      });

      test(
        'the shared capability runner keys the skip hint on revert',
        () async {
          final runner = CommandRunner<void>('zfa', 'test')
            ..addCommand(
              CapabilityCommand(
                _SkippedOnRevertCapability(),
                projectRoot: tempDir.path,
              ),
            );
          exitCode = 0;
          await expectLater(
            () => runner.run(['create', 'Auth', '--revert']).then((_) {
              exitCode = 0;
            }),
            prints(contains('⏭ Skipped (nothing to revert):')),
          );
        },
      );
    },
  );
}

/// A generator-style capability whose only artifact comes back `skipped` —
/// the shape `FileUtils.writeFile`'s revert branch produces for a missing
/// file. Drives the shared [CapabilityCommand] skip hint (review R3).
class _SkippedOnRevertCapability implements ZuraffaCapability {
  @override
  String get name => 'create';

  @override
  String get description => 'skipped-on-revert stub';

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
    pluginId: 'provider',
    capabilityName: name,
    args: args,
    changes: [],
  );

  @override
  Future<ExecutionResult> execute(Map<String, dynamic> args) async =>
      ExecutionResult(
        success: true,
        data: {
          'generatedFiles': [
            GeneratedFile(
              path: 'lib/src/data/providers/auth/auth_provider.dart',
              type: 'provider',
              action: 'skipped',
            ),
          ],
        },
      );
}
