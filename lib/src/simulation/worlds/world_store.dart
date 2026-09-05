/// World scaffolding + file layout (spec 968): where worlds live on
/// disk and how `zfa simulate init` composes a world manifest from the
/// spec's declared dependency table (issue #960's output).
///
/// Layout (committed, diffable, CI-verifiable):
/// - `specs/<feature>/tdd/worlds/<scenario>.world.json` — the manifest
/// - `specs/<feature>/tdd/worlds/<scenario>.cert.json` — the framework
///   certification receipt (world-hash-bound)
/// - `.zfa/receipts/world-run-<scenario>.json` — the proof-carrying run
///   receipt (local machine artifact; the committed evidence lands in
///   the feature's cycle log)
/// - `specs/<feature>/tdd/world-differential-report.json` — the
///   differential gate report (committed)
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../plugins/tdd/services/cycle_evidence.dart';
import 'world_manifest.dart';

/// Where a feature's worlds live.
String worldsDirOf(String featureDir) => p.join(featureDir, 'tdd', 'worlds');

/// The manifest path for [scenario] under [featureDir].
String worldManifestPath(String featureDir, String scenario) =>
    p.join(worldsDirOf(featureDir), '$scenario.world.json');

/// The certification receipt path for [scenario].
String worldCertPath(String featureDir, String scenario) =>
    p.join(worldsDirOf(featureDir), '$scenario.cert.json');

/// One declared dependency row consumed from the spec's External
/// Dependencies & Contracts table (#960's output shape).
final class DeclaredTouchpointRow {
  const DeclaredTouchpointRow({
    required this.name,
    required this.type,
    required this.contract,
    required this.priority,
  });

  final String name;
  final String type;
  final String contract;
  final String priority;
}

/// The simulation family for a declared dependency name: known
/// certified families resolve by name; everything else is `generic`
/// (corpus-served, contract-pinned).
String familyForDependency(String name) => switch (name) {
  'FirebaseAuth' || 'FirebaseAuthApi' => 'firebase-auth',
  'Vendure' || 'VendureApi' => 'vendure',
  'AdMob' || 'AdMobApi' => 'admob',
  _ => 'generic',
};

/// Scaffold a world manifest for [scenario] from the declared
/// dependency rows: touchpoints (parsed contracts), the time model
/// (seed), certified default latency bands per touchpoint, a default
/// failure-storm schedule (the issue's storm classes for the declared
/// touchpoint shapes), the golden corpus per method, and a default
/// behavior program exercising every method once.
///
/// Deterministic: the same rows + scenario + seed always produce
/// byte-identical manifests.
WorldManifest scaffoldWorld({
  required String scenario,
  required String feature,
  required List<DeclaredTouchpointRow> rows,
  required int seed,
}) {
  final touchpoints = <WorldTouchpoint>[];
  final latency = <String, WorldLatencyBands>{};
  final storms = <WorldStorm>[];
  final corpus = <String, Map<String, dynamic>>{};
  final behaviors = <WorldBehavior>[];

  for (final row in rows) {
    final family = familyForDependency(row.name);
    final methods = ContractParser.parse(row.contract);
    touchpoints.add(
      WorldTouchpoint(
        name: row.name,
        type: row.type,
        family: family,
        priority: row.priority,
        contract: row.contract,
        methods: methods,
      ),
    );
    latency[row.name] = WorldLatencyBands.certified;

    // The golden corpus: the certified families seed from the #832
    // certified worlds; generic touchpoints get a placeholder the
    // developer refines to their golden data (certification only
    // requires the world can serve the contract).
    final corpusEntry = <String, dynamic>{};
    for (final method in methods) {
      corpusEntry[method.name] = {
        'fixture': _defaultFixtureFor(family, method),
      };
    }
    corpus[row.name] = corpusEntry;

    // Default failure-storm schedule per the declared shape (storms
    // are METHOD-SCOPED so mid-flow failures stay surgical — an auth
    // expiry at signIn must not also fail signOut):
    // - auth touchpoints get an auth-expiry storm mid-flow
    // - write-shaped methods get a network-flap storm then a
    //   partial-write storm
    if (family == 'firebase-auth') {
      storms.add(
        WorldStorm(
          name: 'auth-expiry-mid-flow',
          kind: 'auth-expiry',
          touchpoint: row.name,
          method: 'signIn',
          fromCall: 1,
          toCall: 1,
          failure: const {'type': 'auth', 'code': 'user-token-expired'},
          description:
              'the session expires mid-flow — honest consumers surface '
              'it, never blind-retry it',
        ),
      );
    }
    final writeMethod = methods.where(
      (m) => const {
        'push',
        'save',
        'write',
        'update',
        'create',
        'post',
        'sync',
      }.contains(m.name.toLowerCase()),
    );
    for (final method in writeMethod) {
      storms.add(
        WorldStorm(
          name: 'network-flap-${method.name}',
          kind: 'network-flap',
          touchpoint: row.name,
          method: method.name,
          fromCall: 1,
          toCall: 2,
          failure: const {'type': 'http', 'status': 503},
          description:
              'network flaps over the first two ${method.name} calls — '
              'retry-with-backoff must survive',
        ),
      );
      storms.add(
        WorldStorm(
          name: 'partial-write-${method.name}',
          kind: 'partial-write',
          touchpoint: row.name,
          method: method.name,
          fromCall: 4,
          toCall: 4,
          failure: const {'type': 'partial'},
          description:
              'a half-written ${method.name} response — honest syncs '
              'detect and repair',
        ),
      );
    }

    // Default behavior program: exercise every method once; retry-sync
    // drivers for write-shaped methods (the temporal class), invoke for
    // reads. Write methods get TWO temporal behaviors so the default
    // storm schedule is fully rehearsed: the flap storm (retry survives)
    // and the partial-write storm (detect + repair).
    for (final method in methods) {
      final isWrite = const {
        'push',
        'save',
        'write',
        'update',
        'create',
        'post',
        'sync',
      }.contains(method.name.toLowerCase());
      if (isWrite) {
        behaviors.add(
          WorldBehavior(
            id: '${scenario}-${method.name}-retry-sync',
            driver: 'retry-sync',
            touchpoint: row.name,
            method: method.name,
            args: _defaultArgsFor(method),
            maxAttempts: 4,
            backoffBaseMs: 50,
            backoffFactor: 2.0,
          ),
        );
        behaviors.add(
          WorldBehavior(
            id: '${scenario}-${method.name}-partial-write-repair',
            driver: 'retry-sync',
            touchpoint: row.name,
            method: method.name,
            args: _defaultArgsFor(method),
            maxAttempts: 3,
            backoffBaseMs: 50,
            backoffFactor: 2.0,
          ),
        );
      } else {
        behaviors.add(
          WorldBehavior(
            id: '${scenario}-${method.name}',
            driver: 'invoke',
            touchpoint: row.name,
            method: method.name,
            args: _defaultArgsFor(method),
            maxAttempts: 1,
            expect: family == 'firebase-auth' && method.name == 'signIn'
                ? 'red'
                : 'green',
          ),
        );
      }
    }
  }

  return WorldManifest(
    schema: WorldManifest.schemaVersion,
    spec: WorldManifest.specNumber,
    scenario: scenario,
    feature: feature,
    version: 1,
    seed: seed,
    touchpoints: touchpoints,
    latency: latency,
    storms: storms,
    corpus: corpus,
    behaviors: behaviors,
    description:
        'scaffolded by `zfa simulate init` from the declared dependency '
        'table (issue #960); refine the corpus fixtures, latency bands, '
        'and storm windows to your scenario golden reality',
  );
}

