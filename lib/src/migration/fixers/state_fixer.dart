import 'dart:io';

import 'package:path/path.dart' as p;

import '../migration_models.dart';
import 'base_fixer.dart';

class StateMigrator extends MigrationFixer {
  @override
  String get migratorId => 'v5_mixed_state';

  @override
  String get displayName => 'State: v5 to v6 DomainState + ViewState';

  @override
  Future<MigrationResult> migrate({
    required List<MigrationFinding> findings,
    required String projectDir,
    bool dryRun = false,
  }) async {
    final actions = <MigrationAction>[];
    final remaining = <MigrationFinding>[];

    for (final finding in findings) {
      if (finding.ruleId != 'v5_mixed_state') {
        remaining.add(finding);
        continue;
      }

      final filePath = p.join(projectDir, finding.filePath);
      final file = File(filePath);
      if (!file.existsSync()) {
        remaining.add(finding);
        continue;
      }

      final content = file.readAsStringSync();
      final analysis = _analyzeStateFile(content);
      if (!analysis.needsMigration) {
        remaining.add(finding);
        continue;
      }

      final fileDir = p.dirname(filePath);
      final baseName = p.basenameWithoutExtension(filePath);
      final entityName = _extractEntityName(baseName);

      final domainStateContent = _buildDomainState(
        entityName,
        analysis.domainFields,
      );
      final viewStateContent = _buildViewState(entityName, analysis.uiFields);

      final domainStatePath = p.join(
        fileDir,
        '${_toSnake(entityName)}_domain_state.dart',
      );
      final viewStatePath = p.join(
        fileDir,
        '${_toSnake(entityName)}_view_state.dart',
      );

      actions.add(
        MigrationAction(
          description:
              'Create ${p.basename(domainStatePath)} with domain data fields',
          filePath: domainStatePath,
          action: 'created',
          newContent: domainStateContent,
        ),
      );

      actions.add(
        MigrationAction(
          description:
              'Create ${p.basename(viewStatePath)} with UI state fields',
          filePath: viewStatePath,
          action: 'created',
          newContent: viewStateContent,
        ),
      );

      actions.add(
        MigrationAction(
          description:
              'Annotate ${finding.filePath} as superseded by dual-layer state',
          filePath: filePath,
          action: 'modified',
          originalContent: content,
          newContent:
              '// NOTE: This file has been migrated to v6 dual-layer state.\n// See: ${p.basename(domainStatePath)} and ${p.basename(viewStatePath)}\n// This file can be removed once all references are updated.\n\n$content',
        ),
      );

      if (!dryRun) {
        File(domainStatePath)
          ..createSync(recursive: true)
          ..writeAsStringSync(domainStateContent);
        File(viewStatePath)
          ..createSync(recursive: true)
          ..writeAsStringSync(viewStateContent);
        file.writeAsStringSync(
          '// NOTE: This file has been migrated to v6 dual-layer state.\n// See: ${p.basename(domainStatePath)} and ${p.basename(viewStatePath)}\n// This file can be removed once all references are updated.\n\n$content',
        );
      }
    }

    return MigrationResult(
      migratorId: migratorId,
      actions: actions,
      remaining: remaining,
    );
  }

  _StateAnalysis _analyzeStateFile(String content) {
    String? className;
    int classLine = 0;
    final domainFields = <_FieldInfo>[];
    final uiFields = <_FieldInfo>[];

    final classMatch = RegExp(r'class\s+(\w+State)\b').firstMatch(content);
    if (classMatch != null) {
      className = classMatch.group(1);
      classLine = _lineNumber(content, classMatch.start);
    }

    if (className == null) {
      return _StateAnalysis(
        className: '<unknown>',
        classLine: 0,
        domainFields: [],
        uiFields: [],
        needsMigration: false,
      );
    }

    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      final fieldMatch = RegExp(
        r'^(?:final\s+)?([\w<>?]+)\s+(\w+)\s*[;=]',
      ).firstMatch(trimmed);
      if (fieldMatch == null) continue;

      final type = fieldMatch.group(1)!;
      final name = fieldMatch.group(2)!;
      if (name.startsWith('_')) continue;

      String? doc;
      if (i > 0 && lines[i - 1].trim().startsWith('///')) {
        doc = lines[i - 1].trim().substring(3).trim();
      }

      final info = _FieldInfo(name: name, type: type, doc: doc);

      if (_isUiField(type, name)) {
        uiFields.add(info);
      } else {
        domainFields.add(info);
      }
    }

