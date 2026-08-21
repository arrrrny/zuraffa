import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/gym_command.dart';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/plugins/gym/gym_plugin.dart';

void main() {
  group('GymCommand', () {
    late Directory workspace;
    late String outputDir;

    setUp(() async {
      workspace = await Directory.systemTemp.createTemp('zfa_gym_command_');
      outputDir = '${workspace.path}/lib/src';
      await Directory(outputDir).create(recursive: true);
      await File('${workspace.path}/pubspec.yaml')
          .writeAsString('name: zuraffa_test');
    });

    tearDown(() async {
      if (workspace.existsSync()) {
        await workspace.delete(recursive: true);
      }
    });

    test('generates gym artifact for a plain entity name', () async {
      final result = await GymCommand(
        GymPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: false,
            verbose: false,
          ),
        ),
      ).execute([
        'Product',
        '--output',
        outputDir,
        '--domain',
        'general',
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      // 4 files: 2 warmup reps + 1 exercise + 1 gym.yaml
      expect(result.files.length, equals(4));

      final paths = result.files.map((f) => f.path).toList();
      expect(
        paths,
        containsAll([
          '${workspace.path}/gym/warmup/01-smoke.dart',
          '${workspace.path}/gym/warmup/02-build.dart',
          '${workspace.path}/gym/exercise-implement-feature.dart',
          '${workspace.path}/gym/gym.yaml',
        ]),
      );

      // The gym.yaml must reference the entity (snake-cased).
      final yaml = result.files.firstWhere(
        (f) => f.path.endsWith('gym.yaml'),
      );
      final content = yaml.content ?? '';
      expect(content, contains('name: product'));
      expect(content, contains('warmup:'));
      expect(content, contains('exercises:'));
    });

    test('generates gym artifact referencing a real usecase when present',
        () async {
      // Drop a usecase file so buildConfigFromUseCase can infer the repo.
      final useCaseDir =
          Directory('${workspace.path}/lib/src/domain/usecases/account');
      await useCaseDir.create(recursive: true);
      await File('${useCaseDir.path}/fetch_user_usecase.dart')
          .writeAsString('''
import 'package:zuraffa/zuraffa.dart';

class FetchUserUseCase extends UseCase<User, NoParams> {
  final UserRepository _repository;

  FetchUserUseCase(this._repository);

  @override
  Future<User> execute(NoParams params, CancelToken? cancelToken) async {
    throw UnimplementedError();
  }
}
''');

      final result = await GymCommand(
        GymPlugin(
          outputDir: outputDir,
          options: const GeneratorOptions(
            dryRun: false,
            force: false,
            verbose: false,
          ),
        ),
      ).execute([
        'FetchUser',
        '--output',
        outputDir,
        '--domain',
        'account',
        '--dry-run',
      ], exitOnCompletion: false);

      expect(result.success, isTrue);
      expect(result.files.length, equals(4));

      final smoke = result.files.firstWhere(
        (f) => f.path.endsWith('01-smoke.dart'),
      );
      final content = smoke.content ?? '';
      // The smoke rep must reference the inferred entity name.
      expect(content, contains('FetchUser'));
      expect(content, contains('FetchUserUseCase'));
    });

    test('prints usage and fails when no name is given', () async {
      final result = await GymCommand(
        GymPlugin(outputDir: outputDir),
      ).execute([], exitOnCompletion: false);

      expect(result.success, isFalse);
      expect(result.errors, contains('Missing arguments'));
    });
  });
}
