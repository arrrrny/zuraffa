/// `SpecMutator` — the deterministic spec-mutation engine (spec
/// 0967-spec-mutation-arena): candidate generation per contract element
/// and line-surgical application.
///
/// Operators are declared per contract ELEMENT — Then clauses,
/// edge-case scenarios, FR literals/routes/keys/ranges, MUST-NOT
/// clauses — never free-text edits. Candidates carry 1-based `specLine`
/// addresses (the RequirementScanner convention), `SM-###` ids in
/// document order, and the exact target token, so application is
/// deterministic and replayable (#806 composes).
///
/// This service is PURE: no I/O, no clocks, no RNG in generation (the
/// only RNG is the explicit, seeded selection in [SpecMutator.select]).
library;

import 'dart:math';

import '../models/behavior.dart';
import '../models/spec_mutation.dart';
import 'requirement_scan.dart';
import 'spec_parser.dart';

/// The result of applying a candidate to a spec.
class SpecMutationApplication {
  const SpecMutationApplication({
    required this.mutatedSpec,
    required this.affectedBehaviorId,
  });

  /// The mutated spec.md content (line-surgical rewrite).
  final String mutatedSpec;

  /// The behavior whose DESCRIPTION changed (the regen target for the
  /// P2 pin); null for `drop` (nothing downstream re-derives).
  final String? affectedBehaviorId;
}

/// Edge-case vocabulary: a scenario whose block text matches any of
/// these is an edge-case scenario (the `drop` operator's target).
final RegExp _edgeCaseVocabulary = RegExp(
  r'\b(error|errors|invalid|empty|fail|fails|failure|failures|boundary|'
  r'timeout|offline|exceed|exceeds|limit|limits|malformed|denied|reject|'
  r'rejects|rejected|negative|overflow)\b',
  caseSensitive: false,
);

/// A strict acceptance scenario header (the parser's grammar).
final RegExp _scenarioHeader = RegExp(r'^\s*(\d+)\.\s*\*\*Given\*\*');

/// An FR bullet (the parser's grammar).
final RegExp _frPattern = RegExp(r'^\s*-\s*\*\*(FR-\d{3})\*\*:\s*(.+)$');

/// The Then marker inside a scenario block.
final RegExp _thenMarker = RegExp(r'\*\*Then\*\*');

/// MUST-NOT clause: from the keyword to the sentence boundary.
final RegExp _mustNotClause = RegExp(r'MUST\s+NOT[^.;]*[.;]?');

/// A markdown heading (a scenario block boundary).
final RegExp _heading = RegExp(r'^#{1,6}\s');

/// Quoted literals (single or double), for swap + weaken.
final RegExp _quotedLiteral = RegExp("'([^']+)'|\"([^\"]+)\"");

/// Backticked tokens, for swap + weaken.
final RegExp _backtickToken = RegExp(r'`([^`]+)`');

/// Route tokens: a leading slash followed by path characters.
final RegExp _routeToken = RegExp(
  r'(?:^|[\s(\x27\x22])(\/[A-Za-z0-9][A-Za-z0-9/_-]*)',
);

/// Dotted key tokens: two or more lowercase segments (extension
/// stoplist keeps `spec.md` / `zuraffa.dart` prose out).
final RegExp _keyToken = RegExp(r'\b[a-z][a-z0-9]*(?:\.[a-z][a-z0-9]*)+\b');

const Set<String> _keyStoplist = {
  'md',
  'dart',
  'yaml',
  'yml',
  'json',
  'xml',
  'txt',
  'html',
  'css',
};

/// Numbers (for swap + weaken).
final RegExp _numberToken = RegExp(r'\b\d+\b');

/// Explicit `N..M` ranges (for widen).
final RegExp _rangeToken = RegExp(r'\b(\d+)\s*\.\.\s*(\d+)\b');

/// Declared bounds (for widen).
final RegExp _boundUpper = RegExp(
  r'\b(at\s+most|up\s+to|no\s+more\s+than|within)\s+(\d+)\b',
  caseSensitive: false,
);
final RegExp _boundLower = RegExp(
  r'\b(at\s+least)\s+(\d+)\b',
  caseSensitive: false,
);

