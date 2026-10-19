/// Vocabulary v2 — automated verification checks (issue #818).
///
/// Verifies a [ScreenDoc] by construction: labels present, hit-target sizes,
/// and state-matrix coverage. Removing a semantic label makes verification fail
/// and names the offending role.
library;

import 'screen_doc.dart';
import 'ui_vocabulary_schema.dart';

/// Kind of verification failure.
enum VerificationErrorKind {
  missingLabel,
  hitTargetTooSmall,
  stateMatrixIncomplete,
  unknownRole,
}

/// A single verification failure.
class VerificationError {
  final VerificationErrorKind kind;
  final String message;
  final String? role;
  final String? nodeName;

  const VerificationError(this.kind, this.message, {this.role, this.nodeName});

  @override
  String toString() =>
      'VerificationError($kind: $message${role == null ? '' : ' role=$role'}'
      '${nodeName == null ? '' : ' node=$nodeName'})';
}

/// Result of verifying a [ScreenDoc].
class VerificationResult {
  final bool valid;
  final List<VerificationError> errors;
  const VerificationResult.valid()
    : valid = true,
      errors = const <VerificationError>[];
  const VerificationResult.invalid(this.errors) : valid = false;
}

/// Minimum hit-target dimension (logical pixels) — WCAG-ish default.
const int kMinHitTarget = 48;

/// Roles that require a semantic label.
const Set<String> kLabelRequiredRoles = <String>{
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
  'screen',
};

/// Required states for full state-matrix coverage.
const Set<String> kRequiredStates = <String>{
  'loading',
  'empty',
  'error',
  'data',
};

/// Verifies a [ScreenDoc].
class ScreenVerifier {
  const ScreenVerifier();

  VerificationResult verify(ScreenDoc doc) {
    final errors = <VerificationError>[];
    _checkLabels(doc.root, errors);
    _checkHitTargets(doc.root, errors);
    _checkStateMatrix(doc, errors);
    if (errors.isEmpty) return const VerificationResult.valid();
    return VerificationResult.invalid(errors);
  }

  void _checkLabels(UiNode node, List<VerificationError> errors) {
    if (node.role != null &&
        kLabelRequiredRoles.contains(node.role) &&
        (node.label == null || node.label!.trim().isEmpty)) {
      errors.add(
        VerificationError(
          VerificationErrorKind.missingLabel,
          'Missing semantic label for role "${node.role}".',
          role: node.role,
          nodeName: node.type,
        ),
      );
    }
    for (final c in node.children) {
      _checkLabels(c, errors);
    }
  }

  void _checkHitTargets(UiNode node, List<VerificationError> errors) {
    if (node.actionId != null) {
      final w = _dim(node, 'width');
      final h = _dim(node, 'height');
      if (w < kMinHitTarget || h < kMinHitTarget) {
        errors.add(
          VerificationError(
            VerificationErrorKind.hitTargetTooSmall,
            'Hit target for role "${node.role ?? node.type}" is '
            '${w}x$h; minimum is ${kMinHitTarget}x$kMinHitTarget.',
            role: node.role,
            nodeName: node.type,
          ),
        );
      }
    }
    for (final c in node.children) {
      _checkHitTargets(c, errors);
    }
  }

  int _dim(UiNode node, String key) {
    final v = node.props[key];
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    // hitTarget nested map support
    final ht = node.props['hitTarget'];
    if (ht is Map) {
      final vv = ht[key];
      if (vv is int) return vv;
      if (vv is double) return vv.round();
      if (vv is String) return int.tryParse(vv) ?? 0;
    }
    return 0;
  }

  void _checkStateMatrix(ScreenDoc doc, List<VerificationError> errors) {
    final present = doc.states.toSet();
    final missing = kRequiredStates.difference(present);
    if (missing.isNotEmpty) {
      errors.add(
        VerificationError(
          VerificationErrorKind.stateMatrixIncomplete,
          'State matrix missing: ${missing.join(', ')}.',
        ),
      );
    }
  }
}
