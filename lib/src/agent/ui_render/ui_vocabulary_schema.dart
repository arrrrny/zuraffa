/// UI Vocabulary Schema — the canonical definition of allowed component nodes,
/// tokens, and style variants available to the agent. Acts as the single source
/// of truth for validation and tool input shaping (spec FR-002, Key Entities).
library;

/// The risk tier of a semantic action (spec US5 — `confirm`-tier gating).
enum ActionTier { safe, confirm }

/// A data binding attached to a vocabulary node (v2 — agent-renderable UI).
///
/// Binds a node property to a data source path so the renderer can hydrate
/// the node without the agent hand-writing widget trees.
class UiBinding {
  /// Source data path (e.g. `note.title`, `note.isPinned`).
  final String source;

  /// Target property on the node (e.g. `text`, `value`, `visible`).
  final String target;

  /// Optional transform name applied to the bound value.
  final String? transform;

  const UiBinding({required this.source, required this.target, this.transform});

  Map<String, Object?> toJson() => <String, Object?>{
    'source': source,
    'target': target,
    if (transform != null) 'transform': transform,
  };

  factory UiBinding.fromJson(Map<String, Object?> json) => UiBinding(
    source: (json['source'] ?? '').toString(),
    target: (json['target'] ?? '').toString(),
    transform: json['transform']?.toString(),
  );

  @override
  String toString() =>
      'UiBinding($source -> $target${transform == null ? '' : ' via $transform'})';
}

/// A node in an agent-authored component tree.
///
/// The shape is intentionally minimal and pure-Dart: every field is observable
/// over the wire to the host UI. No `package:flutter` types appear here.
class UiNode {
  /// Component type, e.g. `card`, `button`, `text`, `container`.
  ///
  /// Must be present in the active `UiVocabularySchema.allowedNodeTypes`.
  final String type;

  /// Component properties (string→primitive/node refs). Free-form so the
  /// schema can evolve without breaking the runtime; schema validation only
  /// checks node types and style tokens, not prop keys.
  final Map<String, Object?> props;

  /// Child nodes.
  final List<UiNode> children;

  /// Optional style token — must be present in
  /// `UiVocabularySchema.allowedStyleTokens` when non-null.
  final String? styleToken;

  /// Optional semantic action id. When non-null, the host UI treats this node
  /// as interactive; a tap emits a `SemanticAction` with this id (spec FR-004).
  final String? actionId;

  /// Optional action tier override. When null and `actionId` is non-null, the
  /// action defaults to [ActionTier.safe]. Set to [ActionTier.confirm] for
  /// risky actions that must pass through the [PolicyGate] (spec FR-006).
  final ActionTier? actionTier;

  /// Semantic role of this node in the v2 vocabulary (e.g. `container`,
  /// `list`, `detail`, `form`, `field`, `action`). Drives layout rendering
  /// and verification (issue #818).
  final String? role;

  /// Semantic (a11y) label for this node. Verification fails when a role that
  /// requires a label has none, naming the role (issue #818 "Done when").
  final String? label;

  /// Data bindings attached to this node (v2).
  final List<UiBinding> bindings;

  const UiNode({
    required this.type,
    this.props = const <String, Object?>{},
    this.children = const <UiNode>[],
    this.styleToken,
    this.actionId,
    this.actionTier,
    this.role,
    this.label,
    this.bindings = const <UiBinding>[],
  });

  /// Count of all nodes in this subtree (self + descendants).
  ///
  /// Used by the schema validator to enforce the node-count cap (FR-002).
  int get nodeCount => 1 + children.fold<int>(0, (sum, c) => sum + c.nodeCount);

  /// Whether this subtree contains any node with a non-null `actionId`.
  bool get hasInteractive =>
      actionId != null || children.any((c) => c.hasInteractive);

  @override
  String toString() {
    final buf = StringBuffer('UiNode($type');
    if (styleToken != null) buf.write(' style=$styleToken');
    if (actionId != null) buf.write(' action=$actionId');
    if (actionTier != null) buf.write(' tier=$actionTier');
    if (role != null) buf.write(' role=$role');
    if (label != null) buf.write(' label=$label');
    if (bindings.isNotEmpty) buf.write(' bindings=${bindings.length}');
    if (props.isNotEmpty) buf.write(' props=$props');
    if (children.isNotEmpty) buf.write(' children=${children.length}');
    buf.write(')');
    return buf.toString();
  }
}

/// Typed validation result (spec FR-002: "typed errors").
class ValidationResult {
  final bool valid;
  final List<ValidationError> errors;
  const ValidationResult.valid()
    : valid = true,
      errors = const <ValidationError>[];
  const ValidationResult.invalid(this.errors) : valid = false;

  @override
  String toString() =>
      valid ? 'ValidationResult(valid)' : 'ValidationResult(invalid: $errors)';
}

/// Concrete validation error kinds — each maps to an acceptance scenario in
/// spec US3 / FR-002.
class ValidationError {
  final ValidationErrorKind kind;
  final String message;
  final String? nodeName;
  final String? badToken;
  const ValidationError(
    this.kind,
    this.message, {
    this.nodeName,
    this.badToken,
  });

  @override
  String toString() =>
      'ValidationError($kind: $message${nodeName == null ? '' : ' node=$nodeName'}${badToken == null ? '' : ' token=$badToken'})';
}

enum ValidationErrorKind {
  unknownNodeType,
  invalidToken,
  capOverflow,
  emptyTree,
  outOfSubset,
}

