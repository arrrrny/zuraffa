/// UI Render Tool — the agent-facing `ui.render` tool (spec FR-001).
///
/// Accepts a component tree, an optional replacement view identifier, and an
/// optional presentation hint, and returns a success result including a view
/// identifier upon valid input. Validates the tree against the active
/// vocabulary schema (FR-002), records the rendered tree in the mission trace
/// with schema version + content hash (FR-008), and emits streaming render
/// events via the [UiEventChannel] (FR-003).
library;

import 'dart:async';

import 'mission_trace_recorder.dart';
import 'policy_gate.dart';
import 'rendered_view.dart';
import 'semantic_action.dart';
import 'ui_event_channel.dart';
import 'ui_vocabulary_schema.dart';
import 'vocabulary_narrowing.dart';

/// The agent-facing `ui.render` tool (spec FR-001).
class UiRenderTool {
  /// Active vocabulary narrowing config (FR-005).
  final VocabularyNarrowingConfig narrowingConfig;

  /// Base schema used when no narrowing applies.
  final UiVocabularySchema baseSchema;

  /// Streaming event channel (FR-003).
  final UiEventChannel channel;

  /// Mission trace recorder (FR-008).
  final MissionTraceRecorder recorder;

  /// Policy gate for confirm-tier actions (FR-006).
  final PolicyGate policyGate;

  /// Action router delivering semantic actions back to the agent (FR-004).
  final ActionRouter actionRouter;

  /// View id generator — overridable for deterministic tests.
  final String Function() _idGenerator;

  /// Currently active mission type (FR-005). Null = no active mission — the
  /// tool throws `NoActiveMissionException` until one is set.
  String? _activeMissionType;

  /// Active mission type (read-only).
  String? get activeMissionType => _activeMissionType;

  /// Rendered views keyed by view id (used by `replaceViewId` lookups and
  /// last-write-wins semantics for rapid render calls).
  final Map<String, RenderedView> _views = <String, RenderedView>{};

  UiRenderTool({
    this.narrowingConfig = VocabularyNarrowingConfig.empty,
    this.baseSchema = UiVocabularySchema.base,
    UiEventChannel? channel,
    MissionTraceRecorder? recorder,
    PolicyGate? policyGate,
    ActionRouter? actionRouter,
    String Function()? idGenerator,
  })  : channel = channel ?? UiEventChannel(),
        recorder = recorder ?? MissionTraceRecorder(),
        policyGate = policyGate ?? PolicyGate(),
        actionRouter = actionRouter ?? CapturingActionRouter(),
        _idGenerator = idGenerator ?? _defaultIdGenerator;

  static int _idCounter = 0;
  static String _defaultIdGenerator() =>
      'view_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  /// Activate a mission (sets the mission type for vocabulary narrowing).
  /// Passing `null` deactivates the mission (subsequent `render` calls throw
  /// `NoActiveMissionException`).
  void activateMission(String? missionType) {
    _activeMissionType = missionType;
  }

  /// Render a component tree (FR-001).
  ///
  /// [tree] — the component tree to render.
  /// [replaceViewId] — optional id of an existing view to replace. When set,
  ///   the previous view is marked inactive and a `UiRenderEventReplace` is
  ///   emitted; the returned view has the same id as the previous one. When
  ///   the id does not match any known view, `ViewNotFoundException` is
  ///   thrown (spec Edge Cases).
  /// [hint] — optional presentation hint (FR-001).
  ///
  /// Throws [NoActiveMissionException] when no mission is active.
  /// Throws [UiRenderValidationException] when validation fails (FR-002).
  /// Throws [ViewNotFoundException] when `replaceViewId` is unknown.
  RenderedView render(
    UiNode tree, {
    String? replaceViewId,
    String? hint,
  }) {
    final missionType = _activeMissionType;
    if (missionType == null) {
      throw NoActiveMissionException();
    }

    // Resolve the active (possibly narrowed) vocabulary (FR-005).
    final schema = vocabularyNarrowing(
      missionType,
      baseSchema,
      config: narrowingConfig,
    );

    // Validate against the active schema (FR-002).
    final result = schema.validate(tree);
    if (!result.valid) {
      channel.emitError(UiRenderValidationException(result));
      throw UiRenderValidationException(result);
    }

    // Compute content hash (FR-008).
    final contentHash = computeContentHash(tree);

    // Resolve the view id: either reuse the replaced view's id or mint a new
    // one. Mark any prior view with the same id as inactive (last-write-wins
    // for rapid render calls — Edge Cases).
    String viewId;
    if (replaceViewId != null) {
      final existing = _views[replaceViewId];
      if (existing == null) {
        throw ViewNotFoundException(replaceViewId);
      }
      viewId = replaceViewId;
      existing.isActive = false;
    } else {
      viewId = _idGenerator();
    }

    final view = RenderedView(
      viewId: viewId,
      tree: tree,
      schemaVersion: schema.schemaVersion,
      contentHash: contentHash,
      hint: hint,
    );
    _views[viewId] = view;

    // Record in mission trace (FR-008).
    recorder.record(view, missionType: missionType);

    // Emit the render event (FR-001, FR-003). For replace calls, emit a
    // `UiRenderEventReplace`; otherwise emit a `UiRenderEventRender`.
    if (replaceViewId != null) {
      channel.emitReplace(replaceViewId, view);
    } else {
      channel.emitRender(view, isPartial: false);
    }
    channel.emitDone(viewId);

    return view;
  }

