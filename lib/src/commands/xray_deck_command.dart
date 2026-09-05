import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;
import '../core/project/project_root.dart';
import '../core/project/receipt_store.dart';
import '../domain/entities/feature_contract/feature_contract.dart';
import '../domain/entities/feature_contract/feature_contract_registry.dart';
import '../plugins/xray/xray_deck_barrel_writer.dart';
import '../version.dart';

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
      'feature',
      help:
          'Feature contract id (spec 1098). Resolves the declared contract '
          '(specs/<id>/contract.yaml), stamps @FeatureOwned onto the '
          'generated deck, and records the feature id in the proof '
          'receipt so the deck answers file→feature.',
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
    final featureId = argResults?["feature"] as String?;
    final projectRoot =
        (argResults?["root"] as String?) ?? ProjectRoot.safeCurrentPath();
    // Issue #1024: keep the user-typed flags for the proof receipt's
    // repro line before relative paths get resolved against the root.
    final repro = [
      'zfa',
      'xray',
      'deck',
      if (argResults?["source"] != null) '--source=${argResults!["source"]}',
      if (argResults?["yaml"] != null) '--yaml=${argResults!["yaml"]}',
      if (argResults?["output"] != null) '--output=${argResults!["output"]}',
      if (argResults?["usecase-name"] != null)
        '--usecase-name=${argResults!["usecase-name"]}',
      if (argResults?["entity"] != null) '--entity=${argResults!["entity"]}',
      if (argResults?["feature"] != null)
        {'--feature=${argResults!["feature"]}'},
      if (force) '--force',
    ].join(' ');
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

    // Spec 1098: resolve the feature contract BEFORE generating — an
    // unresolvable feature id must fail loudly, never stamp a deck with a
    // fabricated ownership anchor.
    FeatureContract? featureContract;
    if (featureId != null && featureId.isNotEmpty) {
      final registry = FeatureContractRegistry.scanProject(projectRoot);
      featureContract = registry.findById(featureId);
      if (featureContract == null) {
        final known = registry.knownIds.toList()..sort();
        print(
          'Error: unknown feature contract: "$featureId". '
          'Known contracts: '
          '${known.isEmpty ? "(none)" : known.join(", ")}. '
          'Declare it at specs/<feature-id>/contract.yaml (spec 1098).',
        );
        exitCode = 64;
        return;
      }
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

    final generated = _generateDeckFile(
      effectiveName,
      allEntries,
      featureId: featureContract?.id,
    );

    final outFile = File(effectiveOutput);
    final existed = outFile.existsSync();
    if (existed && !force) {
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

    // Issue #1024: proof receipt per deck generation (proof.v1). Records
    // the artifact digest under `<root>/.zfa/receipts/` so `zfa proof
    // check` can verify where this deck came from.
    await _emitDeckReceipt(
      projectRoot: projectRoot,
      useCaseName: effectiveName,
      outputAbsolutePath: effectiveOutput,
      created: !existed,
      entryCount: count,
      repro: repro,
      sourcePath: sourcePath,
      yamlPath: yamlPath,
      entityName: entityName,
      featureId: featureContract?.id,
    );

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

  /// Emits the deck registration file.
  ///
  /// Issue #1024: the deck MUST compile against the real runtime API —
  /// `XRayControlDeck.instance.registerEntries(List<XRayMockEntry>)` —
  /// with imports that resolve inside the consuming package:
  ///   - real runtime path `package:zuraffa/src/plugins/xray/…`
  ///     (the old `src/presentation/xray/` path never existed);
  ///   - explicit imports for [XRayMockEntry] / `XRayMockType`
  ///     (`xray_control_deck.dart` imports them without re-exporting);
  ///   - pure-Dart release guard `kXrayReleaseMode`
  ///     (`bool.fromEnvironment('dart.vm.product')`, behaviorally
  ///     identical to `kReleaseMode`) so the deck has no
  ///     `package:flutter` dependency and passes a `dart analyze`
  ///     compile gate in a plain-Dart sandbox;
  ///   - no `description:` named argument — [XRayMockEntry] has no such
  ///     parameter, so a YAML-provided description is preserved as a
  ///     doc comment above the entry;
  ///   - unrecognized `type:` values emit `XRayMockType.unknown`
  ///     (matching `XRayMockType.fromString`) instead of emitting an
  ///     enum value that does not exist.
  String _generateDeckFile(
    String ucName,
    List<Map<String, dynamic>> entries, {
    String? featureId,
  }) {
    final lines = <String>[
      // Spec 1098: the ownership anchor rides in the generated header so
      // the deck answers file→feature via the same annotation the slice
      // layer emits (read back by FeatureContractDecorators.scan).
      if (featureId != null) "// @FeatureOwned('$featureId')",
      '// GENERATED BY zfa xray deck -- DO NOT EDIT.',
      '// UseCase: $ucName',
      '// Mocks: ${entries.length}',
      '',
      "import 'package:zuraffa/src/core/xray_config.dart';",
      "import 'package:zuraffa/src/plugins/xray/xray_control_deck.dart';",
      "import 'package:zuraffa/src/plugins/xray/xray_mock_entry.dart';",
      "import 'package:zuraffa/src/plugins/xray/xray_mock_type.dart';",
      '',
      '/// Registers mock entries for $ucName with the Control Deck.',
      'void register${ucName}XRayDeck() {',
      '  if (kXrayReleaseMode) return;',
      '  XRayControlDeck.instance.registerEntries(',
      '    const [',
    ];

    for (final entry in entries) {
      final type = (entry['type'] ?? 'unknown').toString().toLowerCase();
      final name = _escapeLiteral(entry['name'].toString());
      final payload = _escapeLiteral(entry['payload'].toString());
      final desc = entry['description'];
      // Issue #1024: XRayMockEntry has no `description` parameter — keep
      // the scenario description as a doc comment instead of emitting a
      // named argument that fails `dart analyze`.
      if (desc != null) {
        lines.add('      /// ${_escapeLiteral(desc.toString())}');
      }
      lines.add('      XRayMockEntry(');
      lines.add("        name: '$name',");
      lines.add("        payload: '$payload',");
      lines.add('        type: XRayMockType.${_safeMockType(type)},');
      lines.add('      ),');
    }

    lines.addAll(['    ],', '  );', '}']);

    return lines.join('\n');
  }

  /// Maps a requested mock type to a real `XRayMockType` enum name so the
  /// generated deck always compiles (issue #1024 compile gate). Unknown
  /// values fall back to `unknown`, matching `XRayMockType.fromString`.
  String _safeMockType(String requested) {
    const known = {'valid', 'error', 'unknown'};
    if (known.contains(requested)) return requested;
    if (requested.isNotEmpty) {
      print(
        'Warning: unknown mock type "$requested" — '
        'emitting XRayMockType.unknown',
      );
    }
    return 'unknown';
  }

  /// Issue #1024: emit a proof.v1 generation receipt for the deck file
  /// this run wrote, digesting the final on-disk bytes.
  ///
  /// Best-effort by design (mirrors entity_command._emitReceipt): the
  /// artifact already exists, so a receipt failure degrades to a warning.
  Future<void> _emitDeckReceipt({
    required String projectRoot,
    required String useCaseName,
    required String outputAbsolutePath,
    required bool created,
    required int entryCount,
    required String repro,
    String? sourcePath,
    String? yamlPath,
    String? entityName,
    String? featureId,
  }) async {
    try {
      final file = File(outputAbsolutePath);
      if (!file.existsSync()) return;
      final bytes = file.readAsBytesSync();
      final keepSnapshot = bytes.length <= ReceiptStore.maxSnapshotBytes;
      await ReceiptStore(projectRoot: projectRoot).save(
        GenerationReceipt(
          command: 'xray deck',
          target: useCaseName,
          repro: repro,
          at: DateTime.now().toUtc(),
          generatorVersion: version,
          input: {
            'source': ?sourcePath,
            'yaml': ?yamlPath,
            'entity': ?entityName,
            'feature': ?featureId,
            'entries': entryCount,
            'api': 'XRayControlDeck.instance.registerEntries',
          },
          files: [
            GenerationReceiptFile(
              path: _projectRelativePosix(outputAbsolutePath, projectRoot),
              action: created ? 'create' : 'modify',
              sha256: crypto.sha256.convert(bytes).toString(),
              bytes: bytes.length,
              snapshot: keepSnapshot ? file.readAsStringSync() : null,
            ),
          ],
        ),
      );
      print('  Proof: receipt written to .zfa/receipts/ (proof.v1)');
    } catch (e) {
      print('⚠️  Generation receipt not written: $e');
    }
  }

  /// Normalizes a possibly-absolute artifact path to a project-relative
  /// POSIX path so receipts stay portable across machines.
  String _projectRelativePosix(String filePath, String projectRoot) {
    final rel = p.isAbsolute(filePath)
        ? p.relative(filePath, from: projectRoot)
        : filePath;
    return p.normalize(rel).replaceAll('\\', '/');
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
