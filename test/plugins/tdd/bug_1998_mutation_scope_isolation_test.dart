@Tags(['spawn'])
// Bug #1998 — the verify run's mutation scope must be THIS feature's
// registered subjects.
//
// The scoped mutation config and the mutation report used to live at
// per-PROJECT paths (`.dart_tool/zfa/tdd-verify-mutation.xml` and
// `.dart_tool/zfa/tdd-verify-report/`), so two verify runs in the same
// project shared ONE config and ONE report. The config is written
// before the (multi-minute) preflight and read by the mutation child
// afterwards: a second run's config replaced the first's in that
// window, so the child mutated the OTHER feature's registered subjects
// — and every one of those mutants survived, because this run's tests
// do not cover them. The published verification record then named
// another feature's `lib/tdd/<other-feature>/` survivors as this
// feature's gate, and none of the feature's own subjects was mutated
// at all.
//
// The contract pinned here:
//   1. Two features verified in ONE project never share a config path
//      or a report path.
//   2. The config handed to the mutation child lists EXACTLY the
//      feature's registered subjects — never another feature's.
//   3. A config that no longer lists this feature's registered
//      subjects is REFUSED before the child starts: no foreign file is
//      mutated and no foreign number is published.
//
// The audit runs in a CHILD `dart` process whose PATH carries a fake
// `dart`: the mutation child is then the fake, which reports the first
// file of the config it was handed (the file the real tool mutates) —
// so the whole production spawn path is exercised, hermetically.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;
  late String originalPath;

  const featureA = '001-purchase-store';
  const featureB = '002-subscription-error-vocabulary';

  /// Writes a feature's registry (`specs/<name>/tdd/artifacts.json`) with
  /// one registered subject per [subjectIds] — the registry the mutation
  /// scope is derived from.
  void writeFeature(String name, List<String> subjectIds) {
    final dir = Directory(p.join(tmpDir.path, 'specs', name, 'tdd'))
      ..createSync(recursive: true);
    File(p.join(dir.path, 'artifacts.json')).writeAsStringSync(
      jsonEncode({
        'feature': name,
        'records': [
          for (final id in subjectIds)
            {
              'behavior_id': id,
              'feature': name,
              'source_criterion': 'FR-001',
              'test_path': 'test/tdd/$name/${id}_test.dart',
              'subject_path': 'lib/tdd/$name/${id}_subject.dart',
              'runnable_test_name': '$id::asserts behavior',
              'test_ownership': 'created',
              'subject_ownership': 'created',
              'created_at': '2026-10-22T00:00:00.000Z',
            },
        ],
      }),
    );
    // The subjects exist on disk: the audit captures and restores them.
    for (final id in subjectIds) {
      final subject = File(
        p.join(tmpDir.path, 'lib', 'tdd', name, '${id}_subject.dart'),
      )..parent.createSync(recursive: true);
      subject.writeAsStringSync('int ${id}Value() => 1;\n');
    }
  }

  /// Installs a fake `dart` on the child's PATH: it answers the runner's
  /// `--version` probe and the mutation run itself. The fake reports the
  /// FIRST file of the config it was handed — the file the real tool
  /// mutates — and records the config path it received.
  void installFakeDart() {
    final script = '''#!/bin/sh
# Stand-in for `dart run mutation_test <config> -f md -o <outdir>`.
if [ "\$1" = "--version" ]; then
  echo "Dart SDK version: 3.0.0 (fake)"
  exit 0
fi
config="\$3"
out=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
mkdir -p "\$out"
echo "\$config" > "\$(dirname "\$out")/child-ran.txt"
first=\$(sed -n 's/.*<file>\\(.*\\)<\\/file>.*/\\1/p' "\$config" | head -1)
cat > "\$out/mutation-test-report.md" <<EOF
# Mutation report

Mutants killed: 1
Mutants survived: 1

## Undetected mutations in file : \$first
Line 3 :
EOF
exit 0
''';
    final file = File(p.join(tmpDir.path, 'fake-bin', 'dart'))
      ..parent.createSync(recursive: true);
    file.writeAsStringSync(script);
    Process.runSync('chmod', ['+x', file.path]);
  }

  /// The audit driver — it runs in a child `dart` process so the fake
  /// `dart` on the PATH is the mutation child.
  const auditScript = '''
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';

Future<void> main(List<String> args) async {
  final tmp = args[0];
  final feature = args[1];
  final clobber = args.contains('clobber');
  final auditor = MutationAuditor(
    featureDir: p.join(tmp, 'specs', feature),
    workingDirectory: tmp,
    runPreflight: (scopePaths) async {
      if (clobber) {
        // Another run replaced the scoped config between this run's
        // write and the mutation child's read.
        final root = Directory(p.join(tmp, '.dart_tool', 'zfa'));
        final configs = root.existsSync()
            ? root
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.xml'))
                .toList()
            : <File>[];
        final foreign = File(p.join(tmp, 'foreign-config.xml')).readAsStringSync();
        for (final c in configs) {
          c.writeAsStringSync(foreign);
        }
      }
      return PreflightResult.green(
        exitCode: 0,
        output: 'preflight green',
        ranTestPaths: scopePaths,
      );
    },
  );
  final report = await auditor.run();
  print('AUDIT_RESULT:' + jsonEncode({
    'gate': report.gate.label,
    'reason': report.notAssessedReason,
    'killed': report.killedCount,
    'survived': report.survivedCount,
    'reportPath': report.reportPath,
  }));
}
''';

  /// Runs the audit for [feature] in a child `dart` process.
  Future<Map<String, dynamic>> runAudit(
    String feature, {
    bool clobber = false,
  }) async {
    final script = File(p.join(tmpDir.path, 'audit_child.dart'))
      ..writeAsStringSync(auditScript);
    final packageConfig = p.join(
      Directory.current.path,
      '.dart_tool',
      'package_config.json',
    );
    final childArgs = <String>[
      '--packages=$packageConfig',
      script.path,
      tmpDir.path,
      feature,
    ];
    if (clobber) {
      childArgs.add('clobber');
    }
    final result = Process.runSync(
      Platform.resolvedExecutable,
      childArgs,
      workingDirectory: Directory.current.path,
      environment: {'PATH': '${p.join(tmpDir.path, 'fake-bin')}:$originalPath'},
      includeParentEnvironment: true,
    );
    final stdout = result.stdout.toString();
    final line = stdout
        .split('\n')
        .where((l) => l.startsWith('AUDIT_RESULT:'))
        .firstOrNull;
    if (line == null) {
      fail(
        'the audit child produced no result\n'
        'stdout: $stdout\n'
        'stderr: ${result.stderr}',
      );
    }
    return jsonDecode(line.substring('AUDIT_RESULT:'.length))
        as Map<String, dynamic>;
  }

  /// Every scoped mutation config the project holds.
  List<File> scopedConfigs() {
    final root = Directory(p.join(tmpDir.path, '.dart_tool', 'zfa'));
    if (!root.existsSync()) return [];
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.xml'))
        .toList();
  }

  /// The marker the fake child writes when it runs.
  File? childMarker() {
    final root = Directory(p.join(tmpDir.path, '.dart_tool', 'zfa'));
    if (!root.existsSync()) return null;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('child-ran.txt')) {
        return entity;
      }
    }
    return null;
  }

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug_1998_mutation_scope_');
    writeFeature(featureA, ['u1', 'u2']);
    writeFeature(featureB, ['u1', 'u2']);
    installFakeDart();
    originalPath = Platform.environment['PATH'] ?? '';
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test(
    'two features verified in one project never share a config or a report',
    () async {
      final a = await runAudit(featureA);
      final b = await runAudit(featureB);

      // Both runs assessed their own scope: the fake child reports the
      // config's first file, which is inside the feature's scope.
      expect(a['gate'], 'fail_survived');
      expect(b['gate'], 'fail_survived');

      // One config per feature — the two runs did not overwrite each
      // other's scope.
      final configs = scopedConfigs();
      expect(
        configs.length,
        2,
        reason:
            'each feature must own its scoped mutation config; the runs '
            'shared ${configs.map((c) => c.path).toList()}',
      );

      // And each config still lists ITS OWN subjects.
      final configTexts = configs.map((c) => c.readAsStringSync()).toList();
      expect(
        configTexts.where(
          (t) => t.contains('lib/tdd/$featureA/u1_subject.dart'),
        ),
        hasLength(1),
      );
      expect(
        configTexts.where(
          (t) => t.contains('lib/tdd/$featureB/u1_subject.dart'),
        ),
        hasLength(1),
      );

      // The reports land in per-feature places too.
      expect(a['reportPath'], isNotNull);
      expect(b['reportPath'], isNotNull);
      expect(a['reportPath'], isNot(b['reportPath']));
    },
  );

  test("the config handed to the mutation child lists exactly the feature's "
      'registered subjects', () async {
    await runAudit(featureB);

    final marker = childMarker();
    expect(marker, isNotNull, reason: 'the mutation child must run');
    final configText = File(
      marker!.readAsStringSync().trim(),
    ).readAsStringSync();

    expect(_configFiles(configText), [
      'lib/tdd/$featureB/u1_subject.dart',
      'lib/tdd/$featureB/u2_subject.dart',
    ]);
    expect(
      configText,
      isNot(contains(featureA)),
      reason: "another feature's subjects must never be in this scope",
    );
  });

  test(
    'a config replaced by another run is refused before the child starts',
    () async {
      // The foreign scope another run would have written: another
      // feature's registered subjects.
      File(p.join(tmpDir.path, 'foreign-config.xml')).writeAsStringSync(
        '<mutations version="1.0">\n'
        '  <files>\n'
        '    <file>lib/tdd/$featureA/u1_subject.dart</file>\n'
        '    <file>lib/tdd/$featureA/u2_subject.dart</file>\n'
        '  </files>\n'
        '  <commands>\n'
        '    <command group="test" expected-return="0" '
        'working-directory=".">dart test {file}</command>\n'
        '  </commands>\n'
        '</mutations>\n',
      );

      final report = await runAudit(featureB, clobber: true);

      // The child never ran: no foreign file was mutated.
      expect(
        childMarker(),
        isNull,
        reason:
            'the mutation child must not start on a config that lists '
            "another feature's subjects",
      );

      // And nothing foreign was published.
      expect(report['gate'], 'not_assessed');
      expect(
        report['reason'],
        contains('registered subjects'),
        reason: 'the verdict must name the scope mismatch',
      );
    },
  );
}

/// The `<file>` entries of a scoped mutation config.
List<String> _configFiles(String configText) => RegExp(
  r'<file>(.*?)</file>',
  dotAll: true,
).allMatches(configText).map((m) => m.group(1)!.trim()).toList();