/// Typed exception thrown by `UiRenderTool.render` when validation fails.
class UiRenderValidationException implements Exception {
  final ValidationResult result;
  UiRenderValidationException(this.result);

  @override
  String toString() => 'UiRenderValidationException: $result';
}

/// Thrown when `ui.render` is called with no active mission (spec Edge Cases).
class NoActiveMissionException implements Exception {
  @override
  String toString() =>
      'NoActiveMissionException: ui.render requires an active '
      'mission; activate a mission before rendering.';
}

/// Thrown when `replaceViewId` references a view that does not exist
/// (spec Edge Cases).
class ViewNotFoundException implements Exception {
  final String viewId;
  ViewNotFoundException(this.viewId);

  @override
  String toString() =>
      'ViewNotFoundException: replaceViewId "$viewId" does not match any '
      'known rendered view.';
}

/// The canonical UI Vocabulary Schema (spec Key Entities).
///
/// Configurable per mission via [vocabularyNarrowing] (spec FR-005). The
/// default schema allows a small, generic component set + common style tokens;
/// production apps override via mission-type configuration.
class UiVocabularySchema {
  /// Allowed component node types (e.g. `card`, `button`, `text`, `container`).
  final Set<String> allowedNodeTypes;

  /// Allowed style token values (e.g. `primary`, `secondary`, `danger`).
  final Set<String> allowedStyleTokens;

  /// Allowed semantic roles (v2). Empty set means "any role string allowed".
  final Set<String> allowedRoles;

  /// Maximum node count per rendered tree (FR-002 cap overflow).
  final int nodeCap;

  /// Schema version — recorded alongside each rendered tree in the mission
  /// trace (FR-008).
  final String schemaVersion;

  /// Optional mission-type tag this schema is narrowed for (null = base).
  final String? missionType;

  const UiVocabularySchema({
    required this.allowedNodeTypes,
    required this.allowedStyleTokens,
    required this.nodeCap,
    this.allowedRoles = const <String>{},
    this.schemaVersion = '1.0.0',
    this.missionType,
  });

  /// Default base schema — broad enough to cover the spec's acceptance
  /// scenarios (product-offer card with a Select Offer button).
  static const UiVocabularySchema base = UiVocabularySchema(
    allowedNodeTypes: {
      'root',
      'container',
      'card',
      'button',
      'text',
      'image',
      'list',
      'row',
      'column',
      'divider',
    },
    allowedStyleTokens: {
      'primary',
      'secondary',
      'tertiary',
      'success',
      'warning',
      'danger',
      'neutral',
    },
    allowedRoles: {
      'container',
      'list',
      'detail',
      'form',
      'field',
      'action',
      'label',
      'image',
      'text',
      'header',
      'footer',
      'card',
      'row',
      'column',
    },
    nodeCap: 256,
    schemaVersion: '1.0.0',
  );

  /// Validate a tree against this schema (FR-002). Returns a
  /// [ValidationResult] with a list of every encountered error so the agent
  /// can fix them all in one retry rather than fixing one-at-a-time.
  ValidationResult validate(UiNode tree) {
    final errors = <ValidationError>[];

    // Empty tree edge case (spec Edge Cases): a `root` node with no children
    // and no props is the empty-tree case the spec calls out.
    if (tree.children.isEmpty && tree.props.isEmpty && tree.type == 'root') {
      errors.add(
        const ValidationError(
          ValidationErrorKind.emptyTree,
          'Tree contains no renderable content; emit at least one child node.',
        ),
      );
    }

    _validateNode(tree, errors);

    // Cap overflow check (FR-002 acceptance 2).
    final capError = capOverflowError(tree);
    if (capError != null) errors.add(capError);

    if (errors.isNotEmpty) {
      return ValidationResult.invalid(errors);
    }
    return const ValidationResult.valid();
  }

  void _validateNode(UiNode node, List<ValidationError> errors) {
    // Unknown node type (FR-002 acceptance 1).
    if (!allowedNodeTypes.contains(node.type)) {
      errors.add(
        ValidationError(
          ValidationErrorKind.unknownNodeType,
          'Node type "${node.type}" is not in the allowed vocabulary.',
          nodeName: node.type,
        ),
      );
    }

    // Invalid semantic role (v2).
    if (node.role != null &&
        allowedRoles.isNotEmpty &&
        !allowedRoles.contains(node.role)) {
      errors.add(
        ValidationError(
          ValidationErrorKind.unknownNodeType,
          'Semantic role "${node.role}" is not in the allowed role set.',
          nodeName: node.type,
        ),
      );
    }

    // Invalid style token (FR-002 — "bad token" edge case).
    if (node.styleToken != null &&
        !allowedStyleTokens.contains(node.styleToken)) {
      errors.add(
        ValidationError(
          ValidationErrorKind.invalidToken,
          'Style token "${node.styleToken}" is not in the allowed token set.',
          nodeName: node.type,
          badToken: node.styleToken,
        ),
      );
    }

    // Recurse so we surface every node's error in one pass.
    for (final child in node.children) {
      _validateNode(child, errors);
    }
  }

  /// Cap-overflow check (FR-002 acceptance 2). Public so the render tool can
  /// re-check after narrowing changes the cap.
  ValidationError? capOverflowError(UiNode tree) {
    final count = tree.nodeCount;
    if (count > nodeCap) {
      return ValidationError(
        ValidationErrorKind.capOverflow,
        'Tree has $count nodes; maximum allowed is $nodeCap.',
      );
    }
    return null;
  }
}
