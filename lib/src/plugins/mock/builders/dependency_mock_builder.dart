/// DependencyMockBuilder (feature 072, issue #960): the deterministic
/// emitter for a declared dependency's certified mock package.
///
/// Pure: contract in, file contents out. No I/O, no timestamps, no
/// iteration-order hazards — same contract ⇒ byte-identical artifacts
/// (data-model invariant I2).
library;

import '../models/dependency_contract.dart';

/// One generated artifact: relative path + full content.
class GeneratedDependencyArtifact {
  final String path;
  final String content;

  const GeneratedDependencyArtifact({required this.path, required this.content});
}

/// The package layout for one dependency:
/// - `<name>.dart` — the declared interface (exactly the declared members)
/// - `<name>_fake.dart` — certified fake: scriptable responses + call recorder
/// - `<name>_fixtures.dart` — deterministic fixture lane
abstract final class DependencyMockBuilder {
  /// Emit the package for [contract] under [outDir] (e.g.
  /// `test/mock/dependencies/firebase_auth/`).
  static List<GeneratedDependencyArtifact> emit({
    required DependencyContract contract,
    required String outDir,
  }) {
    final dirName = snake(contract.name);
    return [
      GeneratedDependencyArtifact(
        path: '$outDir/$dirName.dart',
        content: _interface(contract),
      ),
      GeneratedDependencyArtifact(
        path: '$outDir/${dirName}_fake.dart',
        content: _fake(contract),
      ),
      GeneratedDependencyArtifact(
        path: '$outDir/${dirName}_fixtures.dart',
        content: _fixtures(contract),
      ),
    ];
  }

  /// snake_case of a dependency name (`FirebaseAuth` → `firebase_auth`).
  static String snake(String raw) {
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
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

  static String _pascal(String raw) {
    final parts = raw
        .split(RegExp(r'[^A-Za-z0-9]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return raw;
    return parts.map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join();
  }

  /// Declared parameters → typed parameter list. A bare name is typed
  /// `String`; `int attempts` keeps its declared type.
  static String _paramList(List<String> parameters) {
    if (parameters.isEmpty) return '';
    return parameters
        .map((p) {
          final t = p.trim();
          return t.contains(' ') ? t : 'String $t';
        })
        .join(', ');
  }

  /// Async shaping per the mock-datasource convention: declared `void`
  /// becomes `Future<void>`; declared `T` becomes `Future<T>` unless it
  /// is already `Future<T>`/`Stream<T>`.
  static String _returnType(String declared) {
    final t = declared.trim();
    if (t == 'void') return 'Future<void>';
    if (t.startsWith('Future<') || t.startsWith('Stream<')) return t;
    return 'Future<$t>';
  }

  static String _classDoc(DependencyContract c) =>
      '// Declared: ${c.type} | priority: ${c.priority.label}'
      '${c.specLine == null ? '' : ' | spec line ${c.specLine}'}';

  static String _interface(DependencyContract c) {
    final members = c.signatures
        .map(
          (s) => '  ${_returnType(s.returnType)} ${s.name}'
              '(${_paramList(s.parameters)});',
        )
        .join('\n');
    return '''
// GENERATED — `zfa mock dependency ${c.name}` (issue #960).
//
// Declared interface: exactly the members the External Dependencies &
// Contracts row declares — no invented, missing, or renamed members.
// Regenerating from an unchanged row is byte-for-byte identical.
library;

${_classDoc(c)}
abstract class ${c.name} {
$members
}
''';
  }

  static String _fake(DependencyContract c) {
    final dirName = snake(c.name);
    final slots = c.signatures
        .map(
          (s) =>
              '  ${_returnType(s.returnType)} Function()? _scripted${_pascal(s.name)};',
        )
        .join('\n');
    final scripters = c.signatures
        .map(
          (s) => '''
  /// Script the response for `${s.name}` — the fake returns exactly
  /// this value (and records the call) while the script is set.
  void script${_pascal(s.name)}(${_returnType(s.returnType)} response) {
    _scripted${_pascal(s.name)} = () => response;
  }

  /// Script a THROWING outcome for `${s.name}`.
  void script${_pascal(s.name)}Error(Object error) {
    _scripted${_pascal(s.name)} = () => throw error;
  }
''',
        )
        .join('\n');
    final impls = c.signatures
        .map((s) {
          final args = _paramList(s.parameters);
          final argNames = s.parameters
              .map((p) => p.trim().split(' ').last)
              .toList();
          final recordArgs = argNames.isEmpty
              ? ''
              : ', arguments: {${argNames.map((a) => "'$a': $a").join(', ')}}';
          return '''
  @override
  ${_returnType(s.returnType)} ${s.name}($args) {
    _recorder.add('${s.name}'$recordArgs);
    final scripted = _scripted${_pascal(s.name)};
    if (scripted == null) {
      throw StateError(
        'unscripted call: ${c.name}.${s.name} — script it with '
        'script${_pascal(s.name)}() (an unscripted call is a test bug, '
        'never a silent default)',
      );
    }
    return scripted();
  }
''';
        })
        .join('\n');
    return '''
// GENERATED — certified fake for ${c.name} (issue #960).
//
// Scriptable per-method responses + a call recorder (method, named
// arguments, invocation order). An unscripted call is a NAMED error —
// a green here means the staged scenario happened.

${_classDoc(c)}
import '$dirName.dart';

class ${c.name}Fake implements ${c.name} {
  final _CallRecorder _recorder = _CallRecorder();
$slots

$scripters
$impls
}

/// Call recorder: (method, named arguments, invocation order) — query
/// per method for interaction assertions.
class _CallRecorder {
  final List<({String method, Map<String, Object?> arguments})> calls =
      <({String method, Map<String, Object?> arguments})>[];

  void add(String method, {Map<String, Object?> arguments = const {}}) =>
      calls.add((method: method, arguments: arguments));

  List<({String method, Map<String, Object?> arguments})> callsTo(
    String method,
  ) => calls.where((c) => c.method == method).toList();
}
''';
  }

  static String _fixtures(DependencyContract c) {
    final dirName = snake(c.name);
    final scenarios = c.signatures
        .map(
          (s) => '''
  /// Staged scenario for `${s.name}` — deterministic staging from the
  /// declared signature; the response is supplied by the test.
  static void ${s.name}(
    ${c.name}Fake fake,
    ${_returnType(s.returnType)} response,
  ) {
    fake.script${_pascal(s.name)}(response);
  }
''',
        )
        .join('\n');
    return '''
// GENERATED — fixture lane for ${c.name} (issue #960).

${_classDoc(c)}
import '${dirName}_fake.dart';

class ${c.name}Fixtures {
$scenarios
}
''';
  }
}
