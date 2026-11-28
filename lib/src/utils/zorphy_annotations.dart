/// The zorphy v3 archetype annotations, as source text.
///
/// The generator reads entity sources as text (there is no resolved
/// element model at generation time), so "which annotations exist" is a
/// vocabulary that several scans need: identity resolution, the
/// `build.yaml` guard, and the build-relevance fingerprint. It lives
/// here, once. Before it did, three separate regexes matched only the
/// v2 names (`@Zorphy`, `@ZorphyMixin`, `@ZValueObject`), none of which
/// exist in v3 — every scan was dead against the annotations the
/// generator itself emits.
///
/// KEEP IN SYNC with `zorphy_annotation/lib/src/archetypes.dart`: the
/// five class archetypes plus the two member annotations.
/// `test/utils/zorphy_annotations_test.dart` pins the list against a
/// real annotated source.
library;

import 'package:path/path.dart' as p;

/// The five v3 class archetypes.
const Set<String> zorphyArchetypeNames = {
  'ZorphyEntity',
  'ZorphyState',
  'ZorphyUnion',
  'ZorphyIntent',
  'ZorphyValue',
};

/// Every annotation the zorphy builder consumes: the class archetypes
/// plus the member annotations.
const Set<String> zorphyAnnotationNames = {
  ...zorphyArchetypeNames,
  'ZorphyDomainBool',
  'ZorphyMock',
};

/// True when [source] declares a zorphy class archetype: an
/// `@<name>` from [zorphyArchetypeNames], outside comments.
///
/// The name must end at the annotation: `@ZorphyField(...)`,
/// `@ZorphyLens<...>` and the query types are runtime classes, not
/// archetypes, and never count.
bool declaresZorphyArchetype(String source) {
  for (final line in stripComments(source).split('\n')) {
    for (final name in zorphyArchetypeNames) {
      if (RegExp('@$name\\b(?!\\s*<)').hasMatch(line)) return true;
    }
  }
  return false;
}

/// True when [source] carries any annotation the zorphy builder
/// consumes ([zorphyAnnotationNames]), outside comments.
bool hasZorphyAnnotation(String source) {
  for (final line in stripComments(source).split('\n')) {
    for (final name in zorphyAnnotationNames) {
      if (RegExp('@$name\\b').hasMatch(line)) return true;
    }
  }
  return false;
}

/// The archetype [source] declares, or null when it declares none.
///
/// A class carries exactly one archetype in v3 (`ZORPHY_E002` rejects
/// mixing), so the first match is the answer.
String? zorphyArchetypeOf(String source) {
  final stripped = stripComments(source);
  for (final name in zorphyArchetypeNames) {
    if (RegExp('@$name\\b(?!\\s*<)').hasMatch(stripped)) return name;
  }
  return null;
}

/// The value of `#<symbol>` for the named argument of an annotation in
/// [source] — `principalKey: #id` yields `id`. Null when the annotation
/// is absent or declares no such argument.
String? zorphySymbolArgument(
  String source,
  String annotation,
  String argument,
) {
  final annotationMatch = RegExp(
    '@$annotation\\s*(\\(([\\s\\S]*?)\\))?',
  ).firstMatch(stripComments(source));
  final args = annotationMatch?.group(2);
  if (args == null) return null;
  return RegExp(
    '\\b$argument\\s*:\\s*#\\s*([A-Za-z_]\\w*)',
  ).firstMatch(args)?.group(1);
}

/// The `part` directive URI of the shared part the zorphy v3 builder
/// contributes to [libraryPath], a package-relative, `/`-separated path.
///
/// build_runner writes `<library>.part.dart` under its reserved `_br_`
/// directory, mirroring the library's own path: `lib/a/b.dart` gets
/// `lib/_br_/a/b.part.dart`, and a library outside `lib/` gets
/// `_br_/a/b.part.dart` at the package root. This is the only generated
/// file a v3 source declares — no standalone `<name>.zorphy.dart` is
/// ever written — so a scaffold must derive its part directive from here
/// rather than hand-building the relative path.
String sharedPartUri(String libraryPath) {
  final dir = p.posix.dirname(
    p.posix.normalize(libraryPath.replaceAll(r'\', '/')),
  );
  return p.posix
      .relative(sharedPartPath(libraryPath), from: dir)
      .replaceAll(r'\', '/');
}

/// The shared-part path [sharedPartUri] names, package-relative:
/// `lib/_br_/a/b.part.dart` for the library `lib/a/b.dart`. For checks
/// that must decide whether the part a source declares was written.
String sharedPartPath(String libraryPath) {
  // A `part` URI is always `/`-separated; accept a native-separator path
  // so a caller cannot produce a part that names the wrong library.
  final segments = p.posix.split(
    p.posix.normalize(libraryPath.replaceAll(r'\', '/')),
  );
  final inLib = segments.first == 'lib';
  return p.posix.joinAll([
    if (inLib) ...['lib', '_br_'] else '_br_',
    // Only a `lib/` library loses its first segment (it becomes `_br_`);
    // a library elsewhere keeps its whole path below the package root.
    ...segments.sublist(inLib ? 1 : 0, segments.length - 1),
    '${p.posix.basenameWithoutExtension(segments.last)}.part.dart',
  ]);
}

/// [source] with block comments and `//` line comments removed.
///
/// Text-source scans run on this so a doc comment that mentions an
/// annotation classifies nothing. It is deliberately simple: `//` inside
/// a string literal is treated as a comment, which for Dart source only
/// ever drops text AFTER the annotation-bearing prefix of a line.
String stripComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');
