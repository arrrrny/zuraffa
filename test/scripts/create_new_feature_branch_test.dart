import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

void main() {
  test(
    'no-jq metadata fallback adds feature_number to an empty object',
    () async {
      final root = await findProjectRoot();
      final sandbox = await Directory.systemTemp.createTemp(
        'create-new-feature-branch-test-',
      );
      addTearDown(() => sandbox.delete(recursive: true));

      final repo = Directory('${sandbox.path}/repo')..createSync();
      final scriptDir = Directory(
        '${repo.path}/.specify/extensions/git/scripts/bash',
      )..createSync(recursive: true);
      final sourceDir = '$root/.specify/extensions/git/scripts/bash';
      for (final name in ['create-new-feature-branch.sh', 'git-common.sh']) {
        File('$sourceDir/$name').copySync('${scriptDir.path}/$name');
      }

      final init = await Process.run('git', [
        'init',
        '-q',
      ], workingDirectory: repo.path);
      expect(init.exitCode, 0, reason: init.stderr.toString());

      final featureJson = File('${repo.path}/.specify/feature.json')
        ..writeAsStringSync('{}\n');
      final noJqBin = Directory('${sandbox.path}/bin')..createSync();
      for (final command in [
        'bash',
        'basename',
        'dirname',
        'git',
        'grep',
        'head',
        'mkdir',
        'mv',
        'rm',
        'sed',
        'tr',
        'wc',
      ]) {
        final resolved = await Process.run('which', [command]);
        expect(resolved.exitCode, 0, reason: '$command must be available');
        Link(
          '${noJqBin.path}/$command',
        ).createSync(resolved.stdout.toString().trim());
      }

      final result = await Process.run(
        '${noJqBin.path}/bash',
        ['${scriptDir.path}/create-new-feature-branch.sh', 'empty metadata'],
        workingDirectory: repo.path,
        environment: {
          ...Platform.environment,
          'PATH': noJqBin.path,
          'GIT_BRANCH_NAME': '001-empty-metadata',
        },
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(jsonDecode(featureJson.readAsStringSync()), {
        'feature_number': '001',
      });
    },
    skip: Platform.isWindows ? 'Bash-only git extension' : false,
  );
}
