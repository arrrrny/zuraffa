import 'package:path/path.dart' as path;
import '../../../core/generator_options.dart';
import '../../../core/plugin_system/discovery_engine.dart';
import '../../../core/context/file_system.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/entity_analyzer.dart';
import '../../../utils/file_utils.dart';
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
  }) : fileSystem = fileSystem ?? FileSystem.create(root: outputDir),
       discovery =
           discovery ??
           DiscoveryEngine(
             projectRoot: outputDir,
             fileSystem: fileSystem ?? FileSystem.create(root: outputDir),
           );

  Future<List<GeneratedFile>> generate(
    GeneratorConfig config,
    Map<String, dynamic> shadcnData,
  ) async {
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

    final buffer = StringBuffer();
    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln("import 'package:shadcn_ui/shadcn_ui.dart';");
    buffer.writeln(entityImport);
    buffer.writeln();
    buffer.writeln("class ${entityName}ListWidget extends StatelessWidget {");
    buffer.writeln("  final List<$entityName> items;");
    if (hasFilter) buffer.writeln("  final Function(String)? onFilterChanged;");
    if (hasSort) buffer.writeln("  final Function(String)? onSortChanged;");
    buffer.writeln();
    buffer.writeln("  const ${entityName}ListWidget({");
    buffer.writeln("    super.key,");
    buffer.writeln("    required this.items,");
    if (hasFilter) buffer.writeln("    this.onFilterChanged,");
    if (hasSort) buffer.writeln("    this.onSortChanged,");
    buffer.writeln("  });");
    buffer.writeln();
    buffer.writeln("  @override");
    buffer.writeln("  Widget build(BuildContext context) {");
    buffer.writeln("    return Column(");
    buffer.writeln("      children: [");

    if (hasFilter || hasSort) {
      buffer.writeln("        Padding(");
      buffer.writeln("          padding: const EdgeInsets.all(8.0),");
      buffer.writeln("          child: Row(");
      buffer.writeln("            children: [");
      if (hasFilter) {
        buffer.writeln("              Expanded(");
        buffer.writeln("                child: ShadInput(");
        buffer.writeln(
          "                  placeholder: const Text('Filter $entityName...'),",
        );
        buffer.writeln("                  onChanged: onFilterChanged,");
        buffer.writeln("                ),");
        buffer.writeln("              ),");
      }
      if (hasSort) {
        buffer.writeln("              const SizedBox(width: 8),");
        buffer.writeln("              ShadButton.outline(");
        buffer.writeln("                child: const Text('Sort'),");
        buffer.writeln(
          "                onPressed: () => onSortChanged?.call('name'),",
        );
        buffer.writeln("              ),");
      }
      buffer.writeln("            ],");
      buffer.writeln("          ),");
      buffer.writeln("        ),");
    }

    buffer.writeln("        Expanded(");
    buffer.writeln("          child: ListView.builder(");
    buffer.writeln("            itemCount: items.length,");
    buffer.writeln("            itemBuilder: (context, index) {");
    buffer.writeln("              final item = items[index];");
    buffer.writeln("              return ShadCard(");
    if (fields.isNotEmpty) {
      buffer.writeln("                title: Text(item.${fields.keys.first}),");
      if (fields.length > 1) {
        buffer.writeln(
          "                description: Text(item.${fields.keys.elementAt(1)}.toString()),",
        );
      }
    } else {
      buffer.writeln("                title: Text(item.toString()),");
    }
    buffer.writeln("              );");
    buffer.writeln("            },");
    buffer.writeln("          ),");
    buffer.writeln("        ),");
    buffer.writeln("      ],");
    buffer.writeln("    );");
    buffer.writeln("  }");
    buffer.writeln("}");

    return buffer.toString();
  }

  String _generateForm(
    String entityName,
    Map<String, String> fields,
    String entityImport,
  ) {
    final buffer = StringBuffer();
    buffer.writeln("import 'package:flutter/material.dart';");
    buffer.writeln("import 'package:shadcn_ui/shadcn_ui.dart';");
    buffer.writeln(entityImport);
    buffer.writeln();
    buffer.writeln("class ${entityName}FormWidget extends StatefulWidget {");
    buffer.writeln("  final Function(Map<String, dynamic>) onSubmit;");
    buffer.writeln();
    buffer.writeln(
      "  const ${entityName}FormWidget({super.key, required this.onSubmit});",
    );
    buffer.writeln();
    buffer.writeln("  @override");
    buffer.writeln(
      "  State<${entityName}FormWidget> createState() => _${entityName}FormWidgetState();",
    );
    buffer.writeln("}");
    buffer.writeln();
    buffer.writeln(
      "class _${entityName}FormWidgetState extends State<${entityName}FormWidget> {",
    );
    buffer.writeln("  final formKey = GlobalKey<ShadFormState>();");
    buffer.writeln();
    buffer.writeln("  @override");
    buffer.writeln("  Widget build(BuildContext context) {");
    buffer.writeln("    return ShadForm(");
    buffer.writeln("      key: formKey,");
    buffer.writeln("      child: Column(");
    buffer.writeln("        children: [");

    if (fields.isEmpty) {
      buffer.writeln(
        "          const Text('No fields found for $entityName'),",
      );
    } else {
      for (final entry in fields.entries) {
        final name = entry.key;
        final type = entry.value;
        buffer.writeln("          ShadInputFormField(");
        buffer.writeln("            id: '$name',");
        buffer.writeln(
          "            label: const Text('${StringUtils.capitalize(name)}'),",
        );
        if (type.contains('int') || type.contains('double')) {
          buffer.writeln("            keyboardType: TextInputType.number,");
        }
        buffer.writeln("          ),");
      }
    }

    buffer.writeln("          const SizedBox(height: 16),");
    buffer.writeln("          ShadButton(");
    buffer.writeln("            child: const Text('Submit'),");
    buffer.writeln("            onPressed: () {");
    buffer.writeln(
      "              if (formKey.currentState!.saveAndValidate()) {",
    );
    buffer.writeln(
      "                widget.onSubmit(formKey.currentState!.value);",
    );
    buffer.writeln("              }");
    buffer.writeln("            },");
    buffer.writeln("          ),");
    buffer.writeln("        ],");
    buffer.writeln("      ),");
    buffer.writeln("    );");
    buffer.writeln("  }");
    buffer.writeln("}");

    return buffer.toString();
  }
}
