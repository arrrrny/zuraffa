import 'dart:io';

import 'package:test/test.dart';

import '../helpers/project_root.dart';

/// Regression guard for .specify/bugs/rebuild-stale-binary.
///
/// `scripts/rebuild.sh` must fully invalidate build caches so the installed
/// `zfa` binary always reflects current source. A partial cleanup
/// (only `.dart_tool/build_cache`, `hooks_runner`, `pub/bin`) left a stale
/// `dart build cli` artifact in place, making zfa run pre-fix code after a
/// source change — which produced a false roadblock during the zikzak_demo
/// smoke test.
void main() {
  test('rebuild.sh fully invalidates build + .dart_tool caches', () async {
    // Resolve via package URI so this test is immune to CWD pollution when
    // other test files concurrently change Directory.current.
    final root = await findProjectRoot();
    final script = File('$root/scripts/rebuild.sh');
    expect(
      script.existsSync(),
      isTrue,
      reason: 'scripts/rebuild.sh must exist at the repo root',
    );

    final content = script.readAsStringSync();

    // Full invalidation must be present.
    expect(
      content,
      contains('rm -rf build .dart_tool'),
      reason:
          'rebuild.sh must fully clear build + .dart_tool so the installed '
          'zfa binary reflects current source.',
    );

    // The old partial-only cleanup must not be the mechanism (it caused stale
    // binaries). Assert the specific partial lines are gone.
    expect(
      content,
      isNot(contains('rm -rf .dart_tool/build_cache')),
      reason:
          'Partial .dart_tool/build_cache cleanup alone caused stale '
          'binaries; use the full `rm -rf build .dart_tool` clean.',
    );
    expect(
      content,
      isNot(contains('rm -rf .dart_tool/hooks_runner')),
      reason:
          'Partial .dart_tool/hooks_runner cleanup alone caused stale '
          'binaries; use the full `rm -rf build .dart_tool` clean.',
    );
  });
}
