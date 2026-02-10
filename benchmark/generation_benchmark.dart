import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:zuraffa/src/core/context/progress_reporter.dart';
import 'package:zuraffa/src/generator/code_generator.dart';
import 'package:zuraffa/src/models/generator_config.dart';

Future<void> main(List<String> args) async {
  final iterations = args.isNotEmpty ? int.tryParse(args.first) ?? 5 : 5;
  final durations = <int>[];

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

    final stopwatch = Stopwatch()..start();
    final result = await generator.generate();
    stopwatch.stop();

    if (!result.success) {
      stderr.writeln(result.errors.join('\n'));
      exit(1);
    }

    durations.add(stopwatch.elapsedMilliseconds);
    await workspace.delete(recursive: true);
  }

  durations.sort();
  final min = durations.first;
  final max = durations.last;
  final avg = durations.reduce((a, b) => a + b) ~/ durations.length;

  final summary = 'iterations=$iterations min_ms=$min avg_ms=$avg max_ms=$max';
  stderr.writeln(summary);
  final outFile = File(path.join('benchmark', '.last_generation.txt'));
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
