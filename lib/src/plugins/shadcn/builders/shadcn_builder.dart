import 'package:path/path.dart' as path;

import '../../../core/generator_options.dart';
import '../../../core/plugin_system/discovery_engine.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
import '../../../utils/project_flavor.dart';
import '../../../utils/string_utils.dart';

class ShadcnBuilder {
  final String outputDir;
  final GeneratorOptions options;
  final DiscoveryEngine discovery;
  final FileSystem fileSystem;

  ShadcnBuilder({
    required this.outputDir,
    this.options = const GeneratorOptions(),
    DiscoveryEngine? discovery,
    FileSystem? fileSystem,
  }) : fileSystem = fileSystem ?? FileSystem.create(),
       discovery =
           discovery ??
           DiscoveryEngine(
             projectRoot: outputDir,
             fileSystem: fileSystem ?? FileSystem.create(),
           );

  Future<List<GeneratedFile>> generate(
    GeneratorConfig config,
    Map<String, dynamic> shadcnData,
  ) async {
    // #512: shadcn widgets are Flutter widgets (import
    // `package:flutter/material.dart` and `package:shadcn_ui/shadcn_ui.dart`)
    // and depend on zuraffa_flutter. In a pure-Dart target package
    // (pubspec.yaml without a `flutter:` dependency) emitting this code
    // violates Constitution VII (Engine Purity) and breaks `dart analyze`.
    // Skip with a clear warning.
    final flavor = await detectProjectFlavor(outputDir, fileSystem);
    if (flavor == ProjectFlavor.pureDart) {
      print(
        '⚠️ Skipping shadcn widget generation: target project is a pure-Dart '
        'package (no `flutter:` in pubspec.yaml). Shadcn widgets are Flutter '
        'widgets that depend on zuraffa_flutter (Constitution VII: Engine '
        'Purity). Run `zfa shadcn create` inside a Flutter project.',
      );
      return [];
    }

    final layout = shadcnData['layout'] ?? 'list';
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final domain = config.effectiveDomain;

    // Analyze entity to get fields
    final fields = EntityAnalyzer.analyzeEntity(
      entityName,
      outputDir,
      fileSystem: fileSystem,
    );
    final ignoreFields =
        (shadcnData['ignore-fields'] as List?)?.cast<String>() ?? [];

    final filteredFields = Map<String, String>.from(fields)
      ..removeWhere((key, _) => ignoreFields.contains(key));

    final fileName = '${entitySnake}_${layout}_widget.dart';
    final widgetDirPath = path.join(
      outputDir,
      'presentation',
      'widgets',
      domain,
    );
    final filePath = path.join(widgetDirPath, fileName);

    // Find entity file for import
    final entityFile = discovery.findFileSync('$entitySnake.dart');
    String entityImport;
    if (entityFile != null) {
      final relativePath = path.relative(entityFile.path, from: widgetDirPath);
      entityImport = "import '$relativePath';";
    } else {
      // Fallback
      entityImport =
          "import '../../../../domain/entities/$entitySnake/$entitySnake.dart';";
    }

    String content;
    switch (layout) {
      case 'form':
        content = _generateForm(entityName, filteredFields, entityImport);
        break;
      case 'list':
      default:
        content = _generateList(
          entityName,
          filteredFields,
          shadcnData,
          entityImport,
        );
        break;
    }

    final file = await FileUtils.writeFile(
      filePath,
      content,
      'shadcn_widget',
      force: options.force,
      dryRun: options.dryRun,
      verbose: options.verbose,
      revert: config.revert,
      fileSystem: fileSystem,
    );

    return [file];
  }

