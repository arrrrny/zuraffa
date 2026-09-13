/// SubjectProvenance — the single source of truth for the gen
/// contract-derived stub's provenance markers and func's rewritability
/// predicate (issue #1565).
///
/// Three writers own the unit-subject artifact with two different shapes:
///   - `gen` writes the honest-red stub. Since issue #1259 the shape is
///     CONTRACT-DERIVED when the spec declares a Layer Contract row; since
///     SPEC 1489 the declared entity types render VERBATIM when the entity
///     exists on disk (`ScanSession subject_u1() => throw
///     UnimplementedError(...)`), import included.
///   - `func` rewrites the stub with a minimal implementation — but ONLY
///     the bounded shapes its stub-signature regex covers
///     (`int|void|String|bool|double|num|Object|dynamic`), so a
///     hand-authored entity-typed subject still refuses ("refusing to
///     rewrite a file this command did not generate" — the correct guard).
///   - the author hand-implements the body (the #1308 hand-step seam).
///
/// The #1565 deadlock: `make`'s plan schedules `tdd func` for every
/// unit-kind / function-intent / declared plain-function behavior without
/// consulting the subject's shape, so a contract-derived stub with verbatim
/// entity types dead-ends the make in a `generation-error` — on a subject
/// that already IS the declared contract the behavior needs.
///
/// This class owns BOTH sides of the decision so they cannot drift:
///   - the provenance markers, consumed verbatim from what
///     `SubjectWriter._renderContractUnitSubject` emits (the same pattern
///     `func_command` uses for `StubClaims` — the writer's own templates
///     are the contract);
///   - func's bounded-shape pattern (moved verbatim from
///     `func_command._stubSignature`), which both func and make consult;
///   - the broadened contract-derived declaration pattern (applied ONLY
///     when the provenance markers are present — the bounded set's
///     "this command did not generate" safety moves to the markers);
///   - the plan-skip predicate make uses before scheduling the func step.
library;

/// The gen provenance header prefix every gen-emitted stub carries
/// (`// GENERATED STUB — `zfa tdd gen <id>` ...`). SubjectWriter renders it
/// verbatim for every lane; the contract-derived variant continues
/// `(spec 044-test-tdd-generation + issue #1259 contract derivation).`.
const String kGenProvenanceMarker = '// GENERATED STUB — `zfa tdd gen ';

/// The contract-derived subject marker (issue #1259) — the second half of
/// the provenance proof, rendered verbatim by
/// `SubjectWriter._renderContractUnitSubject` and by no other template.
const String kContractDerivedMarker =
    '// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is';

/// An actual `throw UnimplementedError(...)` statement in executable code —
/// the same scan spec 0806 FR-006 standardized for the refusal key (the
/// stub header's doc comment merely MENTIONS `UnimplementedError` and must
/// never trip this).
final RegExp _unimplementedThrow = RegExp(
  r'throw[ \t]+(?:const[ \t]+)?UnimplementedError\s*\(',
);

/// The provenance + rewritability predicates of the unit-subject artifact.
class SubjectProvenance {
  const SubjectProvenance._();

  /// The stub declaration func rewrites: the shapes gen emits for the
  /// unit lane — the legacy no-arg int/void stub (issue #657) and the
  /// contract-derived shape with scalar declared types (issue #1259), with
  /// an optional parameter list. A bounded type set (never an arbitrary
  /// identifier) keeps the "this command did not generate" safety for
  /// UNMARKED files: a hand-authored subject typed by an entity
  /// (`User login(...) => throw ...`) does not match.
  ///
  /// Moved verbatim from `func_command._stubSignature` (issue #1565): make's
  /// plan decision and func's refusal decision must consult the SAME
  /// pattern.
  static final RegExp funcRewritableStubPattern = RegExp(
    r'^((?:int|void|String|bool|double|num|Object|dynamic)\??)'
    r'[ \t]+([A-Za-z_][A-Za-z0-9_]*)\(([^)]*)\)[ \t]*=>[ \t]*'
    r'throw[ \t]+UnimplementedError\([^;\r\n]*\);[ \t]*$',
    multiLine: true,
  );

  /// The declaration line the contract-derived template emits:
  /// `<returnType> <name>(<params>) => throw UnimplementedError('...');`
  /// where `<returnType>` is any renderable Dart type token — the scalars,
  /// entity identifiers, their nullable variants, and generics
  /// (`List<Task>`, `Map<String, Task>`) — never an arbitrary expression.
  /// The bounded set above deliberately excludes entity types (the #1565
  /// deadlock class); this pattern recognizes them, but its callers MUST
  /// gate on [isContractDerivedGenStub] first — the provenance markers, not
  /// the type boundedness, are what proves gen wrote the file.
  static final RegExp contractDerivedDeclarationPattern = RegExp(
    r'^[A-Za-z_][A-Za-z0-9_<>?, ]*[ \t]+([A-Za-z_][A-Za-z0-9_]*)'
    r'\(([^)]*)\)[ \t]*=>[ \t]*'
    r'throw[ \t]+(?:const[ \t]+)?UnimplementedError\([^;\r\n]*\);[ \t]*$',
    multiLine: true,
  );

  /// Whether [source] carries BOTH provenance markers — the gen header AND
  /// the contract-derived subject marker. Either alone is insufficient: the
  /// legacy gen stub shares the header, and a hand-authored file could
  /// carry any single comment line. Together they prove the file is gen's
  /// contract-derived output (issue #1259 template, SPEC 1489 rendering).
  static bool isContractDerivedGenStub(String source) =>
      source.contains(kGenProvenanceMarker) &&
      source.contains(kContractDerivedMarker);

  /// Whether func would REFUSE the subject this file carries — the exact
  /// #1565 deadlock class, and the predicate make's plan consults before
  /// scheduling the func step (issue #1565 FR-1.4):
  ///   - the provenance markers prove gen wrote the file,
  ///   - an actual `throw UnimplementedError` is still in place (the
  ///     honest red the implementation work targets), and
  ///   - func's bounded rewrite set does not cover the signature.
  ///
  /// A scalar contract-derived stub (func CAN rewrite it — the
  /// declared-dummy path) is false here: the func step stays scheduled for
  /// it. A hand-authored entity-typed subject is false (no provenance):
  /// the refusal guard stays honest for files gen did not write.
  static bool funcWouldRefuseContractDerivedStub(String source) =>
      isContractDerivedGenStub(source) &&
      _unimplementedThrow.hasMatch(source) &&
      !funcRewritableStubPattern.hasMatch(source);
}
