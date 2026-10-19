/// Dependency-contract model (feature 072, issue #960): the typed read
/// of one declared External Dependencies & Contracts row.
///
/// Pure data + parsing; no I/O. The declared row is the single source of
/// truth the mock surface is generated from (VISION §9: the machine
/// certifies against the declared contract).
library;

/// Mock priority declared per row — orders materialization in the loop
/// (P1 before P2 before P3; unprioritized last).
enum MockPriority {
  p1(0),
  p2(1),
  p3(2),
  none(3);

  /// Sort tier: lower runs first.
  final int tier;

  const MockPriority(this.tier);

  /// Parse the declared priority cell. Case-insensitive; empty/null →
  /// [none]. An unknown token → null (the caller refuses naming the
  /// cell — a typo'd priority is contract drift, not a default).
  static MockPriority? tryParse(String? raw) {
    final t = raw?.trim().toUpperCase();
    if (t == null || t.isEmpty) return none;
    switch (t) {
      case 'P1':
        return p1;
      case 'P2':
        return p2;
      case 'P3':
        return p3;
      default:
        return null;
    }
  }

  /// kebab label for artifacts/summaries.
  String get label => this == none ? 'none' : name;
}

/// Strip one surrounding pair of inline-code backticks from [text] and
/// trim either side (issue #1892).
///
/// This is the single definition of the backtick rule: every parser that
/// reads a declared contract cell normalizes through this file, so the
/// accepted grammar cannot drift between the mock model and
/// `SandboxComposition.declaredSignatures`.
String stripInlineCodeSpan(String text) {
  var s = text.trim();
  if (s.length >= 2 && s.startsWith('`') && s.endsWith('`')) {
    s = s.substring(1, s.length - 1).trim();
  }
  return s;
}

/// True when [text] is ONE inline-code span — the backtick opening the
/// text closes on its final character. A cell whose methods are each
/// wrapped individually (`` `a() -> X`, `b() -> Y` ``) starts and ends
/// with a backtick but is not one span, because the first backtick closes
/// before the end.
bool _isWholeInlineCodeSpan(String text) =>
    text.length >= 2 &&
    text.startsWith('`') &&
    text.endsWith('`') &&
    text.indexOf('`', 1) == text.length - 1;

/// Split a declared contract cell into method segments.
///
/// A `,` is a boundary only when the next token starts a signature
/// (`name(`), so commas inside parameter lists and generic return types
/// (`read() -> Map<String, int>`) stay in their segment. Inline-code
/// backticks are tolerated in both documented shapes (issue #1892): one
/// pair around the whole cell and one pair per method segment.
List<String> splitDependencyContract(String contract) {
  var text = contract.trim();
  // One shared primitive (stripInlineCodeSpan) owns the single-pair strip,
  // so the whole-cell and per-segment rules cannot drift (issue #1892).
  if (_isWholeInlineCodeSpan(text)) {
    text = stripInlineCodeSpan(text);
  }
  text = text.replaceAll('`', '');
  return [
    for (final part in text.split(_signatureBoundary))
      if (part.trim().isNotEmpty) part.trim(),
  ];
}

final RegExp _signatureBoundary = RegExp(
  r',\s*(?=[A-Za-z_][A-Za-z0-9_]*\s*\()',
);

/// One declared method of a dependency contract:
/// `name(paramType param, ...) -> ReturnType`.
class DependencySignature {
  final String name;
  final List<String> parameters;
  final String returnType;

  const DependencySignature({
    required this.name,
    required this.parameters,
    required this.returnType,
  });

  static final RegExp _shape = RegExp(
    r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)\s*->\s*(.+?)\s*$',
  );

  /// Parse one signature; throws [FormatException] naming the raw text
  /// when the shape does not match (the caller refuses naming the row).
  ///
  /// Inline-code backticks (the Layer Contracts convention, see
  /// `spec_parser.dart`'s `parseContractRows`) are tolerated around the
  /// signature, so a contract cell written as
  /// `` `read() -> Future<UserLocation?>` `` parses identically to its
  /// un-backticked form (issue #1892). A comma-separated LIST is refused
  /// instead of silently misparsed: callers with a whole contract cell
  /// must split it first (`DependencyContract.parseRow` does).
  factory DependencySignature.parse(String raw) {
    final original = raw.trim();
    final segments = splitDependencyContract(original);
    if (segments.length != 1) {
      throw FormatException(
        'expected one `name(Params) -> Return` signature, got '
        '${segments.length}; split the contract at top-level commas '
        'first: $original',
      );
    }
    final text = segments.single;
    final m = _shape.firstMatch(text);
    if (m == null) {
      throw FormatException(
        'not a `name(Params) -> Return` signature: $original',
      );
    }
    final params = m
        .group(2)!
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return DependencySignature(
      name: m.group(1)!,
      parameters: params,
      returnType: m.group(3)!.trim(),
    );
  }

  @override
  String toString() => '$name(${parameters.join(', ')}) -> $returnType';
}

/// The typed contract of one declared dependency row.
class DependencyContract {
  final String name;

  /// Declared kind as written (`service`, `storage`, …).
  final String type;
  final List<DependencySignature> signatures;
  final MockPriority priority;

  /// The row's line in spec.md (for refusals/provenance).
  final int? specLine;

  const DependencyContract({
    required this.name,
    required this.type,
    required this.signatures,
    this.priority = MockPriority.none,
    this.specLine,
  });

  /// Parse the contract cell: methods separated by signature-boundary
  /// commas; each must match the signature shape. Throws
  /// [FormatException] naming the offending segment. Inline-code
  /// backticks are normalized by [splitDependencyContract] (issue #1892).
  static DependencyContract parseRow({
    required String name,
    required String type,
    required String contract,
    String? priority,
    int? specLine,
  }) {
    final parsedPriority = MockPriority.tryParse(priority);
    if (parsedPriority == null) {
      throw FormatException(
        'unknown mock priority "$priority" (expected P1, P2, or P3)',
      );
    }
    final signatures = splitDependencyContract(
      contract,
    ).map(DependencySignature.parse).toList();
    return DependencyContract(
      name: name,
      type: type,
      signatures: signatures,
      priority: parsedPriority,
      specLine: specLine,
    );
  }
}
