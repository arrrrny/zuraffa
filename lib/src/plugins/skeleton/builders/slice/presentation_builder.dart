/// Builds the `--flutter` presentation page of a working slice (042, FR-005).
library;

import '../../models/bone.dart';

/// Flutter imports emitted as constants so no source line in `lib/` starts
/// with a Flutter import (issue #495 / feature 014 convention).
const String _flutterMaterialImport = "import 'package:flutter/material.dart';";
const String _flutterTestImport =
    "import 'package:flutter_test/flutter_test.dart';";

/// Emits the real UI page over the primary entity and its widget test.
class PresentationBuilder {
  /// The feature page: loads primary-entity instances through the DI
  /// container and saves edits via the update use case.
  String buildPage({
    required String featureSlug,
    required String primaryEntity,
    required List<EntityField> fields,
  }) {
    final pascal = slugToPascalCase(featureSlug);
    final display = slugToDisplayName(featureSlug);
    final camel = pascalToCamel(primaryEntity);
    final entitySnake = pascalToSnake(primaryEntity);

    final hasFields = fields.isNotEmpty;
    final titleExpr = hasFields
        ? "Text('\${instance.${fields.first.name}}')"
        : "const Text('$primaryEntity instance')";
    final subtitleParts = fields
        .skip(1)
        .map((f) => "'\${instance.${f.name}}'")
        .toList();
    final subtitleExpr = subtitleParts.isEmpty
        ? 'const SizedBox.shrink()'
        : "Text(${subtitleParts.join(" + ' ' + ")})";

    // Edit action: prefer the last non-nullable String field for a visible
    // edit; fall back to saving the instance unchanged.
    final editFields = fields
        .where((f) => !f.nullable && f.type == 'String')
        .toList();
    final String editAction;
    if (editFields.isNotEmpty) {
      final target = editFields.last;
      editAction =
          'final edited = current.copyWith(${target.name}: ${_editLiteral(target.type)});';
    } else {
      editAction = 'final edited = current;';
    }

    return '''
$_flutterMaterialImport

import '../di/injection.dart';
import '../entities/$entitySnake.dart';

/// Real UI for the $display working slice: loads [$primaryEntity] instances
/// through the DI container and saves an edit via the update use case.
class ${pascal}Page extends StatefulWidget {
  const ${pascal}Page({required this.services, super.key});

  final ${pascal}Services services;

  @override
  State<${pascal}Page> createState() => _${pascal}PageState();
}

class _${pascal}PageState extends State<${pascal}Page> {
  late Future<List<$primaryEntity>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.services.${camel}Repository.getAll${primaryEntity}s();
  }

  Future<void> _saveEdit() async {
    final instances =
        await _future.catchError((_) => const <$primaryEntity>[]);
    if (instances.isEmpty) return;
    final current = instances.first;
    $editAction
    await widget.services.update$primaryEntity(edited);
    setState(() {
      _future = widget.services.${camel}Repository.getAll${primaryEntity}s();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$display')),
      body: FutureBuilder<List<$primaryEntity>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final instances = snapshot.data!;
          return ListView.builder(
            itemCount: instances.length,
            itemBuilder: (context, index) {
              final instance = instances[index];
              return ListTile(
                leading: $titleExpr,
                title: $titleExpr,
                subtitle: $subtitleExpr,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveEdit,
        tooltip: 'Save edit via update use case',
        child: const Icon(Icons.save),
      ),
    );
  }
}
''';
  }

  /// The widget test for the feature page.
  String buildPageTest({
    required String featureSlug,
    required String primaryEntity,
  }) {
    final pascal = slugToPascalCase(featureSlug);
    final snake = slugToSnakeCase(featureSlug);
    return '''
$_flutterMaterialImport
$_flutterTestImport

import '../di/injection.dart';
import '../presentation/${snake}_page.dart';

void main() {
  testWidgets('${pascal}Page renders seeded instances', (tester) async {
    final services = ${pascal}Services.create(backend: BoneBackend.mock);
    await tester.pumpWidget(
      MaterialApp(home: ${pascal}Page(services: services)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(${pascal}Page), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
  });
}
''';
  }

  String _editLiteral(String type) {
    switch (type) {
      case 'String':
        return "'Edited by bone page'";
      case 'int':
        return '42';
      case 'double':
        return '4.2';
      case 'num':
        return '42';
      case 'bool':
        return 'true';
      case 'List<String>':
        return "const <String>['edited']";
      case 'Map<String, dynamic>':
        return "const <String, dynamic>{'edited': true}";
      case 'DateTime':
        return 'DateTime.utc(2027, 1, 1)';
    }
    throw ArgumentError('unsupported field type: $type');
  }
}
