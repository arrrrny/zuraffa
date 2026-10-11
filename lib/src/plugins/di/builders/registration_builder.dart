import 'package:code_builder/code_builder.dart';

import '../../../core/builder/shared/spec_library.dart';

/// Emits the generated DI files (issue #1102 hardening: idempotent
/// registrations + a resetDependencies test hook).
///
/// [registeredTypes] makes a registration file UNREGISTER-FIRST: for
/// every type listed, the emitted body guards its registration with
///
/// ```dart
/// if (getIt.isRegistered<T>()) { getIt.unregister<T>(); }
/// ```
///
/// so calling `setupDependencies(getIt)` twice in one process (hot
/// restart under test, re-entered test lanes) is legal by
/// construction instead of throwing on the double registration (the
/// pilot's lesson 4: generated DI was not idempotent).
class RegistrationBuilder {
  final SpecLibrary specLibrary;

  const RegistrationBuilder({this.specLibrary = const SpecLibrary()});

  String buildRegistrationFile({
    required String functionName,
    required List<String> imports,
    required Block body,
    List<String> registeredTypes = const [],
  }) {
    final method = Method(
      (m) => m
        ..name = functionName
        ..returns = refer('void')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'getIt'
              ..type = refer('GetIt'),
          ),
        )
        ..body = Block(
          (b) => b
            // #1102: unregister-first guards precede the body — the
            // registration sites pass their types so a second
            // setupDependencies call re-registers instead of
            // throwing.
            ..statements.addAll(registeredTypes.map(unregisterFirstGuard))
            ..statements.add(body),
        ),
    );

    final library = specLibrary.library(
      specs: [method],
      directives: imports.map(Directive.import),
    );

    return specLibrary.emitLibrary(library);
  }

  String buildIndexFile({
    required String functionName,
    required List<Code> registrations,
    List<Directive> directives = const [],
    bool emitReset = true,
  }) {
    final setup = Method(
      (m) => m
        ..name = functionName
        ..returns = refer('void')
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'getIt'
              ..type = refer('GetIt'),
          ),
        )
        ..body = Block((b) => b..statements.addAll(registrations)),
    );

    final specs = <Spec>[setup];
    if (emitReset) {
      specs.add(_buildResetFunction(resetNameFor(functionName)));
    }

    final library = specLibrary.library(specs: specs, directives: directives);

    return specLibrary.emitLibrary(library);
  }

  /// Emits `void resetDependencies(GetIt getIt) { getIt.reset(); }` —
  /// the #1102 test-lane hook. Emitted ALONGSIDE setupDependencies
  /// by the index builder (and the day-zero bootstrap barrel), so a
  /// test lane can wipe the graph between cases without depending
  /// on private internals.
  Method _buildResetFunction(String name) {
    return Method(
      (m) => m
        ..name = name
        ..returns = refer('void')
        ..docs.addAll([
          '/// Test-lane hook (issue #1102): unregisters everything the',
          '/// paired setup function registered, so repeated setup in one',
          '/// process (and between test cases) is idempotent.',
        ])
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'getIt'
              ..type = refer('GetIt'),
          ),
        )
        ..body = Block(
          (b) => b
            ..statements.add(
              refer('getIt').property('reset').call([]).statement,
            ),
        ),
    );
  }

  /// Derives the reset function name from the setup function name
  /// (`setupDependencies` → `resetDependencies`).
  static String resetNameFor(String setupName) =>
      'reset${setupName.replaceFirst(RegExp('^setup'), '')}';

  /// The unregister-first guard statement for [typeName] — public so
  /// emission sites can compose it into custom bodies when a
  /// function registers through hand-written glue.
  static Code unregisterFirstGuard(String typeName) => Code(
    '// #1102: unregister-first — setupDependencies is callable twice.\n'
    'if (getIt.isRegistered<$typeName>()) {\n'
    '  getIt.unregister<$typeName>();\n'
    '}',
  );
}
