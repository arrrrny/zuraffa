/// World certification (spec 968): the framework proves the world's
/// mocks satisfy the declared contracts — never self-graded.
///
/// [WorldCertifier] invokes EVERY declared contract method through a
/// fresh world runtime (certification mode: the failure schedule is
/// held back — storms are behavioral semantics the scenario program
/// exercises, not contract violations) and checks the world can serve
/// each method:
///
/// - a declared `void` method must complete and return nothing;
/// - a declared type-returning method must serve a non-null response
///   (the corpus fixture or the certified adapter's record);
/// - `firebase-auth` touchpoints dispatch through the #832 certified
///   `FirebaseAuthAdapter` — the world composes the mocks the framework
///   already certifies, and the certification evidence records that
///   composition.
///
/// The proof is EXECUTED by the framework (`zfa simulate init` /
/// `certify` / `run`), never asserted by the agent: the receipt records
/// per-method `satisfied` + evidence + the world hash, and a red
/// certification refuses to run the scenario (issue #968: "World
/// certification: the framework proves the world's mocks satisfy the
/// declared contracts — never self-graded").
///
/// The receipt lives at
/// `specs/<feature>/tdd/worlds/<scenario>.cert.json` — committed next to
/// the manifest, diffable, and hash-bound: `simulate run` / `verify-world`
/// recompute the manifest's world hash and refuse when it no longer
/// matches the certified one (a mutated world invalidates its receipts).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'world_manifest.dart';
import 'world_runtime.dart';
import 'world_utils.dart';

/// One method's proof outcome.
final class WorldMethodProof {
  const WorldMethodProof({
    required this.touchpoint,
    required this.method,
    required this.satisfied,
    required this.evidence,
  });

  final String touchpoint;
  final String method;
  final bool satisfied;

  /// What the invocation proved (shape, adapter dispatch, corpus).
  final String evidence;

  Map<String, dynamic> toJson() => {
    'touchpoint': touchpoint,
    'method': method,
    'satisfied': satisfied,
    'evidence': evidence,
  };
}

/// The certification outcome for one world.
final class WorldCertification {
  const WorldCertification({
    required this.scenario,
    required this.worldHash,
    required this.certified,
    required this.proofs,
    required this.at,
  });

  final String scenario;

  /// The certified world's hash (binds the receipt to the exact world
  /// version).
  final String worldHash;

  final bool certified;
  final List<WorldMethodProof> proofs;

  /// ISO-8601 UTC — when the LIVE proof executed.
  final String at;

  Map<String, dynamic> toDocument() => {
    'schema': 1,
    'spec': 968,
    'scenario': scenario,
    'world_hash': worldHash,
    'certified': certified,
    'at': at,
    'methods': [for (final proof in proofs) proof.toJson()],
  };

  String toFileContents() =>
      '${const JsonEncoder.withIndent('  ').convert(toDocument())}\n';
}

/// The world certifier: proves declared contracts by invocation.
final class WorldCertifier {
  const WorldCertifier();