  /// Render a component tree progressively via a stream of partial trees
  /// (FR-003 acceptance 3 — "intermediate nodes arrive before the full tree
  /// completes").
  ///
  /// Each partial is emitted as a `UiRenderEventRender` with `isPartial: true`
  /// (except the last, which is `isPartial: false`). The final view returned
  /// by the future is also recorded in the mission trace.
  Stream<RenderedView> renderProgressive(
    Stream<UiNode> partials, {
    String? hint,
  }) async* {
    final missionType = _activeMissionType;
    if (missionType == null) {
      throw NoActiveMissionException();
    }
    final schema = vocabularyNarrowing(
      missionType,
      baseSchema,
      config: narrowingConfig,
    );

    final viewId = _idGenerator();
    RenderedView? lastPartial;
    await for (final partial in partials) {
      final result = schema.validate(partial);
      if (!result.valid) {
        channel.emitError(UiRenderValidationException(result));
        // Drop any partial we stored and close the view so the host does not
        // wait forever for a Done event.
        _views.remove(viewId);
        channel.emitDone(viewId);
        return;
      }
      final contentHash = computeContentHash(partial);
      final view = RenderedView(
        viewId: viewId,
        tree: partial,
        schemaVersion: schema.schemaVersion,
        contentHash: contentHash,
        hint: hint,
      );
      lastPartial = view;
      _views[viewId] = view;
      channel.emitRender(view, isPartial: true);
      yield view;
    }

    // Always close the view (even for an empty partials stream) so the host
    // never blocks awaiting a Done event.
    final finalView = lastPartial;
    if (finalView != null) {
      channel.emitRender(finalView, isPartial: false);
      recorder.record(finalView, missionType: missionType);
    }
    channel.emitDone(viewId);
  }

  /// Route a user interaction captured on a rendered tree back to the agent
  /// (FR-004). If the action is `confirm`-tier, it is intercepted by the
  /// [PolicyGate] (FR-006) and only delivered after approval.
  ///
  /// Returns the action that was actually delivered (or `null` if denied).
  Future<SemanticAction?> routeInteraction(SemanticAction action) async {
    // Stamp the action with the view id so the agent knows which view to
    // update. Fall back to the active (most-recently-rendered active) view
    // rather than the chronologically-last-rendered one, which would
    // mis-attribute an interaction to a different, still-live view in a
    // multi-view mission.
    final stamped = action.viewId == null
        ? action.copyWith(viewId: activeView?.viewId)
        : action;

    // Gate confirm-tier actions (FR-006).
    final approved = await policyGate.intercept(stamped);
    if (approved == null) {
      // Denied — emit a policy event and drop the action (FR-006 acceptance 2).
      channel.emitPolicy(stamped, approved: false);
      return null;
    }
    channel.emitPolicy(approved, approved: true);
    channel.emitInteraction(approved);
    actionRouter.deliver(approved);
    return approved;
  }

  /// Tear down the tool, dropping any undecided `confirm`-tier decisions so a
  /// finished or abandoned mission does not leak pending decisions (FR-006).
  void dispose() {
    policyGate.dispose();
  }

  /// Look up a rendered view by id (returns `null` if unknown or no longer
  /// active).
  RenderedView? view(String viewId) => _views[viewId];

  /// All currently-known views (active and superseded).
  Iterable<RenderedView> get views => _views.values;

  /// Most-recently-rendered active view (or `null`).
  RenderedView? get activeView {
    for (final v in _views.values.toList().reversed) {
      if (v.isActive) return v;
    }
    return null;
  }
}