dynamic _defaultFixtureFor(String family, ContractMethod method) {
  if (method.returns == 'void') return null;
  if (family == 'firebase-auth' && method.name == 'signIn') {
    return const {
      'uid': 'u-ada-001',
      'email': 'ada@example.com',
      'displayName': 'Ada Lovelace',
    };
  }
  // Generic placeholder: an empty record the developer refines. The
  // certifier only requires a non-null servable response.
  return const <String, dynamic>{};
}

Map<String, dynamic> _defaultArgsFor(ContractMethod method) {
  if (const {'signIn', 'register'}.contains(method.name)) {
    return const {'email': 'ada@example.com', 'password': 's3cret!'};
  }
  return {
    for (final param in method.params)
      param: switch (param.toLowerCase()) {
        'email' => 'ada@example.com',
        'password' => 's3cret!',
        'cursor' => 'c-0',
        'count' || 'limit' || 'quantity' || 'take' => 10,
        'batch' || 'items' || 'data' => const <String, dynamic>{},
        _ => 'placeholder:$param',
      },
  };
}

/// Append a hash-chained world evidence entry to the feature's cycle
/// log (`<featureDir>/tdd/cycle-log.md`), schema-1 chain format — the
/// same format the run driver, doctor, and fixture commitment already
/// parse. [kind] is `world-cert` / `world-run`; [hash] is the entry's
/// chain hash (the world hash for certification, the run digest for
/// runs).
Future<void> appendWorldCycleEvidence({
  required String featureDir,
  required String behaviorId,
  required String kind,
  required String commandLine,
  required String hash,
  required int exitCode,
  required String criterion,
  Map<String, String> extraLines = const {},
}) async {
  final tddDir = Directory(p.join(featureDir, 'tdd'));
  if (!tddDir.existsSync()) tddDir.createSync(recursive: true);
  final file = File(p.join(tddDir.path, 'cycle-log.md'));
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  final cycleEvidence = CycleEvidence(featureDir);
  final prev = await cycleEvidence.lastHashFor(behaviorId) ?? 'genesis';
  final now = DateTime.now().toUtc().toIso8601String();

  final buffer = StringBuffer()
    ..writeln('## $now: $kind (spec 968)')
    ..writeln('- behavior: $behaviorId')
    ..writeln('- kind: $kind')
    ..writeln('- at: $now')
    ..writeln('- exit: $exitCode')
    ..writeln('- criterion: $criterion')
    ..writeln('- command: `$commandLine`')
    ..writeln('- schema: 1')
    ..writeln('- prev-hash: $prev')
    ..writeln('- hash: $hash');
  for (final line in extraLines.entries) {
    buffer.writeln('- ${line.key}: ${line.value}');
  }

  final prefix = existing.isEmpty
      ? '# Cycle log — ${p.basename(p.normalize(featureDir))}\n'
      : (existing.endsWith('\n') ? existing : '$existing\n');
  // Atomic write: write to a temp file then rename to prevent torn reads
  // on concurrent CI runs targeting the same world name.
  final tmp = File('${file.path}.tmp');
  tmp.writeAsStringSync('$prefix\n${buffer.toString()}');
  tmp.renameSync(file.path);
}
