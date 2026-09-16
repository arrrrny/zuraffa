// Spec 1653 (PR #1678 review fixes) — test-side gate seed.
//
// The `zfa graphql` family is gated behind `PluginGate.refusalFor('graphql')`:
// execution requires the capability to be enabled (`.zfa.json`
// `capabilities.graphql: true`) AND resolvable (the companion package listed
// in `.dart_tool/package_config.json`). Suites that drive the gated commands
// need both conditions true in `Directory.current` — which during `dart test`
// is the zuraffa repo root, where no capability is enabled.
//
// [seedGraphqlGate] builds a throwaway project with both conditions seeded
// and switches the process CWD into it. `Directory.current` is VM-wide, so
// the switch is serialized through the same cross-isolate CWD lock CliRunner
// uses (issue #1096): acquire before the chdir, release after the restore.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'cwd_mutex.dart';

/// A seeded gate sandbox created by [seedGraphqlGate].
class GraphqlGateSandbox {
  GraphqlGateSandbox({required this.directory, required this.previousCwd});

  /// The throwaway project the gate reads as enabled + resolvable.
  final Directory directory;

  /// The CWD to restore when the test finishes.
  final String previousCwd;
}

/// Seeds an enabled + resolvable graphql capability and switches
/// [Directory.current] to the sandbox. Pair with
/// [restoreGraphqlGate] in `addTearDown`.
Future<GraphqlGateSandbox> seedGraphqlGate() async {
  await CwdMutex.acquire();
  final sandbox = Directory.systemTemp.createTempSync('zfa_gate_seed_');
  File(p.join(sandbox.path, '.zfa.json')).writeAsStringSync(
    jsonEncode({
      'capabilities': {'graphql': true},
    }),
  );
  final dotTool = Directory(p.join(sandbox.path, '.dart_tool'))
    ..createSync(recursive: true);
  File(p.join(dotTool.path, 'package_config.json')).writeAsStringSync(
    jsonEncode({
      'configVersion': 2,
      'packages': [
        {
          'name': 'zuraffa_graphql',
          'rootUri': 'file:///x/zuraffa_graphql',
          'languageVersion': '3.11',
        },
      ],
    }),
  );
  final previousCwd = Directory.current.path;
  Directory.current = sandbox.path;
  return GraphqlGateSandbox(directory: sandbox, previousCwd: previousCwd);
}

/// Restores what [seedGraphqlGate] changed: the CWD, the CWD lock
/// (release-after-restore, mirroring CliRunner), and the sandbox itself.
void restoreGraphqlGate(GraphqlGateSandbox sandbox) {
  Directory.current = sandbox.previousCwd;
  try {
    sandbox.directory.deleteSync(recursive: true);
  } on FileSystemException {
    // Best-effort cleanup — a leftover temp dir must not fail the suite.
  }
  CwdMutex.release();
}
