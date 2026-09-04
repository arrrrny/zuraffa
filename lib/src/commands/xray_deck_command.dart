import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;
import '../plugins/xray/xray_deck_barrel_writer.dart';
import '../core/project/project_root.dart';

/// CLI subcommand for generating X-Ray Control Deck code.
class XrayDeckCommand extends Command<void> {
  @override
  String get name => 'deck';

  @override
  String get description =>
      'Generate X-Ray Control Deck registration from annotations or YAML';

  XrayDeckCommand() {
    argParser.addOption(
      'source',
      abbr: 's',
      help: 'Dart source file to scan for @XRayMock annotations',
    );
    argParser.addOption(
      'yaml',
      abbr: 'y',
      help: 'YAML file with mock scenarios',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output file path for the generated deck registration',
    );
    argParser.addOption(
      'usecase-name',
      abbr: 'n',
      help: 'UseCase name (auto-detected from source if omitted)',
    );
    argParser.addFlag(
      'force',
      abbr: 'f',
      help: 'Overwrite existing output file',
      negatable: false,
    );
    argParser.addOption(
      'entity',
      help:
          'Entity name (PascalCase). When set, defaults --output '
          'to lib/src/xray/<entity_snake>_xray_deck.dart, '
          '--usecase-name to <Entity>, and updates the barrel at '
          'lib/src/xray/xray_decks.dart (issue #360).',
    );
    argParser.addOption(
      'root',
      help:
          'Project root to generate the deck in (default: current directory). '
          'Lets tests run against an explicit sandbox instead of relying on '
          'the process working directory.',
    );
  }

  @override
  Future<void> run() async {
    var sourcePath = argResults?["source"] as String?;
    var yamlPath = argResults?["yaml"] as String?;
    var outputPath = argResults?["output"] as String?;
    var useCaseName = argResults?["usecase-name"] as String?;
    final force = argResults?["force"] as bool? ?? false;
    final entityName = argResults?["entity"] as String?;
    final projectRoot =
        (argResults?["root"] as String?) ?? ProjectRoot.safeCurrentPath();
    // Resolve relative source/yaml paths against the project root so the
    // command works hermetically (e.g. from an explicit --root sandbox).
    if (sourcePath != null && !p.isAbsolute(sourcePath)) {
      sourcePath = p.join(projectRoot, sourcePath);
    }
    if (yamlPath != null && !p.isAbsolute(yamlPath)) {
      yamlPath = p.join(projectRoot, yamlPath);
    }

    // #360: --entity adjusts defaults + triggers barrel update.
    String? entitySnake;
    if (entityName != null) {
      entitySnake = _toSnakeCase(entityName);
      outputPath ??= p.join(
        "lib",
        "src",
        "xray",
        "${entitySnake}_xray_deck.dart",
      );
      useCaseName ??= entityName;

      // When --entity is provided without --source or --yaml, auto-discover
      // matching usecase files.
      if (sourcePath == null && yamlPath == null) {
        final usecasesDir = p.join(
          projectRoot,
          'lib',
          'src',
          'domain',
          'usecases',
        );
        final dir = Directory(usecasesDir);
        if (dir.existsSync()) {
          final matchingFiles = <String>[];
          for (final subDir in dir.listSync().whereType<Directory>()) {
            for (final file in subDir.listSync().whereType<File>()) {
              final fileName = p.basename(file.path);
              if (fileName.contains('_${entitySnake}_usecase.dart')) {
                matchingFiles.add(file.path);
              }
            }
          }
          if (matchingFiles.isNotEmpty) {
            // Use the first matching file as the default source.
            sourcePath = matchingFiles.first;
          }
        }
      }
    }

    if (sourcePath == null && yamlPath == null) {
      print('Error: provide --source and/or --yaml');
      exitCode = 64;
      return;
    }

    final effectiveOutput = p.join(
      projectRoot,
      outputPath ?? _defaultOutputPath(sourcePath, yamlPath),
    );
    final effectiveName = useCaseName ?? _detectUseCaseName(sourcePath);

    if (effectiveName == null) {
      print('Error: could not determine UseCase name. Use --usecase-name.');
      exitCode = 2;
      return;
    }

    final annotationEntries = sourcePath != null
        ? _scanAnnotations(sourcePath)
        : <Map<String, dynamic>>[];
    final yamlEntries = yamlPath != null
        ? _parseYamlFile(yamlPath)
        : <Map<String, dynamic>>[];

    final allEntries = [...annotationEntries, ...yamlEntries];

    if (allEntries.isEmpty) {
      print('No mock scenarios found.');
      exitCode = 1;
      return;
    }

    final generated = _generateDeckFile(effectiveName, allEntries);

    final outFile = File(effectiveOutput);
    if (outFile.existsSync() && !force) {
      print('Error: $effectiveOutput already exists. Use --force.');
      exitCode = 1;
      return;
    }

    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(generated);

    final count = allEntries.length;
    final suffix = count == 1 ? 'y' : 'ies';
    print('Generated $count mock entr$suffix for $effectiveName');
    print('  Output: $effectiveOutput');

    // #360: update the registration barrel so main.dart's
    // `registerAllXRayDecks()` call wires this deck.
    if (entityName != null) {
      final writer = XRayDeckBarrelWriter(projectRoot: projectRoot);
      final deckAbsPath = effectiveOutput;
      final registerFn = 'register${effectiveName}XRayDeck';
      final result = writer.update(
        entityName: entityName,
        deckFilePath: deckAbsPath,
        registerFunctionName: registerFn,
      );
      print('  Barrel: ${result.message}');
      if (result.created) {
        print(
          '    (run `zfa app shell --xray --force` to wire into main.dart)',
        );
      }
    }
  }