    return _StateAnalysis(
      className: className,
      classLine: classLine,
      domainFields: domainFields,
      uiFields: uiFields,
      needsMigration: domainFields.isNotEmpty && uiFields.isNotEmpty,
    );
  }

  bool _isUiField(String type, String name) {
    if ((type == 'bool' || type == 'bool?') &&
        (name.startsWith('is') || name.startsWith('has'))) {
      return true;
    }
    if (name == 'error' || type == 'AppFailure?' || type == 'AppFailure') {
      return true;
    }
    if (name == 'isLoading' || name == 'isRefreshing') return true;
    if (name == 'offset' || name == 'limit' || name == 'hasMore') return true;
    return false;
  }

  String _buildDomainState(String entityName, List<_FieldInfo> fields) {
    final entityCamel = entityName[0].toLowerCase() + entityName.substring(1);
    final buf = StringBuffer();
    buf.writeln(
      "// GENERATED by 'zfa migrate state' -- review and adjust as needed.",
    );
    buf.writeln("import 'package:zuraffa/zuraffa.dart';");
    buf.writeln();
    buf.writeln('/// Domain state for $entityName.');
    buf.writeln('class ${entityName}DomainState extends DomainState {');
    buf.writeln('  ${entityName}DomainState({required super.presenter});');
    buf.writeln();

    if (fields.isEmpty) {
      buf.writeln('  // No domain data fields detected in original state.');
      buf.writeln('  // Add slice bindings here manually, e.g.:');
      buf.writeln(
        "  // late final $entityCamel = bind<$entityName>('$entityCamel', get${entityName}UseCase, params);",
      );
    } else {
      for (final field in fields) {
        final typeName = _stripNull(field.type);
        buf.writeln('  /// ${field.doc ?? "Bound $typeName slice"}');
        buf.writeln("  // TODO: Replace useCase and params");
        buf.writeln(
          "  // late final ${field.name} = bind<$typeName>('${field.name}', useCase, params);",
        );
        buf.writeln();
      }
    }

    buf.writeln('}');
    return buf.toString();
  }

  String _buildViewState(String entityName, List<_FieldInfo> fields) {
    final buf = StringBuffer();
    buf.writeln(
      "// GENERATED by 'zfa migrate state' -- review and adjust as needed.",
    );
    buf.writeln("import 'package:flutter/material.dart';");
    buf.writeln();
    buf.writeln('/// View (transient UI) state for $entityName.');
    buf.writeln('class ${entityName}ViewState extends ChangeNotifier {');
    buf.writeln();

    if (fields.isEmpty) {
      buf.writeln('  // No transient UI state fields detected.');
    } else {
      // Declare private backing fields
      for (final field in fields) {
        final declaredType = field.type.endsWith('?')
            ? field.type
            : '${field.type}?';
        final initValue = _defaultInitValue(field.type);
        buf.writeln('  $declaredType _${field.name} = $initValue;');
      }
      buf.writeln();

      // Generate getters
      for (final field in fields) {
        buf.writeln('  /// ${field.doc ?? field.name}');
        buf.writeln(
          '  ${field.type} get ${field.name} => _${field.name}${field.type.endsWith('?') ? '' : '!'};',
        );
      }
      buf.writeln();

      // Generate setters
      for (final field in fields) {
        buf.writeln('  set ${field.name}(${field.type} value) {');
        buf.writeln('    _${field.name} = value;');
        buf.writeln('    notifyListeners();');
        buf.writeln('  }');
        buf.writeln();
      }
    }

    buf.writeln('}');
    return buf.toString();
  }

  String _defaultInitValue(String type) {
    if (type == 'bool' || type == 'bool?') return 'false';
    if (type == 'int' || type == 'int?') return '0';
    if (type == 'double' || type == 'double?') return '0.0';
    if (type == 'String' || type == 'String?') return "''";
    return 'null';
  }

  String _stripNull(String type) => type.replaceAll('?', '');

  String _extractEntityName(String baseName) {
    final parts = baseName.replaceAll('_state', '').split('_');
    return parts
        .where((segment) => segment.isNotEmpty)
        .map((segment) => segment[0].toUpperCase() + segment.substring(1))
        .join();
  }

  String _toSnake(String name) {
    final result = StringBuffer();
    for (int i = 0; i < name.length; i++) {
      if (i > 0 && name[i].toUpperCase() == name[i] && name[i - 1] != '_') {
        result.write('_');
      }
      result.write(name[i].toLowerCase());
    }
    return result.toString();
  }

  int _lineNumber(String content, int offset) {
    return '\n'.allMatches(content.substring(0, offset)).length + 1;
  }
}

class _StateAnalysis {
  final String className;
  final int classLine;
  final List<_FieldInfo> domainFields;
  final List<_FieldInfo> uiFields;
  final bool needsMigration;

  const _StateAnalysis({
    required this.className,
    required this.classLine,
    required this.domainFields,
    required this.uiFields,
    required this.needsMigration,
  });
}

class _FieldInfo {
  final String name;
  final String type;
  final String? doc;
  const _FieldInfo({required this.name, required this.type, this.doc});
}
