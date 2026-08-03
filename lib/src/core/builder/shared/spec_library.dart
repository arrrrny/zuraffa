import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

class SpecLibrary {
  const SpecLibrary();

  Library library({
    Iterable<Spec> specs = const [],
    Iterable<Directive> directives = const [],
  }) {
    return Library(
      (b) => b
        ..directives.addAll(directives)
        ..body.addAll(specs),
    );
  }

  String emitLibrary(
    Library library, {
    bool format = true,
    String? leadingComment,
    bool wrapWithGeneratedMarkers = true,
  }) {
    final emitter = DartEmitter(
      allocator: Allocator.simplePrefixing(),
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    var raw = library.accept(emitter).toString();

    if (leadingComment != null) {
      raw = '$leadingComment\n$raw';
    }

    // Wrap with GENERATED markers for smart regeneration.
    // This allows the AST merge engine to identify and safely
    // replace generated code while preserving user edits.
    if (wrapWithGeneratedMarkers) {
      raw = '// GENERATED - DO NOT EDIT\n$raw\n// END GENERATED';
    }

    if (!format) {
      return raw;
    }
    try {
      return DartFormatter(
        languageVersion: DartFormatter.latestLanguageVersion,
      ).format(raw);
    } catch (_) {
      return raw;
    }
  }

  String emitSpec(
    Spec spec, {
    Iterable<Directive> directives = const [],
    bool format = true,
    bool wrapWithGeneratedMarkers = true,
  }) {
    return emitLibrary(
      library(specs: [spec], directives: directives),
      format: format,
      wrapWithGeneratedMarkers: wrapWithGeneratedMarkers,
    );
  }

  String emitCode(
    String code, {
    Iterable<Directive> directives = const [],
    bool format = true,
    bool wrapWithGeneratedMarkers = true,
  }) {
    return emitLibrary(
      library(specs: [Code(code)], directives: directives),
      format: format,
      wrapWithGeneratedMarkers: wrapWithGeneratedMarkers,
    );
  }
}
