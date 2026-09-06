/// `AdapterScaffold` — scaffolds the REAL adapter behind the SAME
/// interface as the certified mock (issue #1193, FR-002).
///
/// The honest 90/10 (#908): real implementations carry unforeseeable
/// nuance, so realize never PRETENDS to generate them. What it does is
/// scaffold the SEAM: the adapter class name derived from the entity +
/// adapter family, the `implements` clause read verbatim off the
/// certified mock's declaration (the same-interface guarantee), and one
/// `throw UnimplementedError(...)` member for every `@override` the mock
/// carries (the contract surface). The file is explicitly header-marked
/// as a HAND-DELTA SEAM, immediately gated as a nuance receipt in the
/// feature's provenance ledger (the command's job), and NEVER written a
/// `proof.v1` generation receipt — scaffolding is a hand-delta with a
/// head start, not generated code.
///
/// The scaffold lives beside the mock it replaces in the DI binding
/// (same directory), so the mock's own relative imports stay valid and
/// are copied verbatim.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Raised when the scaffold cannot be derived honestly: the mock file
/// does not declare the entity's mock class, or the declaration carries
/// no `implements` clause (no interface to stand behind).
class AdapterScaffoldException implements Exception {
  const AdapterScaffoldException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The derived scaffold plan: everything the command needs to write (or,
/// under `--dry-run`, print) the seam.
class ScaffoldPlan {
  const ScaffoldPlan({
    required this.entity,
    required this.adapterName,
    required this.adapterClass,
    required this.adapterFile,
    required this.mockClass,
    required this.mockFile,
    required this.classTail,
    required this.memberSignatures,
    required this.imports,
  });

  /// The entity whose mock is being realized (e.g. `User`).
  final String entity;

  /// The adapter family name from the CLI (e.g. `firestore`).
  final String adapterName;

  /// The adapter class symbol (e.g. `UserFirestoreAdapter`).
  final String adapterClass;

  /// Absolute path the scaffold file is written to.
  final String adapterFile;

  /// The mock class symbol (e.g. `UserMockDataSource`).
  final String mockClass;

  /// Absolute path of the certified mock implementation.
  final String mockFile;

  /// The declaration tail after the class name (` implements X`), read
  /// verbatim off the mock — the same-interface guarantee.
  final String classTail;

  /// Every `@override` member signature of the mock, whitespace
  /// normalized (the contract surface).
  final List<String> memberSignatures;

  /// The mock's import lines, copied verbatim (same directory ⇒ still
  /// valid relative URIs).
  final List<String> imports;
}

/// Derives and writes REAL adapter scaffolds.
class AdapterScaffold {
  AdapterScaffold({required this.projectRoot});

  /// The target project root.
  final String projectRoot;

  /// The adapter class symbol for [entity] + [adapterName]:
  /// `<Entity><Pascal(name)>Adapter`, tolerating callers that pass the
  /// class name itself (`UserRealAdapter`) or a stem (`UserReal`,
  /// `Real`).
  static String adapterClassFor(String entity, String adapterName) {
    var base = _pascal(adapterName);
    if (base.isEmpty) {
      throw const AdapterScaffoldException(
        'the adapter name is empty — pass a family name (e.g. --adapter '
        'firestore) or an existing adapter class name.',
      );
    }
    if (!base.startsWith(entity)) {
      base = '$entity$base';
    }
    if (!base.endsWith('Adapter')) {
      base = '${base}Adapter';
    }
    return base;
  }

  /// Plan the scaffold for [entity] behind the mock at [mockFile].
  Future<ScaffoldPlan> plan({
    required String entity,
    required String adapterName,
    required String mockFile,
  }) async {
    final mockClass = '${entity}MockDataSource';
    final file = File(mockFile);
    if (!await file.exists()) {
      throw AdapterScaffoldException(
        'no certified mock implementation at '
        '${p.relative(mockFile, from: projectRoot)} — realize locates the '
        'mock behind the behavior\'s interface per the engine receipt '
        '(run `zfa make engine $entity` first).',
      );
    }
    final raw = await file.readAsString();
    final header = _classHeader(raw, mockClass);
    if (header == null) {
      throw AdapterScaffoldException(
        'the mock file ${p.relative(mockFile, from: projectRoot)} does not '
        'declare "class $mockClass" — the scaffold derives the interface '
        'from the certified mock\'s declaration.',
      );
    }
    if (!header.tail.contains('implements')) {
      throw AdapterScaffoldException(
        'the mock declaration "class $mockClass${header.tail}" carries no '
        'implements clause — the REAL adapter must stand behind the SAME '
        'interface as the mock, and there is none to stand behind.',
      );
    }
    final members = _overrideMembers(raw, mockClass);
    if (members.isEmpty) {
      throw AdapterScaffoldException(
        'the mock class $mockClass declares no @override members — no '
        'contract surface to scaffold behind.',
      );
    }

    final adapterClass = adapterClassFor(entity, adapterName);
    final adapterFile = p.join(
      p.dirname(mockFile),
      '${_snake(adapterClass)}.dart',
    );

    return ScaffoldPlan(
      entity: entity,
      adapterName: adapterName,
      adapterClass: adapterClass,
      adapterFile: adapterFile,
      mockClass: mockClass,
      mockFile: mockFile,
      classTail: header.tail,
      memberSignatures: members,
      imports: _importLines(raw),
    );
  }

  /// Write the scaffold file (refuses to clobber an existing file — an
  /// existing adapter is bound as-is by the command, never rewritten).
  Future<File> write(ScaffoldPlan plan) async {
    final file = File(plan.adapterFile);
    if (await file.exists()) {
      throw AdapterScaffoldException(
        'an adapter file already exists at '
        '${p.relative(plan.adapterFile, from: projectRoot)} — realize '
        'binds existing adapters, it never overwrites them.',
      );
    }
    final buffer = StringBuffer();
    buffer.writeln(
      '// HAND-DELTA SEAM — scaffolded by `zfa tdd realize --adapter '
      '${plan.adapterName}`',
    );
    buffer.writeln(
      '// (issue #1193). NOT generated code: this file is a receipted '
      'hand-delta',
    );
    buffer.writeln(
      '// (specs/<feature>/tdd/provenance-ledger.json). Real nuance is '
      'hand-written',
    );
    buffer.writeln(
      '// by design — fill each member in, then re-run `zfa tdd realize '
      '<feature>',
    );
    buffer.writeln(
      '// --adapter ${plan.adapterName}`: the contract suite and the '
      'differential gate',
    );
    buffer.writeln('// verify the swap.');
    buffer.writeln('//');
    buffer.writeln(
      '// interface: the SAME one ${plan.mockClass} implements — the swap '
      'goes',
    );
    buffer.writeln('// behind the contract, never through it.');
    for (final import in plan.imports) {
      buffer.writeln(import);
    }
    if (plan.imports.isNotEmpty) buffer.writeln();
    buffer.writeln(
      '/// REAL adapter for ${plan.entity} — the hand-delta seam behind '
      'the same',
    );
    buffer.writeln('/// interface as the certified mock ${plan.mockClass}.');
    buffer.writeln('class ${plan.adapterClass}${plan.classTail} {');
    for (final signature in plan.memberSignatures) {
      final member = _memberName(signature);
      buffer.writeln('  @override');
      buffer.writeln('  $signature {');
      buffer.writeln('    throw UnimplementedError(');
      buffer.writeln(
        "      'TODO(#1193): real ${plan.adapterName} nuance for "
        "${plan.entity}.$member',",
      );
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln();
    }
    buffer.writeln('}');
    await file.parent.create(recursive: true);
    await file.writeAsString(buffer.toString());
    return file;
  }
}

// ---------------------------------------------------------------------
// Mock-declaration parsing: a bracket-depth character scanner. The
// generated mock files follow one shape; anything unparseable refuses
// honestly (an [AdapterScaffoldException] or no members).
// ---------------------------------------------------------------------

/// The class declaration header: everything between `class <Name>` and
/// the body's opening `{` (normalized whitespace, leading space kept).
({String tail, int bodyOpen})? _classHeader(String raw, String className) {
  final match = RegExp(
    'class\\s+$className\\b([^{;]*)\\{',
    dotAll: true,
  ).firstMatch(raw);
  if (match == null) return null;
  var tail = _collapse(match.group(1) ?? '');
  final bodyOpen = match.end - 1;
  return (tail: tail.isEmpty ? '' : ' $tail', bodyOpen: bodyOpen);
}

/// Every `@override` member signature of [className]'s body, whitespace
/// collapsed: the text between the annotation stack and the body marker
/// (`{`, `=>` or `;`). Constructors, private helpers and statics are not
/// contract members and are skipped.
List<String> _overrideMembers(String raw, String className) {
  final header = _classHeader(raw, className);
  if (header == null) return const [];
  final body = _sliceBraces(raw, header.bodyOpen);
  if (body == null) return const [];

  final members = <String>[];
  var depthParen = 0, depthBracket = 0, depthBrace = 0;
  var chunk = StringBuffer();
  var sawOverride = false;
  var i = 0;

  String flushChunk() {
    final text = _collapse(chunk.toString());
    chunk = StringBuffer();
    final hadOverride = sawOverride;
    sawOverride = false;
    if (!hadOverride || text.isEmpty) return '';
    final signature = _signatureOf(text);
    return signature ?? '';
  }

  while (i < body.length) {
    final c = body[i];

    // Comments are dropped from chunk text.
    if (c == '/' && i + 1 < body.length && body[i + 1] == '/') {
      final nl = body.indexOf('\n', i);
      i = nl < 0 ? body.length : nl;
      continue;
    }
    if (c == '/' && i + 1 < body.length && body[i + 1] == '*') {
      final end = body.indexOf('*/', i + 2);
      i = end < 0 ? body.length : end + 2;
      continue;
    }

    // `atTop` is the depth BEFORE the current char: a `{` at the
    // member level IS the body start (the depth counters only move
    // after the terminator checks below).
    final atTop = depthParen == 0 && depthBracket == 0 && depthBrace == 0;

    if (c == '@' && atTop) {
      // An annotation: consume the annotation token (with optional
      // arguments) without letting its brackets leak into the chunk.
      chunk.write(c);
      i++;
      while (i < body.length && (body[i].isLetterOrDigitLike())) {
        chunk.write(body[i]);
        i++;
      }
      if (i < body.length && body[i] == '(') {
        chunk.write('(');
        depthParen++;
        i++;
        var inner = 1;
        while (i < body.length && inner > 0) {
          final d = body[i];
          if (d == '(') {
            inner++;
            depthParen++;
          } else if (d == ')') {
            inner--;
            depthParen--;
          }
          chunk.write(d);
          i++;
        }
      }
      final name = chunk.toString().trim().toLowerCase();
      if (name.endsWith('@override')) sawOverride = true;
      continue;
    }

    if (c == '{' && atTop) {
      // A member body block: everything collected so far is the
      // signature; skip the block.
      final signature = flushChunk();
      if (signature.isNotEmpty) members.add(signature);
      var inner = 1;
      i++;
      while (i < body.length && inner > 0) {
        if (body[i] == '{') inner++;
        if (body[i] == '}') inner--;
        i++;
      }
      continue;
    }

    if (c == '=' && i + 1 < body.length && body[i + 1] == '>' && atTop) {
      // An expression body: the signature ends here; skip to the `;`
      // at depth 0.
      final signature = flushChunk();
      if (signature.isNotEmpty) members.add(signature);
      i += 2;
      while (i < body.length) {
        final d = body[i];
        if (d == '(') depthParen++;
        if (d == ')') depthParen--;
        if (d == '[') depthBracket++;
        if (d == ']') depthBracket--;
        if (d == '{') depthBrace++;
        if (d == '}') depthBrace--;
        if (d == ';' &&
            depthParen == 0 &&
            depthBracket == 0 &&
            depthBrace == 0) {
          i++;
          break;
        }
        i++;
      }
      continue;
    }

    if (c == ';' && atTop) {
      // End of an expression-less member (abstract/empty body).
      final signature = flushChunk();
      if (signature.isNotEmpty) members.add(signature);
      i++;
      continue;
    }

    // The char is part of the signature text: update the depths.
    if (c == '(') depthParen++;
    if (c == ')') depthParen--;
    if (c == '[') depthBracket++;
    if (c == ']') depthBracket--;
    if (c == '{') depthBrace++;
    if (c == '}') depthBrace--;
    chunk.write(c);
    i++;
  }
  // A trailing chunk without a terminator (shouldn't happen) is dropped.
  return members;
}

/// The signature of a normalized member chunk: strip the annotation
/// stack, canonicalize the punctuation spacing, strip the body
/// modifiers (`async`/`async*`/`sync*`), and exclude constructors and
/// non-contract members.
String? _signatureOf(String text) {
  var signature = text;
  // Strip the annotation stack: every leading `@Token(...)`.
  while (true) {
    final m = RegExp(r'^@[\w.]+(\([^)]*\))?').firstMatch(signature);
    if (m == null) break;
    signature = signature.substring(m.end).trim();
  }
  signature = _canonicalSignature(signature);
  // A return-type-only fragment means the parse drifted — refuse.
  if (signature.isEmpty || signature.startsWith('factory ')) return null;
  if (_looksLikeConstructor(signature)) return null;
  if (signature.startsWith('_') || signature.startsWith('static ')) {
    return null;
  }
  // Setter signatures keep their shape; getters may have no parens.
  return signature;
}

/// Canonicalize a collapsed signature: punctuation hugging, trailing
/// commas inside parameter braces dropped, body modifiers stripped —
/// `Future<X?> getById( String id, { bool f = false, }) async` becomes
/// `Future<X?> getById(String id, {bool f = false})`.
String _canonicalSignature(String s) {
  var t = _collapse(s);
  t = t.replaceAll(RegExp(r'\s+async\*?$'), '');
  t = t.replaceAll(RegExp(r'\s+sync\*?$'), '');
  t = t.replaceAllMapped(RegExp(r'([\(\[\{<])\s+'), (m) => m.group(1)!);
  t = t.replaceAllMapped(RegExp(r'\s+([\)\]\}>;])'), (m) => m.group(1)!);
  t = t.replaceAll(RegExp(r',\s*\}'), '}');
  return t;
}

/// `Name(` / `const Name(` — the identifier before the first `(` is a
/// bare capitalized word with no return type before it.
bool _looksLikeConstructor(String signature) {
  final m = RegExp(
    r'^(?:const\s+)?([A-Z][A-Za-z0-9_]*)\s*\(',
  ).firstMatch(signature);
  if (m == null) return false;
  // `Future<...>` and friends carry a generic argument after the
  // identifier — not constructors. The regex above already required the
  // `(` directly, so a matched capitalized word followed by `(` is a
  // constructor shape (or an unnamed-function return type, which the
  // generated mocks never emit).
  return true;
}

/// Slice the body braces starting at [openIndex] (the index of the
/// opening `{`): returns the inner text, or null when unbalanced.
String? _sliceBraces(String raw, int openIndex) {
  var depth = 0;
  var start = -1;
  for (var i = openIndex; i < raw.length; i++) {
    final c = raw[i];
    if (c == '{') {
      if (depth == 0) start = i + 1;
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return raw.substring(start, i);
    }
  }
  return null;
}

List<String> _importLines(String raw) =>
    raw.split('\n').map((l) => l.trim()).where((l) {
      return l.startsWith("import '") ||
          l.startsWith('import "') ||
          l.startsWith('export ') ||
          l.startsWith('part ');
    }).toList();

/// Collapse all whitespace runs to single spaces.
String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// The member name of a normalized signature (for the TODO message).
String _memberName(String signature) {
  var m = RegExp(r'\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\(').firstMatch(signature);
  if (m != null) return m.group(1)!;
  m = RegExp(r'\bget\s+([a-zA-Z_][a-zA-Z0-9_]*)').firstMatch(signature);
  if (m != null) return m.group(1)!;
  m = RegExp(r'\bset\s+([a-zA-Z_][a-zA-Z0-9_]*)').firstMatch(signature);
  if (m != null) return m.group(1)!;
  return 'member';
}

String _pascal(String s) {
  final parts = s
      .split(RegExp(r'[-_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) {
        if (part.toUpperCase() == part && part.length > 1) {
          // FIRESTORE → Firestore (keep single letters as-is).
          return part[0] + part.substring(1).toLowerCase();
        }
        return part[0].toUpperCase() + part.substring(1);
      })
      .toList();
  return parts.join();
}

String _snake(String s) {
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '-' || c == ' ' || c == '_') {
      out.write('_');
    } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
      out.write('_');
      out.write(c.toLowerCase());
    } else {
      out.write(c.toLowerCase());
    }
  }
  return out.toString();
}

extension on String {
  /// Letters, digits, `_` and `.` — annotation token characters.
  bool isLetterOrDigitLike() => RegExp(r'[A-Za-z0-9_.]').hasMatch(this);
}