  String _generateList(
    String entityName,
    Map<String, String> fields,
    Map<String, dynamic> data,
    String entityImport,
  ) {
    final hasFilter = data['filter'] == true;
    final hasSort = data['sort'] == true;

    final lines = <String>[
      "import 'package:flutter/material.dart';",
      "import 'package:shadcn_ui/shadcn_ui.dart';",
      entityImport,
      '',
      'class ${entityName}ListWidget extends StatelessWidget {',
      '  final List<$entityName> items;',
      if (hasFilter) '  final Function(String)? onFilterChanged;',
      if (hasSort) '  final Function(String)? onSortChanged;',
      '',
      '  const ${entityName}ListWidget({',
      '    super.key,',
      '    required this.items,',
      if (hasFilter) '    this.onFilterChanged,',
      if (hasSort) '    this.onSortChanged,',
      '  });',
      '',
      '  @override',
      '  Widget build(BuildContext context) {',
      '    return Column(',
      '      children: [',
    ];

    if (hasFilter || hasSort) {
      lines.addAll([
        '        Padding(',
        '          padding: const EdgeInsets.all(8.0),',
        '          child: Row(',
        '            children: [',
        if (hasFilter) ...[
          '              Expanded(',
          '                child: ShadInput(',
          "                  placeholder: const Text('Filter $entityName...'),",
          '                  onChanged: onFilterChanged,',
          '                ),',
          '              ),',
        ],
        if (hasSort) ...[
          '              const SizedBox(width: 8),',
          '              ShadButton.outline(',
          "                child: const Text('Sort'),",
          "                onPressed: () => onSortChanged?.call('name'),",
          '              ),',
        ],
        '            ],',
        '          ),',
        '        ),',
      ]);
    }

    lines.addAll([
      '        Expanded(',
      '          child: ListView.builder(',
      '            itemCount: items.length,',
      '            itemBuilder: (context, index) {',
      '              final item = items[index];',
      '              return ShadCard(',
      if (fields.isNotEmpty) ...[
        '                title: Text(item.${fields.keys.first}),',
        if (fields.length > 1)
          '                description: Text(item.${fields.keys.elementAt(1)}.toString()),',
      ] else
        '                title: Text(item.toString()),',
      '              );',
      '            },',
      '          ),',
      '        ),',
      '      ],',
      '    );',
      '  }',
      '}',
    ]);

    return '${lines.join('\n')}\n';
  }

  String _generateForm(
    String entityName,
    Map<String, String> fields,
    String entityImport,
  ) {
    final lines = <String>[
      "import 'package:flutter/material.dart';",
      "import 'package:shadcn_ui/shadcn_ui.dart';",
      entityImport,
      '',
      'class ${entityName}FormWidget extends StatefulWidget {',
      '  final Function(Map<String, dynamic>) onSubmit;',
      '',
      '  const ${entityName}FormWidget({super.key, required this.onSubmit});',
      '',
      '  @override',
      '  State<${entityName}FormWidget> createState() => _${entityName}FormWidgetState();',
      '}',
      '',
      'class _${entityName}FormWidgetState extends State<${entityName}FormWidget> {',
      '  final formKey = GlobalKey<ShadFormState>();',
      '',
      '  @override',
      '  Widget build(BuildContext context) {',
      '    return ShadForm(',
      '      key: formKey,',
      '      child: Column(',
      '        children: [',
    ];

    if (fields.isEmpty) {
      lines.add("          const Text('No fields found for $entityName'),");
    } else {
      for (final entry in fields.entries) {
        final name = entry.key;
        final type = entry.value;
        lines.add('          ShadInputFormField(');
        lines.add("            id: '$name',");
        lines.add(
          "            label: const Text('${StringUtils.capitalize(name)}'),",
        );
        if (type.contains('int') || type.contains('double')) {
          lines.add('            keyboardType: TextInputType.number,');
        }
        lines.add('          ),');
      }
    }

    lines.addAll([
      '          const SizedBox(height: 16),',
      '          ShadButton(',
      "            child: const Text('Submit'),",
      '            onPressed: () {',
      '              if (formKey.currentState!.saveAndValidate()) {',
      '                widget.onSubmit(formKey.currentState!.value);',
      '              }',
      '            },',
      '          ),',
      '        ],',
      '      ),',
      '    );',
      '  }',
      '}',
    ]);

    return '${lines.join('\n')}\n';
  }
}
