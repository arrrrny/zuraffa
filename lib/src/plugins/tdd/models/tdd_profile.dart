/// `TddProfile` entity — the machine-readable command map at
/// `.specify/memory/tdd-profile.md`.
library;

class TddProfile {
  final String runner;
  final String single;
  final String file;
  final String suite;
  final String coverage;

  const TddProfile({
    required this.runner,
    required this.single,
    required this.file,
    required this.suite,
    required this.coverage,
  });

  static const TddProfile flutter = TddProfile(
    runner: 'flutter_test',
    single: 'flutter test {file} --plain-name "{name}"',
    file: 'flutter test {file}',
    suite: 'flutter test',
    coverage: 'flutter test --coverage',
  );

  static const TddProfile dart = TddProfile(
    runner: 'dart',
    single: 'dart test {file} -P "{name}"',
    file: 'dart test {file}',
    suite: 'dart test',
    coverage: 'dart test --coverage',
  );

  String resolveSingle({required String file, required String name}) =>
      single.replaceAll('{file}', file).replaceAll('{name}', name);

  String resolveFile(String filePath) => file.replaceAll('{file}', filePath);

  String resolveSuite() => suite;

  String resolveCoverage() => coverage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TddProfile &&
          other.runner == runner &&
          other.single == single &&
          other.file == file &&
          other.suite == suite &&
          other.coverage == coverage);

  @override
  int get hashCode => Object.hash(runner, single, file, suite, coverage);

  @override
  String toString() => 'TddProfile(runner: $runner, suite: "$suite")';
}
