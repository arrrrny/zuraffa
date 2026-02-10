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
        ..body.addAll(specs)
        ..directives.addAll(directives),
    );
  }

  String emitLibrary(Library library, {bool format = true}) {
    final emitter = DartEmitter(
      orderDirectives: true,
      useNullSafetySyntax: true,
    );
    final raw = library.accept(emitter).toString();
    if (!format) {
      return raw;
    }
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(raw);
  }

  String emitSpec(
    Spec spec, {
    Iterable<Directive> directives = const [],
    bool format = true,
  }) {
    return emitLibrary(
      library(specs: [spec], directives: directives),
      format: format,
    );
  }
}
