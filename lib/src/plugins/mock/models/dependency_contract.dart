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
  factory DependencySignature.parse(String raw) {
    final m = _shape.firstMatch(raw);
    if (m == null) {
      throw FormatException('not a `name(Params) -> Return` signature: $raw');
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
      returnType: m.group(3)!,
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

  /// Split the contract cell into method strings at TOP-LEVEL commas
  /// only — parameter lists carry their own commas
  /// (`signIn(email, password) -> User, signOut() -> void`).
  static List<String> _splitMethods(String contract) {
    final out = <String>[];
    final buf = StringBuffer();
    var depth = 0;
    for (final ch in contract.runes) {
      final c = String.fromCharCode(ch);
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
      } else if (c == ',' && depth == 0) {
        final part = buf.toString().trim();
        if (part.isNotEmpty) out.add(part);
        buf.clear();
        continue;
      }
      buf.write(c);
    }
    final last = buf.toString().trim();
    if (last.isNotEmpty) out.add(last);
    return out;
  }

  /// Parse the contract cell: methods separated by `,` at the top
  /// level; each must match the signature shape. Throws
  /// [FormatException] naming the offending segment.
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
    final signatures = _splitMethods(
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
