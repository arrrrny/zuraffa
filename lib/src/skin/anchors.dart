/// Typed anchor protocol (issue #1102, pilot lessons 6 + 7; the
/// on-ramp to #1099's identified components).
///
/// Lesson 6 — anchor identity needs to be TYPED: the pilot
/// identified anchors via `ValueKey('zfa:signin-*')` string
/// conventions and dynamic onPressed reads. The productized
/// protocol fixes the vocabulary (`ZfaAnchors`) and the registry
/// (`ZfaAnchorRegistry`), and the emitted `ZfaButton`
/// (`contractId` / `contractEnabled`) turns the protocol into types.
///
/// Lesson 7 — drive skins through the Dart VM service, not
/// synthetic clicks: on macOS, cliclick/CGEvent clicks never reach
/// the Flutter view. What works is `vm_service` evaluate finding the
/// `zfa:` anchor and invoking the REAL onPressed —
/// [ZfaAnchorRegistry.tap] is exactly that seam, exposed to the VM
/// service as the emitted `debugTapAnchor(String zfaKey)` function.
library;

/// The verdict of a driver tap (issue #1112) — the rich answer the
/// old `bool` could never give. The JSON shape
/// `{"result":"found","tapped":true}` is THE cross-surface contract:
/// the live-app driver (`zfa skin drive`), the emitted
/// `debugTapAnchor`, the widget-test bridge (`zfaAnchorTapped`), and
/// the simulator (`zfa skin sim`) all speak it, on every host OS.
sealed class TapResult {
  const TapResult();

  /// The four verdicts, in the issue's vocabulary:
  /// `TapResult = found | disabled | notFound | error(String)`.
  static const TapResult found = TapFound();
  static const TapResult disabled = TapDisabled();
  static const TapResult notFound = TapNotFound();
  static TapResult error(String message) => TapError(message);

  /// The verdict name — the JSON `result` value.
  String get name;

  /// Whether the anchor was found AND its real onPressed invoked.
  bool get tapped => this is TapFound;

  /// The cross-surface JSON envelope (no `message` key unless an
  /// error carries one).
  Map<String, Object?> toJson() {
    final json = <String, Object?>{'result': name, 'tapped': tapped};
    final message = this is TapError ? (this as TapError).message : null;
    if (message != null) json['message'] = message;
    return json;
  }

  /// Restores a verdict from its JSON envelope (driver/sim receipts).
  static TapResult fromJson(Map<String, Object?> json) {
    final name = json['result'];
    if (name == 'found') return TapResult.found;
    if (name == 'disabled') return TapResult.disabled;
    if (name == 'notFound') return TapResult.notFound;
    if (name == 'error') return TapResult.error('${json['message'] ?? ''}');
    return TapResult.error('unknown TapResult verdict: $name');
  }

  @override
  bool operator ==(Object other) =>
      other is TapResult && other.toJson().toString() == toJson().toString();

  @override
  int get hashCode => toJson().toString().hashCode;

  @override
  String toString() {
    final message = this is TapError ? (this as TapError).message : null;
    return message == null
        ? 'TapResult.${name}'
        : 'TapResult.${name}($message)';
  }
}

/// The anchor was found, enabled, and its REAL onPressed ran.
class TapFound extends TapResult {
  const TapFound();

  @override
  String get name => 'found';
}

/// The anchor is mounted but inert (contractEnabled=false or a null
/// onPressed) — present, honest, untappable.
class TapDisabled extends TapResult {
  const TapDisabled();

  @override
  String get name => 'disabled';
}

/// No such anchor in the tree/registry — the driver refuses to
/// pretend.
class TapNotFound extends TapResult {
  const TapNotFound();

  @override
  String get name => 'notFound';
}

/// The tap could not be performed (release build, walk failure, a
/// throwing handler) — carries the reason.
class TapError extends TapResult {
  const TapError(this.message);

  /// Why the tap could not be performed.
  final String message;

  @override
  String get name => 'error';
}

/// The `zfa:` anchor key vocabulary — the mapping between a
/// component's contract id and the `ValueKey` it carries in the
/// live tree.
abstract final class ZfaAnchors {
  /// The anchor key prefix (the pilot's `zfa:signin-*` convention,
  /// now the protocol).
  static const String prefix = 'zfa:';

  /// The `ValueKey` string a typed anchor with [contractId] carries.
  static String keyFor(String contractId) => '$prefix$contractId';

  /// Whether [key] is an anchor key (`zfa:`-prefixed).
  static bool isAnchorKey(String key) =>
      key.length > prefix.length && key.startsWith(prefix);

  /// The contract id of [keyOrId] — accepts both the bare id and
  /// the `zfa:`-prefixed key.
  static String contractIdOf(String keyOrId) =>
      keyOrId.startsWith(prefix) ? keyOrId.substring(prefix.length) : keyOrId;

  /// Normalizes [keyOrId] to the bare contract id (alias of
  /// [contractIdOf] — the name the driver seam documents).
  static String normalize(String keyOrId) => contractIdOf(keyOrId);
}

/// The anchor → tap-handler registry backing `debugTapAnchor`.
///
/// The emitted `ZfaButton` registers its real `onPressed` under its
/// contract id while mounted; the VM-service driver (or a test lane)
/// invokes it through [tap]. Handlers are plain `void Function()`
/// closures — pure Dart, no Flutter types, so the registry lives in
/// the framework and the driver seam works on every platform.
class ZfaAnchorRegistry {
  final Map<String, _ZfaAnchorHandler> _handlers = {};

  /// Registers [onTap] under [anchorId] (bare id or `zfa:` key —
  /// normalized). Re-registering replaces the handler
  /// (idempotent remounts must not stack callbacks). [enabled]
  /// (issue #1112) records the anchor's live tappable state so the
  /// driver can answer `disabled` instead of a lying no-op; the
  /// legacy two-argument call stays enabled by default.
  void register(String anchorId, void Function() onTap, {bool enabled = true}) {
    _handlers[ZfaAnchors.normalize(anchorId)] = _ZfaAnchorHandler(
      onTap,
      enabled,
    );
  }

  /// Removes the handler for [anchorId] (widget unmount).
  void unregister(String anchorId) {
    _handlers.remove(ZfaAnchors.normalize(anchorId));
  }

  /// The rich verdict for [anchorId] (issue #1112): found (and tap)
  /// / disabled / notFound — the exact mapping the emitted
  /// `debugTapAnchor` and `zfa skin drive` surface.
  TapResult tapResult(String anchorId) {
    final handler = _handlers[ZfaAnchors.normalize(anchorId)];
    if (handler == null) return const TapNotFound();
    if (!handler.enabled) return const TapDisabled();
    handler.onTap();
    return const TapFound();
  }

  /// Invokes the registered handler. Returns whether the anchor was
  /// found AND tapped (an unknown anchor refuses honestly — the
  /// driver harness must never silently no-op). A disabled anchor is
  /// never invoked.
  bool tap(String anchorId) => tapResult(anchorId) is TapFound;

  /// The registered anchor ids, sorted (driver diagnostics).
  List<String> get registered {
    final ids = _handlers.keys.toList()..sort();
    return List.unmodifiable(ids);
  }

  /// Drops every handler (test-lane teardown).
  void clear() => _handlers.clear();
}

/// One registered anchor: the real handler plus its live tappable
/// state (issue #1112 — the `disabled` verdict needs both).
class _ZfaAnchorHandler {
  const _ZfaAnchorHandler(this.onTap, this.enabled);

  final void Function() onTap;
  final bool enabled;
}
