/// Deterministic test-runner transcripts (CI reporter drift).
///
/// package:test silently switches to its `github` reporter when
/// `GITHUB_ACTIONS=true` (set on every Actions runner). The github
/// reporter emits no compact `mm:ss +N:` progress lines — which
/// [determines the executed test count](`parseExecutedTestCount`) and
/// the red-classifier transcript grammar depend on — and injects
/// `::group::` / `::error` markers that the load-failure classifier
/// reads as CFE noise. The result: TDD subprocess verdicts that differ
/// between a laptop and CI (spec-fuzz mutants `notAssessed`,
/// `testCount: null` in runner regressions).
///
/// [withCompactReporter] pins `--reporter compact` on every spawned
/// `dart test` / `flutter test` invocation so transcripts look the same
/// everywhere. Templates that already carry a reporter flag win.
List<String> withCompactReporter(List<String> tokens) {
  if (tokens.length < 2) return tokens;
  final command = tokens[1];
  if (command != 'test') return tokens;
  final executable = tokens.first;
  if (!executable.endsWith('dart') && !executable.endsWith('flutter')) {
    return tokens;
  }
  final args = tokens.skip(2).toList(growable: false);
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--reporter' || arg == '-r') return tokens;
    if (arg.startsWith('--reporter=')) return tokens;
    if (arg.startsWith('-r') && arg.length > 2) return tokens;
    if (arg == '--') break; // everything after `--` is positional data
  }
  return [executable, command, '--reporter', 'compact', ...args];
}
