/// Helper to derive subject return types and minimal return bodies from
/// behavior descriptions (issues #657, #920).
///
/// Both `zfa tdd func` and `zfa tdd wire` use this helper so generated and
/// wired subjects infer their signature and return values consistently
/// (e.g. String, bool, int, double, List, Map, Result) matching the behavior
/// contract rather than defaulting blindly to `int` / `return 0;`.
library;

/// Signature details derived from a behavior description.
class DerivedSignature {
  const DerivedSignature({required this.returnType, this.explicitBody});

  final String returnType;
  final String? explicitBody;
}

/// Derives the return type and minimal body expression from [description].
///
/// [forWire]: When true, we are generating an entity-wired subject, where
/// an entity anchor statement is present. If [explicitBody] is null for String,
/// the caller can emit a deterministic string literal or return the entity/string.
DerivedSignature deriveSubjectSignature(
  String description, {
  bool forWire = false,
}) {
  final desc = description.toLowerCase();

  // "returns 42" — a concrete integer result.
  final digits = RegExp(r'\breturns?\s+(\d+)').firstMatch(desc);
  if (digits != null) {
    return DerivedSignature(
      returnType: 'int',
      explicitBody: 'return ${digits.group(1)};',
    );
  }

  // Boolean results.
  if (RegExp(r'\breturns?\s+true\b').hasMatch(desc) ||
      RegExp(r'\breturns?\s+false\b').hasMatch(desc) ||
      RegExp(r'\breturns?\s+a?\s*bool\b').hasMatch(desc)) {
    final value = RegExp(r'\breturns?\s+false\b').hasMatch(desc)
        ? 'false'
        : 'true';
    return DerivedSignature(returnType: 'bool', explicitBody: 'return $value;');
  }

  // A non-empty string result (render / format / label / message).
  if (desc.contains('non-empty string') ||
      RegExp(r'\breturns?\s+a?\s*string\b').hasMatch(desc) ||
      desc.contains('as a string') ||
      desc.contains('string for') ||
      desc.contains('render') ||
      desc.contains('format')) {
    return const DerivedSignature(returnType: 'String', explicitBody: null);
  }

  // Collections and numbers.
  if (RegExp(r'\breturns?\s+a?\s*(list|array)\b').hasMatch(desc)) {
    return const DerivedSignature(
      returnType: 'List<String>',
      explicitBody: 'return const <String>[];',
    );
  }
  if (RegExp(r'\breturns?\s+a?\s*map\b').hasMatch(desc)) {
    return const DerivedSignature(
      returnType: 'Map<String, Object?>',
      explicitBody: 'return const <String, Object?>{};',
    );
  }
  if (RegExp(r'\breturns?\s+a?\s*(double|float|num)\b').hasMatch(desc)) {
    return const DerivedSignature(
      returnType: 'double',
      explicitBody: 'return 0.0;',
    );
  }
  if (RegExp(r'\breturns?\s+an?\s+int\b').hasMatch(desc) ||
      RegExp(r'\breturns?\s+a?\s*count\b').hasMatch(desc)) {
    return const DerivedSignature(returnType: 'int', explicitBody: 'return 0;');
  }

  // For wired subjects without explicit non-int indicator, keep int if no other hint:
  if (forWire) {
    return const DerivedSignature(returnType: 'int', explicitBody: 'return 0;');
  }

  // Type-silent descriptions fallback for func.
  return const DerivedSignature(returnType: 'String', explicitBody: null);
}