/// One mutable statement found in the spec: a scenario Then line or an
/// FR line, with its line address and statement text.
class _Statement {
  _Statement({
    required this.lineIndex,
    required this.prefix,
    required this.text,
    required this.behaviorId,
    required this.elementPrefix,
  });

  /// 0-based line index in the split spec.
  final int lineIndex;

  /// The untouched line prefix before the statement text (kept verbatim
  /// when splicing the mutated statement back).
  final String prefix;

  /// The statement text after the Then marker / FR id.
  final String text;

  /// `A1` / `U2`.
  final String behaviorId;

  /// `AC-1:Then` / `FR-001` — the element address prefix.
  final String elementPrefix;
}

/// The deterministic spec-mutation engine.
class SpecMutator {
  const SpecMutator();

  /// Generate every candidate in document order.
  ///
  /// `operators` filters the declared set (default: all). Ids `SM-###`
  /// are assigned in document order of the parsed contract elements,
  /// independent of the filter, so ids stay stable across filters
  /// (replay/ledger addressability).
  List<SpecMutationCandidate> candidates(
    String specMd, {
    Set<SpecMutationOperator>? operators,
  }) {
    final ops = operators ?? SpecMutationOperator.all;
    final lines = specMd.split('\n');
    final generated = <SpecMutationCandidate>[];
    var scenarioIndex = 0;
    var frIndex = 0;

    void add(SpecMutationCandidate candidate) => generated.add(candidate);

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_scenarioHeader.hasMatch(line)) {
        scenarioIndex += 1;
        final block = _scenarioBlock(lines, i);
        final thenStatement = _thenStatementOf(lines, block, scenarioIndex);
        if (thenStatement != null) {
          _addStatementCandidates(
            thenStatement,
            scenarioIndex,
            add,
            isThen: true,
          );
        }
        if (_edgeCaseVocabulary.hasMatch(block.text)) {
          add(
            SpecMutationCandidate(
              mutationId: '',
              operator: SpecMutationOperator.drop,
              specLine: i + 1,
              element: 'AC-$scenarioIndex:scenario',
              behaviorId: 'A$scenarioIndex',
              originalValues: _valuesOf(block.text),
              targetToken: block.text.trim(),
              description:
                  'drop the edge-case scenario AC-$scenarioIndex '
                  '(spec line ${i + 1})',
            ),
          );
        }
        i = block.endExclusive - 1;
        continue;
      }
      final fr = _frPattern.firstMatch(line);
      if (fr != null) {
        frIndex += 1;
        final statement = _Statement(
          lineIndex: i,
          prefix: line.substring(0, fr.group(0)!.length),
          text: fr.group(2)!.trim(),
          behaviorId: 'U$frIndex',
          elementPrefix: fr.group(1)!,
        );
        _addStatementCandidates(statement, frIndex, add, isThen: false);
        {
          for (final match in _mustNotClause.allMatches(statement.text)) {
            add(
              SpecMutationCandidate(
                mutationId: '',
                operator: SpecMutationOperator.dropMustNot,
                specLine: i + 1,
                element: '${statement.elementPrefix}:MUST-NOT',
                behaviorId: statement.behaviorId,
                originalValues: _valuesOf(match.group(0)!),
                targetToken: match.group(0)!,
                description:
                    'drop the MUST NOT clause from '
                    '${statement.elementPrefix} (spec line ${i + 1})',
              ),
            );
          }
        }
      }
    }
    // Assign document-order ids over the FULL candidate set, then apply
    // the operator filter: ids stay stable across filters (replay and
    // ledger rows keep their addresses).
    final out = <SpecMutationCandidate>[];
    for (var i = 0; i < generated.length; i++) {
      final withId = _withId(
        generated[i],
        'SM-${(i + 1).toString().padLeft(3, '0')}',
      );
      if (ops.contains(withId.operator)) out.add(withId);
    }
    return out;
  }

  /// Apply [candidate] to [specMd] (which MUST be the spec the
  /// candidate was generated from) — a line-surgical rewrite.
  SpecMutationApplication apply(
    String specMd,
    SpecMutationCandidate candidate,
  ) {
    final lines = specMd.split('\n');
    final index = candidate.specLine - 1;
    final line = lines[index];
    switch (candidate.operator) {
      case SpecMutationOperator.drop:
        // The candidate's specLine is the scenario header line; the
        // block extent is recomputed the same way generation did.
        final block = _scenarioBlock(lines, index);
        final span =
            lines.sublist(0, block.headerIndex) +
            lines.sublist(block.endExclusive);
        return SpecMutationApplication(
          mutatedSpec: span.join('\n'),
          affectedBehaviorId: null,
        );
      case SpecMutationOperator.weaken:
        final split = _splitThen(line);
        final weakened = _weaken(split.$2);
        lines[index] = split.$1 + weakened;
        return SpecMutationApplication(
          mutatedSpec: lines.join('\n'),
          affectedBehaviorId: candidate.behaviorId,
        );
      case SpecMutationOperator.swapLiteral:
        final split = _splitStatement(line);
        final swapped = _swapToken(split.$2, candidate.targetToken);
        lines[index] = split.$1 + swapped;
        return SpecMutationApplication(
          mutatedSpec: lines.join('\n'),
          affectedBehaviorId: candidate.behaviorId,
        );
      case SpecMutationOperator.widen:
        final split = _splitStatement(line);
        final widened = _widenToken(split.$2, candidate.targetToken);
        lines[index] = split.$1 + widened;
        return SpecMutationApplication(
          mutatedSpec: lines.join('\n'),
          affectedBehaviorId: candidate.behaviorId,
        );
      case SpecMutationOperator.dropMustNot:
        final split = _splitStatement(line);
        var text = split.$2;
        var cleaned = text.replaceFirst(candidate.targetToken, '');
        cleaned = _collapseSpaces(cleaned);
        lines[index] = split.$1 + cleaned;
        return SpecMutationApplication(
          mutatedSpec: lines.join('\n'),
          affectedBehaviorId: candidate.behaviorId,
        );
    }
  }

  /// Deterministic budget/seed selection: budget at or above the
  /// candidate count keeps everything; seed 0 takes the document-order
  /// prefix; a nonzero seed shuffles indices with `Random(seed)` then
  /// re-sorts the chosen set (stable, replayable subsets).
  static List<SpecMutationCandidate> select(
    List<SpecMutationCandidate> all, {
    required int budget,
    required int seed,
  }) {
    if (budget >= all.length) return all;
    if (seed == 0) return all.take(budget).toList();
    final indices = List<int>.generate(all.length, (i) => i);
    indices.shuffle(Random(seed));
    final chosen = indices.take(budget).toList()..sort();
    return [for (final i in chosen) all[i]];
  }

  // ------------------------------------------------------------------
  // Statement candidate generation.
  // ------------------------------------------------------------------

  void _addStatementCandidates(
    _Statement statement,
    int index,
    void Function(SpecMutationCandidate) add, {
    required bool isThen,
  }) {
    // The element address: the scenario's document-wide AC number for
    // Thens, or the FR's own id as written for FR statements.
    final elementPrefix = isThen ? 'AC-$index:Then' : statement.elementPrefix;
    if (isThen) {
      if (_hasSpecifics(statement.text)) {
        add(
          SpecMutationCandidate(
            mutationId: '',
            operator: SpecMutationOperator.weaken,
            specLine: statement.lineIndex + 1,
            element: elementPrefix,
            behaviorId: statement.behaviorId,
            originalValues: _valuesOf(statement.text),
            targetToken: statement.text,
            description:
                'weaken the Then clause of $elementPrefix (spec line '
                '${statement.lineIndex + 1})',
          ),
        );
      }
    }
    {
      for (final token in _swapTokens(statement.text)) {
        add(
          SpecMutationCandidate(
            mutationId: '',
            operator: SpecMutationOperator.swapLiteral,
            specLine: statement.lineIndex + 1,
            element: '$elementPrefix:literal:${token.token}',
            behaviorId: statement.behaviorId,
            originalValues: [token.value],
            targetToken: token.token,
            description:
                'swap the ${token.kind} in $elementPrefix (spec line '
                '${statement.lineIndex + 1})',
          ),
        );
      }
    }
    {
      for (final token in _widenTokens(statement.text)) {
        add(
          SpecMutationCandidate(
            mutationId: '',
            operator: SpecMutationOperator.widen,
            specLine: statement.lineIndex + 1,
            element: '$elementPrefix:range:${token.token}',
            behaviorId: statement.behaviorId,
            originalValues: token.values,
            targetToken: token.token,
            description:
                'widen the range in $elementPrefix (spec line '
                '${statement.lineIndex + 1})',
          ),
        );
      }
    }
  }

  _Statement? _thenStatementOf(
    List<String> lines,
    _ScenarioBlock block,
    int scenarioIndex,
  ) {
    for (var i = block.headerIndex; i < block.endExclusive; i++) {
      final line = lines[i];
      final match = _thenMarker.firstMatch(line);
      if (match != null) {
        final prefix = line.substring(0, match.end);
        final text = line.substring(match.end).trim();
        return _Statement(
          lineIndex: i,
          prefix: prefix,
          text: text,
          behaviorId: 'A$scenarioIndex',
          elementPrefix: 'AC-$scenarioIndex:Then',
        );
      }
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Scenario blocks.
  // ------------------------------------------------------------------

  _ScenarioBlock _scenarioBlock(List<String> lines, int headerIndex) {
    var end = headerIndex + 1;
    while (end < lines.length) {
      final line = lines[end];
      if (_scenarioHeader.hasMatch(line) ||
          _heading.hasMatch(line) ||
          _frPattern.hasMatch(line)) {
        break;
      }
      end++;
    }
    // Trim trailing blank lines out of the block.
    while (end > headerIndex + 1 && lines[end - 1].trim().isEmpty) {
      end--;
    }
    final text = lines.sublist(headerIndex, end).join('\n');
    return _ScenarioBlock(
      headerIndex: headerIndex,
      endExclusive: end,
      text: text,
    );
  }

  // ------------------------------------------------------------------
  // Token extraction + transformations.
  // ------------------------------------------------------------------

  /// A matched swap token: [token] is the exact text in the statement
  /// (quotes included), [value] the pin-scannable original value.
  ({String token, String value, String kind}) _tok(
    String token,
    String value,
    String kind,
  ) => (token: token, value: value, kind: kind);

  List<({String token, String value, String kind})> _swapTokens(String text) {
    final tokens = <({String token, String value, String kind})>[];
    for (final m in _quotedLiteral.allMatches(text)) {
      tokens.add(_tok(m.group(0)!, m.group(1) ?? m.group(2)!, 'literal'));
    }
    for (final m in _backtickToken.allMatches(text)) {
      tokens.add(_tok(m.group(0)!, m.group(1)!, 'literal'));
    }
    for (final m in _routeToken.allMatches(text)) {
      tokens.add(_tok(m.group(1)!, m.group(1)!, 'route'));
    }
    for (final m in _keyToken.allMatches(text)) {
      final segments = m.group(0)!.split('.');
      final last = segments.last;
      if (_keyStoplist.contains(last)) continue;
      if (segments.any((s) => s.length < 2)) continue;
      // A dotted chain inside a backticked/quoted token was already
      // taken by the literal scan.
      if (_isInsideEarlierToken(text, m, tokens)) continue;
      tokens.add(_tok(m.group(0)!, m.group(0)!, 'key'));
    }
    for (final m in _numberToken.allMatches(text)) {
      if (_isInsideEarlierToken(text, m, tokens)) continue;
      tokens.add(_tok(m.group(0)!, m.group(0)!, 'number'));
    }
    tokens.sort((a, b) {
      final ai = text.indexOf(a.token);
      final bi = text.indexOf(b.token);
      return ai.compareTo(bi);
    });
    return tokens;
  }

  bool _isInsideEarlierToken(
    String text,
    RegExpMatch match,
    List<({String token, String value, String kind})> taken,
  ) {
    for (final t in taken) {
      final start = text.indexOf(t.token);
      if (start < 0) continue;
      final end = start + t.token.length;
      if (match.start >= start && match.end <= end) return true;
    }
    return false;
  }

  List<({String token, List<String> values})> _widenTokens(String text) {
    final tokens = <({String token, List<String> values})>[];
    final rangeSpans = <({int start, int end})>[
      for (final m in _rangeToken.allMatches(text))
        (start: m.start, end: m.end),
    ];
    bool overlapsRange(RegExpMatch m) =>
        rangeSpans.any((s) => m.start < s.end && m.end > s.start);
    for (final m in _rangeToken.allMatches(text)) {
      tokens.add((token: m.group(0)!, values: [m.group(1)!, m.group(2)!]));
    }
    for (final m in _boundUpper.allMatches(text)) {
      if (overlapsRange(m)) continue;
      tokens.add((token: m.group(0)!, values: [m.group(2)!]));
    }
    for (final m in _boundLower.allMatches(text)) {
      if (overlapsRange(m)) continue;
      tokens.add((token: m.group(0)!, values: [m.group(2)!]));
    }
    tokens.sort(
      (a, b) => text.indexOf(a.token).compareTo(text.indexOf(b.token)),
    );
    return tokens;
  }

  bool _hasSpecifics(String text) =>
      _quotedLiteral.hasMatch(text) ||
      _backtickToken.hasMatch(text) ||
      _numberToken.hasMatch(text);

  String _weaken(String text) {
    var out = text;
    out = out.replaceAllMapped(_quotedLiteral, (_) => 'something');
    out = out.replaceAllMapped(_backtickToken, (_) => 'something');
    out = out.replaceAllMapped(_numberToken, (_) => 'a number');
    return out;
  }

  String _swapToken(String text, String targetToken) {
    final number = RegExp(r'^\d+$').firstMatch(targetToken);
    if (number != null) {
      final bumped = (int.parse(targetToken) + 1).toString();
      return text.replaceFirst(targetToken, bumped);
    }
    // A quoted/backticked token swaps its CONTENT (the declared literal
    // changes; the delimiters are the spec's grammar, not the value).
    if (targetToken.length >= 2) {
      final first = targetToken[0];
      final last = targetToken[targetToken.length - 1];
      const delims = {"'", '"', '`'};
      if (delims.contains(first) && first == last) {
        final inner = targetToken.substring(1, targetToken.length - 1);
        return text.replaceFirst(targetToken, '$first$inner-swapped$first');
      }
    }
    return text.replaceFirst(targetToken, '$targetToken-swapped');
  }

  String _widenToken(String text, String targetToken) {
    final range = RegExp(r'^(\d+)\s*\.\.\s*(\d+)$').firstMatch(targetToken);
    if (range != null) {
      final lower = int.parse(range.group(1)!) ~/ 2;
      final upper = int.parse(range.group(2)!) * 2;
      return text.replaceFirst(targetToken, '$lower..$upper');
    }
    final number = RegExp(r'(\d+)').firstMatch(targetToken);
    if (number != null) {
      final value = int.parse(number.group(1)!);
      final isLower = RegExp(
        r'^at\s+least\b',
        caseSensitive: false,
      ).hasMatch(targetToken);
      final widened = isLower ? value ~/ 2 : value * 2;
      return text.replaceFirst(
        targetToken,
        targetToken.replaceFirst(number.group(1)!, widened.toString()),
      );
    }
    return text;
  }

  String _collapseSpaces(String text) =>
      text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  (String, String) _splitThen(String line) {
    final match = _thenMarker.firstMatch(line);
    if (match == null) return (line, '');
    var prefixEnd = match.end;
    if (prefixEnd < line.length && line[prefixEnd] == ' ') prefixEnd++;
    return (line.substring(0, prefixEnd), line.substring(prefixEnd).trim());
  }

  (String, String) _splitStatement(String line) {
    final fr = _frPattern.firstMatch(line);
    if (fr != null) {
      final description = fr.group(2)!;
      final prefixEnd = fr.end - description.length;
      return (line.substring(0, prefixEnd), description.trim());
    }
    return _splitThen(line);
  }

  SpecMutationCandidate _withId(SpecMutationCandidate c, String id) =>
      SpecMutationCandidate(
        mutationId: id,
        operator: c.operator,
        specLine: c.specLine,
        element: c.element,
        behaviorId: c.behaviorId,
        originalValues: c.originalValues,
        targetToken: c.targetToken,
        description: c.description,
      );
}

class _ScenarioBlock {
  _ScenarioBlock({
    required this.headerIndex,
    required this.endExclusive,
    required this.text,
  });

  final int headerIndex;
  final int endExclusive;
  final String text;
}

/// The values a statement carries (literals + numbers) — what the P3
/// assertion-pin scan looks for in committed `expect(` lines.
List<String> _valuesOf(String text) {
  final values = <String>[];
  for (final m in _quotedLiteral.allMatches(text)) {
    values.add(m.group(1) ?? m.group(2)!);
  }
  for (final m in _backtickToken.allMatches(text)) {
    values.add(m.group(1)!);
  }
  for (final m in _numberToken.allMatches(text)) {
    values.add(m.group(0)!);
  }
  return values;
}

/// P1 plan-gate pin: validate a (mutated) spec string through the same
/// gate chain `zfa tdd plan` / `zfa tdd ingest` apply, WITHOUT writing
/// anything: template-version treaty, behavior derivation, the coverage
/// gate, declaration refusals, and the undeclared-dependency lint.
/// Entity-collision gates (which read the project's lib/) are out of
/// scope for the in-isolation chain — documented in the plan.
SpecGateCheck validateSpecContract({
  required String feature,
  required String specMd,
}) {
  final templateVersion = const SpecParser().parseTemplateVersion(specMd);
  if (templateVersion == null ||
      !SpecParser.knownTemplateVersions.contains(templateVersion)) {
    return SpecGateCheck(
      accepted: false,
      refusal:
          'template-version gate: '
          '${templateVersion == null ? 'missing `**Template Version**` marker' : 'unknown template version `$templateVersion`'}',
    );
  }
  final List<Behavior> behaviors;
  final List<SpecDependency> dependencies;
  try {
    behaviors = const SpecParser().parse(feature, specMd);
    dependencies = const SpecParser().parseDependencies(specMd);
    const SpecParser().parseKeyEntities(specMd);
    const SpecParser().parseLayerContracts(specMd);
  } on StateError catch (e) {
    return SpecGateCheck(accepted: false, refusal: 'parser gate: ${e.message}');
  }
  final scan = const RequirementScanner().scan(specMd);
  final gaps = const CoverageGate().evaluate(scan, behaviors);
  if (gaps.isNotEmpty) {
    final first = gaps.first;
    return SpecGateCheck(
      accepted: false,
      refusal:
          'coverage gate: ${first.statement.id} (line '
          '${first.statement.lineNo}) produces no behavior row',
    );
  }
  try {
    SpecParser.parseScenarioTypeMarkers(specMd);
    const SpecParser().parseContractRows(specMd);
    SpecParser.parsePersistenceDeclarations(specMd);
    SpecParser.parseFrContractTraces(specMd);
  } on StateError catch (e) {
    return SpecGateCheck(
      accepted: false,
      refusal: 'declaration gate: ${e.message}',
    );
  }
  final declared = dependencies.map((d) => d.dependency).toSet();
  for (final statement in scan.statements) {
    final undeclared = SpecParser.knownExternalDependencies
        .where(
          (name) =>
              RegExp('\\b${RegExp.escape(name)}\\b').hasMatch(statement.line),
        )
        .where((name) => !declared.contains(name))
        .toList();
    if (undeclared.isNotEmpty) {
      return SpecGateCheck(
        accepted: false,
        refusal:
            'undeclared-dependency lint: ${statement.id} (line '
            '${statement.lineNo}) references ${undeclared.join(', ')}',
      );
    }
  }
  if (scan.hasDuplicates) {
    return SpecGateCheck(
      accepted: false,
      refusal:
          'coverage gate: duplicate acceptance id '
          '${scan.duplicates.first.id}',
    );
  }
  return const SpecGateCheck(accepted: true);
}
