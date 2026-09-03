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

  // "returns 42" / "returns -1" / "returns 1.5" — a concrete numeric
  // literal result. Bug #920 review: an unsigned-only regex mis-routes
  // signed integers to the String fallback and decimal literals to a
  // truncated int body (`return 1;` from `returns 1.5`).
  final number =
      RegExp(r'\breturns?\s+(-?\d+(?:\.\d+)?)\b').firstMatch(desc);
  if (number != null) {
    final literal = number.group(1)!;
    return DerivedSignature(
      returnType: literal.contains('.') ? 'double' : 'int',
      explicitBody: 'return $literal;',
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
  // The render/format substring check is paired with the function-intent
  // verbs ("render <noun>" / "format <noun>") so it does not match
  // unrelated prose like "rendering time" or "formatted database".
  if (desc.contains('non-empty string') ||
      RegExp(r'\breturns?\s+a?\s*string\b').hasMatch(desc) ||
      desc.contains('as a string') ||
      desc.contains('string for') ||
      RegExp(r'\b(render|format)\s+\w+').hasMatch(desc)) {
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