  String _defaultOutputPath(String? sourcePath, String? yamlPath) {
    final base = sourcePath ?? yamlPath ?? 'unknown';
    final slashIdx = base.lastIndexOf('/');
    final dir = slashIdx >= 0 ? base.substring(0, slashIdx) : '.';
    final name = slashIdx >= 0
        ? base
              .substring(slashIdx + 1)
              .replaceAll('.dart', '')
              .replaceAll('.yaml', '')
        : base;
    return '$dir/${name}_xray_deck.dart';
  }

  String? _detectUseCaseName(String? sourcePath) {
    if (sourcePath == null) return null;
    final slashIdx = sourcePath.lastIndexOf('/');
    final fileName = slashIdx >= 0
        ? sourcePath.substring(slashIdx + 1)
        : sourcePath;
    final parts = fileName.replaceAll('.dart', '').split('_');
    return parts.map((p) {
      if (p.isEmpty) return '';
      // Preserve the expected "UseCase" casing (two capitalized words)
      // instead of collapsing it to "Usecase".
      if (p.toLowerCase() == 'usecase') return 'UseCase';
      return p[0].toUpperCase() + p.substring(1).toLowerCase();
    }).join();
  }

  List<Map<String, dynamic>> _scanAnnotations(String sourcePath) {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      print('Warning: source file not found: $sourcePath');
      return [];
    }

    final content = file.readAsStringSync();
    final entries = <Map<String, dynamic>>[];

    // Match @XRayMock(name: ..., payload: ..., type: ...)
    final regex = RegExp(r'@XRayMock\(([^)]+)\)');
    for (final match in regex.allMatches(content)) {
      final body = match.group(1)!;
      final name = _extractField(body, 'name');
      final payload = _extractField(body, 'payload');
      final type = _extractField(body, 'type');

      if (name != null && payload != null) {
        entries.add({'name': name, 'payload': payload, 'type': ?type});
      }
    }

    // Match @XRayMock.fromYaml('path')
    final fromYamlMarker = '@XRayMock.fromYaml(';
    var searchIdx = 0;
    while (searchIdx < content.length) {
      final idx = content.indexOf(fromYamlMarker, searchIdx);
      if (idx < 0) break;
      final rest = content.substring(idx + fromYamlMarker.length);
      String? path;
      if (rest.startsWith("'") || rest.startsWith('"')) {
        final quote = rest[0];
        final end = rest.indexOf(quote, 1);
        if (end > 0) {
          path = rest.substring(1, end);
        }
      }
      if (path != null) {
        entries.addAll(_parseYamlFile(path));
      }
      searchIdx = idx + fromYamlMarker.length + 1;
    }

    return entries;
  }

  String? _extractField(String body, String field) {
    // Build regex matching field: 'value' or field: "value"
    // We avoid raw strings with mixed quotes by concatenating.
    final ws = r'\s*:\s*';
    final qClass = "['\\x22]"; // character class: single-quote or double-quote
    final qNeg = "[^'\\x22]*"; // negated class: any char except quotes
    final pattern = '$field$ws$qClass($qNeg)$qClass';
    final regex = RegExp(pattern);
    final match = regex.firstMatch(body);
    return match?.group(1);
  }

  List<Map<String, dynamic>> _parseYamlFile(String yamlPath) {
    final file = File(yamlPath);
    if (!file.existsSync()) {
      print('Warning: YAML file not found: $yamlPath');
      return [];
    }
    try {
      final content = file.readAsStringSync();
      final yaml = loadYaml(content);
      if (yaml is! YamlList) return [];
      return yaml
          .whereType<YamlMap>()
          .map((m) {
            final name = m['name'];
            final payload = m['payload'];
            if (name == null || payload == null) return null;
            return <String, dynamic>{
              'name': name.toString(),
              'payload': payload.toString(),
              if (m['type'] != null) 'type': m['type'].toString(),
              if (m['description'] != null)
                'description': m['description'].toString(),
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('Warning: failed to parse YAML: $yamlPath');
      return [];
    }
  }

  String _escapeLiteral(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$');
  }

  String _generateDeckFile(String ucName, List<Map<String, dynamic>> entries) {
    final lines = <String>[
      '// GENERATED BY zfa xray deck -- DO NOT EDIT.',
      '// UseCase: $ucName',
      '// Mocks: ${entries.length}',
      '',
      "import 'package:flutter/foundation.dart';",
      "import 'package:zuraffa/src/presentation/xray/xray_control_deck.dart';",
      '',
      '/// Registers mock entries for $ucName with the Control Deck.',
      'void register${ucName}XRayDeck() {',
      '  if (kReleaseMode) return;',
      '  XRayControlDeckRegistry.registerEntries(',
      "  '$ucName',",
      '    const [',
    ];

    for (final entry in entries) {
      final type = (entry['type'] ?? 'unknown').toString();
      final name = _escapeLiteral(entry['name'].toString());
      final payload = _escapeLiteral(entry['payload'].toString());
      final desc = entry['description'];
      final descPart = desc != null
          ? ", description: '${_escapeLiteral(desc.toString())}'"
          : '';
      lines.add('      XRayMockEntry(');
      lines.add("        name: '$name',");
      lines.add("        payload: '$payload',");
      lines.add('        type: XRayMockType.$type$descPart,');
      lines.add('      ),');
    }

    lines.addAll(['    ],', '  );', '}']);

    return lines.join('\n');
  }
}

// Helper: PascalCase -> snake_case.
String _toSnakeCase(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char.toUpperCase() == char && char.toLowerCase() != char) {
      if (i > 0) buffer.write('_');
      buffer.write(char.toLowerCase());
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}
