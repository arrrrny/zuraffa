import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/context/progress_reporter.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

Future<void> main(List<String> args) async {
  final iterations = args.isNotEmpty ? int.tryParse(args.first) ?? 3 : 3;
  final deltas = <int>[];
  final peaks = <int>[];

  for (var i = 0; i < iterations; i++) {
    final workspace = await _createWorkspace();
    final outputDir = path.join(workspace.path, 'lib', 'src');
    await _writeLargeEntity(outputDir, 'Profile', 10000);

    final config = GeneratorConfig(
      name: 'Profile',
      methods: const ['get', 'getList', 'create', 'update', 'delete'],
      generateData: true,
      generateVpc: true,
      generateState: true,
      generateDi: true,
      generateRoute: true,
      generateMock: true,
    );

    final generator = CodeGenerator(
      config: config,
      outputDir: outputDir,
      dryRun: false,
      force: true,
      verbose: false,
      progressReporter: NullProgressReporter(),
    );

    final before = ProcessInfo.currentRss;
    final result = await generator.generate();
    final after = ProcessInfo.currentRss;

    if (!result.success) {
      stderr.writeln(result.errors.join('\n'));
      exit(1);
    }

    deltas.add(after - before);
    peaks.add(after);
    await workspace.delete(recursive: true);
  }

  final avgDelta = deltas.reduce((a, b) => a + b) ~/ deltas.length;
  final maxPeak = peaks.reduce((a, b) => a > b ? a : b);

  final summary =
      'iterations=$iterations avg_delta_mb=${_toMb(avgDelta)} peak_mb=${_toMb(maxPeak)}';
  stderr.writeln(summary);
  final outFile = File(path.join('benchmark', '.last_memory.txt'));
  await outFile.writeAsString(summary);
}

Future<Directory> _createWorkspace() async {
  final dir = Directory(
    '${Directory.systemTemp.path}/zfa_bench_${DateTime.now().microsecondsSinceEpoch}',
  );
  return dir.create(recursive: true);
}

Future<void> _writeLargeEntity(
  String outputDir,
  String entityName,
  int fieldCount,
) async {
  final snake = _camelToSnake(entityName);
  final entityDir = Directory(
    path.join(outputDir, 'domain', 'entities', snake),
  );
  await entityDir.create(recursive: true);
  final file = File(path.join(entityDir.path, '$snake.dart'));

  final buffer = StringBuffer();
  buffer.writeln('class $entityName {');
  for (var i = 0; i < fieldCount; i++) {
    buffer.writeln('  final int field$i;');
  }
  buffer.writeln('  const $entityName({');
  for (var i = 0; i < fieldCount; i++) {
    buffer.writeln('    required this.field$i,');
  }
  buffer.writeln('  });');
  buffer.writeln('}');
  await file.writeAsString(buffer.toString());
}

String _camelToSnake(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (i > 0 && char.toUpperCase() == char) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

String _toMb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
