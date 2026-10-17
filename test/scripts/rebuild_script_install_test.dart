import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

/// Regression guard for issue #1744.
///
/// `scripts/rebuild.sh` used to `cp build/zfa_bundle/bundle/bin/zfa`
/// straight onto `$INSTALL_DIR/zfa`, never compare the installed bytes with
/// the artifact it had just built, never smoke-test the installed binary, and
/// print `✅ Rebuild complete` no matter what. The issue hit exactly that: the
/// installed `zfa` differed from its own bundle by a single ~4 KB window,
/// `zfa --version` then spun at ~43% CPU for 8+ minutes and died with
/// `SEGV_MAPERR`, and the script still reported success.
///
/// The install path must therefore: (1) stage the copy in a sibling temp file,
/// (2) prove it is byte-identical to the built artifact with `cmp -s`, (3)
/// rename it into place (never an in-place `cp` onto the live path), and (4)
/// smoke-test the installed `zfa --version` under a bounded budget BEFORE the
/// success banner, failing the rebuild otherwise.
void main() {
  test(
    'rebuild.sh stages, byte-verifies and atomically renames the install',
    () async {
      final root = await findProjectRoot();
      final script = File('$root/scripts/rebuild.sh');
      expect(
        script.existsSync(),
        isTrue,
        reason: 'scripts/rebuild.sh must exist at the repo root',
      );
      final content = script.readAsStringSync();

      expect(
        content,
        contains('install_binary_atomically'),
        reason: 'the install must go through a shared atomic-install helper',
      );
      expect(
        content,
        contains('cmp -s'),
        reason:
            'the staged copy must be compared byte-for-byte against the built '
            'artifact before it replaces the installed binary',
      );
      expect(
        content,
        contains('mv -f "\$tmp" "\$dest"'),
        reason:
            'the verified temp file must be renamed into place — a rename is '
            'atomic, an in-place cp can be observed half-written',
      );
      expect(
        content,
        isNot(
          contains('cp build/zfa_bundle/bundle/bin/zfa "\$INSTALL_DIR/zfa"'),
        ),
        reason: 'the old non-atomic direct cp install must be gone',
      );

      // The smoke check must be bounded (perl `alarm`, since stock macOS has no
      // `timeout(1)`) and must run before the success banner is printed.
      expect(
        content,
        contains('alarm'),
        reason: 'the smoke check must bound the zfa --version wall clock',
      );
      // Anchor both markers to CODE text: a bare `--version` / `Rebuild
      // complete` also appears in the surrounding comment prose, so the
      // assertion could otherwise be satisfied by the comments' own order
      // while the smoke-check code moved below the banner.
      final smokeIndex = content.indexOf('alarm shift');
      final bannerIndex = content.indexOf('echo "✅ Rebuild complete');
      expect(
        smokeIndex,
        greaterThan(-1),
        reason: 'the perl smoke-check invocation must be present in the script',
      );
      expect(
        bannerIndex,
        greaterThan(-1),
        reason: 'the success banner must be present in the script',
      );
      expect(
        smokeIndex,
        lessThan(bannerIndex),
        reason:
            'the zfa --version smoke check must run before "✅ Rebuild '
            'complete" is printed',
      );
    },
  );

  test('rebuild.sh fails loudly when the built zfa cannot run '
      '(issue #1744: it used to print "Rebuild complete" regardless)', () async {
    final sandbox = await Directory.systemTemp.createTemp(
      'rebuild-install-1744-',
    );
    addTearDown(() => sandbox.delete(recursive: true));

    // A fake `dart` whose "build" produces a bundle holding a zfa that cannot
    // run — the state the issue hit (installed binary is not a working bundle)
    // that the old script copied blind and then declared a successful rebuild.
    final bin = Directory('${sandbox.path}/bin')..createSync();
    final dartStub = File('${bin.path}/dart')
      ..writeAsStringSync('''
#!/bin/bash
set -e
args="\$*"
case "\$args" in
  "pub get"*) exit 0 ;;
  *zfa_bundle*)
    mkdir -p build/zfa_bundle/bundle/bin
    cat > build/zfa_bundle/bundle/bin/zfa <<'ZFA_STUB'
#!/bin/bash
# A "broken" install whose smoke check must still actually execute this file:
# record that it ran, then fail. Without the marker the failure-path test could
# pass because the rebuild aborted before ever reaching the smoke check.
if [ -n "\$ZFA_SMOKE_MARKER" ]; then
  echo "smoke-check-ran" >> "\$ZFA_SMOKE_MARKER"
fi
exit 1
ZFA_STUB
    chmod +x build/zfa_bundle/bundle/bin/zfa
    exit 0 ;;
  *mcp_server_bundle*)
    mkdir -p build/mcp_server_bundle/bundle/bin
    printf '#!/bin/bash\\nexit 0\\n' > build/mcp_server_bundle/bundle/bin/zuraffa_mcp_server
    chmod +x build/mcp_server_bundle/bundle/bin/zuraffa_mcp_server
    exit 0 ;;
esac
exit 0
''');
    Process.runSync('chmod', ['+x', dartStub.path]);

    final root = await findProjectRoot();
    final scriptsDir = Directory('${sandbox.path}/scripts')..createSync();
    File('$root/scripts/rebuild.sh').copySync('${scriptsDir.path}/rebuild.sh');

    final result = await Process.run(
      'bash',
      ['${scriptsDir.path}/rebuild.sh'],
      workingDirectory: sandbox.path,
      environment: {
        ...Platform.environment,
        'PATH': '${bin.path}:${Platform.environment['PATH']}',
        'ZURAFFA_BIN': '${sandbox.path}/install',
        'ZFA_SMOKE_MARKER': '${sandbox.path}/smoke.marker',
      },
    );

    final smokeMarker = File('${sandbox.path}/smoke.marker');
    expect(
      smokeMarker.existsSync(),
      isTrue,
      reason:
          'the smoke check must actually run the installed zfa — the fake '
          'zfa records its own execution',
    );
    expect(
      result.exitCode,
      isNot(0),
      reason: 'a bundle whose zfa cannot run must fail the rebuild',
    );
    expect(
      result.stdout.toString(),
      isNot(contains('Rebuild complete')),
      reason: 'the success banner must not print when the smoke check fails',
    );
  });
}
