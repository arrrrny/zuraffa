import 'package:zorphy_annotation/zorphy_annotation.dart'
    show ZorphyIntentBase, ZorphyStateBase;

import '../context/zfa_context.dart';
import '../failure.dart';
import '../middleware/telemetry_cost_middleware.dart' show zfaIntentDigest;
import '../reactions/zfa_reaction_bus.dart';
import '../result.dart';
import '../signals/zfa_signal.dart';
import '../signals/zfa_state_signal.dart';

/// The lean v8 controller: a typed `dispatch(ZorphyIntent, ZfaContext)` loop
/// over a pair of reactive state signals, replacing the multi-method
/// `Controller` + redundant `Presenter` ceremony.
///
/// A [ZfaController] owns exactly two reactive slices — the generated
/// [domainState] (`D`) and the transient [uiState] (`U`) — and a single entry
/// point, [dispatch], that runs an intent through a [runner] (and, when a
/// [ZfaReactionBus] is supplied, the bus's choreography) under a derived
/// [ZfaContext].
///
/// ## Execution loop
///
/// [dispatch]:
///
/// 1. derives an active context from the caller's [ZfaContext] (or a fresh
///    root), and — when a [sourceContractId] is given — opens a child
///    [TelemetrySpan] and stamps the id into both the span `attributes` and the
///    context [ZfaContext.baggage], so every use case and reaction in the
///    cascade can read it;
/// 2. records the intent's canonical `intentDigest()` in [inFlightIntentDigests]
///    for the duration of the run (intents without replay metadata are still
///    dispatched, just not tracked);
/// 3. executes the runner (or the reaction bus around it) and returns its
///    [Result];
/// 4. clears the in-flight digest when the run settles.
///
/// ## Ownership & cancellation
///
/// Pass an [owner] to bind both signals to it: [ZfaSignal.disposeOwner] then
/// disposes the signals and — through the controller's dispose hook — cancels
/// every context still active in flight, so a disposed owner never leaves a
/// use case running against a dead scope. [dispose] does the same explicitly.
///
/// ## Strict Chord rule
///
/// The controller carries no repositories, database handles or HTTP clients.
/// The [runner] is the only thing that touches the outside world, and it
/// receives the derived [ZfaContext] explicitly.
class ZfaController<D extends ZorphyStateBase, U extends ZorphyStateBase> {
  /// Create a controller over an initial [initialDomain] and [initialUi] state.
  ///
  /// [runner] executes one intent under a context and returns its [Result]; it
  /// is the same shape a [ZfaReactionBus] expects, so a single runner serves
  /// both the direct and the choreographed path. When [bus] is given, [dispatch]
  /// runs the intent through it. Bind both signals to [owner] to tie their
  /// lifetime (and the cancellation of in-flight work) to it.
  ZfaController({
    required D initialDomain,
    required U initialUi,
    required ReactionRunner runner,
    ZfaReactionBus? bus,
    Object? owner,
  }) : _runner = runner,
       _bus = bus,
       domainState = ZfaStateSignal<D>(initialDomain, owner: owner),
       uiState = ZfaStateSignal<U>(initialUi, owner: owner) {
    // When the owner disposes the domain signal, cancel any in-flight context
    // so no use case keeps running against a dead scope. The hook is idempotent
    // with [dispose] (both funnel through [_cancelActiveContexts]).
    domainState.onDispose(_cancelActiveContexts);
  }

  final ReactionRunner _runner;
  final ZfaReactionBus? _bus;

  /// The generated domain state slice.
  final ZfaStateSignal<D> domainState;

  /// The transient UI state slice.
  final ZfaStateSignal<U> uiState;

  final Set<String> _inFlightIntentDigests = <String>{};
  final Set<ZfaContext> _activeContexts = <ZfaContext>{};
  bool _disposed = false;

  /// The canonical digests of the intents currently executing.
  ///
  /// A digest is present for the whole duration of its [dispatch] and removed
  /// once the run settles. Intents that expose no `intentDigest()` are not
  /// tracked here.
  Set<String> get inFlightIntentDigests =>
      Set<String>.unmodifiable(_inFlightIntentDigests);

  /// Replace the UI state with [updater]'s result.
  void patchUiState(U Function(U current) updater) {
    uiState.value = updater(uiState.value);
  }

  /// Replace the domain state with [updater]'s result.
  void patchDomainState(D Function(D current) updater) {
    domainState.value = updater(domainState.value);
  }

  /// Dispatch [intent] under a context derived from [ctx] (or a fresh root).
  ///
  /// When [sourceContractId] is given it is propagated into the active
  /// context's span attributes and [ZfaContext.baggage]. The intent's digest is
  /// tracked in [inFlightIntentDigests] while it runs. The runner's (or the
  /// reaction bus's) [Result] is returned unchanged.
  Future<Result<O, AppFailure>> dispatch<I extends ZorphyIntentBase, O>(
    I intent, {
    ZfaContext? ctx,
    String? sourceContractId,
  }) async {
    _assertNotDisposed();
    final base = ctx ?? ZfaContext.root();
    final active = sourceContractId == null
        ? base
        : base.childSpan(
            operation: 'dispatch',
            attributes: {'sourceContractId': sourceContractId},
            baggage: {'sourceContractId': sourceContractId},
          );

    final digest = zfaIntentDigest(intent);
    if (digest != null) _inFlightIntentDigests.add(digest);
    _activeContexts.add(active);
    final Result<Object?, AppFailure> result;
    try {
      final bus = _bus;
      if (bus == null) {
        result = await _runner(intent, active);
      } else {
        result = await bus.run(intent, runner: _runner, context: active);
      }
    } finally {
      _activeContexts.remove(active);
      if (digest != null) _inFlightIntentDigests.remove(digest);
    }
    return result.fold(
      (value) => Result<O, AppFailure>.success(value as O),
      (failure) => Result<O, AppFailure>.failure(failure),
    );
  }

  /// Cancel every in-flight context and dispose both state signals.
  ///
  /// Idempotent. Also invoked automatically when an [owner] disposes the
  /// signals it was bound to.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelActiveContexts();
    domainState.dispose();
    uiState.dispose();
  }

  void _cancelActiveContexts() {
    for (final context in _activeContexts.toList(growable: false)) {
      context.cancellation.cancel('ZfaController disposed');
    }
    _activeContexts.clear();
  }

  void _assertNotDisposed() {
    if (_disposed) throw StateError('ZfaController has been disposed.');
  }
}
