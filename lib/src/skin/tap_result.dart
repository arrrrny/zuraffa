/// TapResult — the typed verdict of the debugTapAnchor drive seam
/// (issue #1112, pilot lesson 7).
///
/// The pilot proved the seam: synthetic clicks (cliclick, CGEvent,
/// AX press) never reach the Flutter macOS view, but
/// `package:vm_service.evaluate` finding the `zfa:` anchor and
/// invoking its REAL onPressed works — the genuine engine flow
/// (presenter → certified mock → push). The verdict vocabulary is
/// intentionally tiny and JSON-shaped so `zfa skin drive` can print
/// the SAME envelope on every host OS — sub-agent friendly:
///
/// ```json
/// {"result":"found","tapped":true}
/// {"result":"disabled","tapped":false}
/// {"result":"notFound","tapped":false}
/// {"result":"error","tapped":false,"message":"..."}
/// ```
///
/// Pure Dart (Constitution VII) — the emitted kit (Flutter glue)
/// constructs these; the `zfa skin drive` CLI parses and prints
/// them; both resolve the type from `package:zuraffa/skin.dart`.
library;

import 'dart:convert';

/// The sealed verdict of a [debugTapAnchor] drive.
sealed class TapResult {
  const TapResult();

  /// The issue vocabulary: `found | disabled | notFound | error`.
  String get label => switch (this) {
    TapFound() => 'found',
    TapDisabled() => 'disabled',
    TapNotFound() => 'notFound',
    TapError() => 'error',
  };

  /// The canonical JSON map the CLI prints verbatim.
  Map<String, Object?> toJson() => switch (this) {
    TapFound() => {'result': 'found', 'tapped': true},
    TapDisabled() => {'result': 'disabled', 'tapped': false},
    TapNotFound() => {'result': 'notFound', 'tapped': false},
    TapError(:final message) => {
      'result': 'error',
      'tapped': false,
      'message': message,
    },
  };

  /// The exact bytes `zfa skin drive` emits as its final stdout line.
  String toJsonString() => jsonEncode(toJson());

  /// Restores a verdict from the JSON envelope (round trips with
  /// [toJson]). An unknown shape refuses honestly as [TapError].
  static TapResult fromJson(Map<String, Object?> json) {
    switch (json['result']) {
      case 'found':
        return const TapFound();
      case 'disabled':
        return const TapDisabled();
      case 'notFound':
        return const TapNotFound();
      case 'error':
        final message = json['message'];
        return TapError(message is String ? message : 'unknown driver error');
      default:
        return TapError('unknown TapResult envelope: $json');
    }
  }

  /// Parses the string form the VM-service evaluate returns.
  static TapResult fromJsonString(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic>
          ? TapResult.fromJson(decoded)
          : TapError('seam returned a non-object payload: $source');
    } on FormatException catch (e) {
      return TapError('seam returned non-JSON output: ${e.message}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TapResult && other.toJsonString() == toJsonString();

  @override
  int get hashCode => toJsonString().hashCode;

  @override
  String toString() => 'TapResult${toJsonString()}';
}

/// The anchor was found in the live tree and its REAL `onPressed`
/// was invoked (the genuine engine flow starts).
final class TapFound extends TapResult {
  const TapFound();
}

/// The anchor is in the tree but refuses taps right now
/// (`onPressed == null` or `contractEnabled == false`) — discoverable
/// and honest about the refusal.
final class TapDisabled extends TapResult {
  const TapDisabled();
}

/// No element carries the `zfa:<id>` key — an unknown anchor never
/// silently no-ops.
final class TapNotFound extends TapResult {
  const TapNotFound();
}

/// The drive itself failed (connection, walk, or the handler threw).
final class TapError extends TapResult {
  const TapError(this.message);

  /// What went wrong — the only data-carrying verdict.
  final String message;
}