  /// Certify [manifest]: every declared method invoked through a fresh
  /// runtime with the failure schedule held back (certification mode).
  Future<WorldCertification> certify(WorldManifest manifest) async {
    // Certification mode: the same corpus/contracts/latency, no storms —
    // storms are the scenario's behavioral semantics, not the contract.
    final stormFree = WorldManifest(
      schema: manifest.schema,
      spec: manifest.spec,
      scenario: manifest.scenario,
      feature: manifest.feature,
      version: manifest.version,
      seed: manifest.seed,
      touchpoints: manifest.touchpoints,
      latency: manifest.latency,
      storms: const [],
      corpus: manifest.corpus,
      behaviors: const [],
      description: manifest.description,
    );
    final runtime = WorldRuntime(stormFree);
    final proofs = <WorldMethodProof>[];

    for (final touchpoint in manifest.touchpoints) {
      for (final method in touchpoint.methods) {
        proofs.add(await _prove(runtime, touchpoint, method));
      }
    }

    return WorldCertification(
      scenario: manifest.scenario,
      worldHash: manifest.worldHash,
      certified: proofs.isNotEmpty && proofs.every((x) => x.satisfied),
      proofs: proofs,
      at: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<WorldMethodProof> _prove(
    WorldRuntime runtime,
    WorldTouchpoint touchpoint,
    ContractMethod method,
  ) async {
    final certId = 'cert:${touchpoint.name}.${method.name}';
    try {
      final result = await runtime.invoke(
        certId,
        touchpoint.name,
        method.name,
        _argsFor(touchpoint, method),
      );
      final shape = shapeOf(result);
      if (method.returns == 'void') {
        return WorldMethodProof(
          touchpoint: touchpoint.name,
          method: method.name,
          satisfied: result == null,
          evidence: result == null
              ? 'completed, served void'
              : 'declared void but served $shape',
        );
      }
      if (result == null) {
        return WorldMethodProof(
          touchpoint: touchpoint.name,
          method: method.name,
          satisfied: false,
          evidence:
              'no corpus fixture served for declared return '
              '${method.returns} --> fix: add corpus."${touchpoint.name}".'
              '"${method.name}".fixture to the world manifest.',
        );
      }
      final composed = touchpoint.family == 'firebase-auth'
          ? ' (dispatched through the certified FirebaseAuthAdapter)'
          : '';
      return WorldMethodProof(
        touchpoint: touchpoint.name,
        method: method.name,
        satisfied: true,
        evidence:
            'served $shape for declared return '
            '${method.returns}$composed',
      );
    } catch (e) {
      return WorldMethodProof(
        touchpoint: touchpoint.name,
        method: method.name,
        satisfied: false,
        evidence: 'invocation failed: $e',
      );
    }
  }

  /// Deterministic invocation arguments derived from the certified
  /// worlds: the auth family uses the certified credential; everything
  /// else uses declared param names with placeholder scalars (the proof
  /// is that the world SERVES the contract, not that the args are
  /// meaningful).
  static Map<String, dynamic> _argsFor(
    WorldTouchpoint touchpoint,
    ContractMethod method,
  ) {
    if (touchpoint.family == 'firebase-auth' &&
        const {'signIn', 'register'}.contains(method.name)) {
      return const {'email': 'ada@example.com', 'password': 's3cret!'};
    }
    return {
      for (final param in method.params)
        param: _placeholderFor(param, method.name),
    };
  }

  static dynamic _placeholderFor(String param, String method) =>
      switch (param.toLowerCase()) {
        'email' => 'ada@example.com',
        'password' => 's3cret!',
        'cursor' => 'c-0',
        'count' || 'limit' || 'quantity' || 'take' => 10,
        'batch' || 'items' || 'data' => const <String, dynamic>{},
        _ => 'placeholder:$param',
      };
}

/// Load the committed certification receipt for [scenario] under
/// [worldsDir]. Returns `null` when absent (never certified).
WorldCertification? loadWorldCertification(String worldsDir, String scenario) {
  final file = File(p.join(worldsDir, '$scenario.cert.json'));
  if (!file.existsSync()) return null;
  try {
    final doc = jsonDecode(file.readAsStringSync());
    if (doc is! Map<String, dynamic>) return null;
    return WorldCertification(
      scenario: doc['scenario'] as String? ?? '',
      worldHash: doc['world_hash'] as String? ?? '',
      certified: doc['certified'] as bool? ?? false,
      proofs: (doc['methods'] as List? ?? const [])
          .map(
            (m) => WorldMethodProof(
              touchpoint: (m as Map)['touchpoint'] as String? ?? '',
              method: m['method'] as String? ?? '',
              satisfied: m['satisfied'] as bool? ?? false,
              evidence: m['evidence'] as String? ?? '',
            ),
          )
          .toList(growable: false),
      at: doc['at'] as String? ?? '',
    );
  } on FormatException {
    return null;
  }
}

/// The SHA-256 digest of a declared contract string (certification
/// provenance: the receipt binds the exact contract text).
String contractDigestOf(String contract) =>
    crypto.sha256.convert(utf8.encode(contract)).toString();
