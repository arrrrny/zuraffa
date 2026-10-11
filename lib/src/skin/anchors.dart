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
  final Map<String, void Function()> _handlers = {};

  /// Registers [onTap] under [anchorId] (bare id or `zfa:` key —
  /// normalized). Re-registering replaces the handler
  /// (idempotent remounts must not stack callbacks).
  void register(String anchorId, void Function() onTap) {
    _handlers[ZfaAnchors.normalize(anchorId)] = onTap;
  }

  /// Removes the handler for [anchorId] (widget unmount).
  void unregister(String anchorId) {
    _handlers.remove(ZfaAnchors.normalize(anchorId));
  }

  /// Invokes the registered handler. Returns whether the anchor was
  /// found AND tapped (an unknown anchor refuses honestly — the
  /// driver harness must never silently no-op).
  bool tap(String anchorId) {
    final handler = _handlers[ZfaAnchors.normalize(anchorId)];
    if (handler == null) return false;
    handler();
    return true;
  }

  /// The registered anchor ids, sorted (driver diagnostics).
  List<String> get registered {
    final ids = _handlers.keys.toList()..sort();
    return List.unmodifiable(ids);
  }

  /// Drops every handler (test-lane teardown).
  void clear() => _handlers.clear();
}
