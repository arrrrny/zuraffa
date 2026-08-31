/// Provenance auditor service (spec 051-corpus-harness, FR-005/FR-006).
///
/// Attributes every file under `lib/` to a logged zfa command invocation,
/// setup/import provenance, or a declared carve-out entry.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/provenance_record.dart';
import 'carve_out_manifest.dart';

class ProvenanceAuditResult {
  const ProvenanceAuditResult({
    required this.attributed,
    required this.carveOut,
    required this.unattributed,
  });

  final List<ProvenanceRecord> attributed;
  final List<ProvenanceRecord> carveOut;
  final List<String> unattributed;

  int get total => attributed.length + carveOut.length + unattributed.length;
  bool get isComplete => unattributed.isEmpty;
}

class ProvenanceAuditor {
  ProvenanceAuditor({
    required this.projectRoot,
    this.carveOutManifest,
  });

  final String projectRoot;
  final CarveOutManifest? carveOutManifest;

  /// Audit all lib/ files and return the attribution result.
  Future<ProvenanceAuditResult> audit() async {
    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!await libDir.exists()) {
      return const ProvenanceAuditResult(
        attributed: [],
        carveOut: [],
        unattributed: [],
      );
    }

    final libFiles = <String>[];
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relative = p.relative(entity.path, from: projectRoot);
        libFiles.add(relative);
      }
    }
    libFiles.sort();

    final attributed = <ProvenanceRecord>[];
    final carveOutRecords = <ProvenanceRecord>[];
    final unattributed = <String>[];

    // Load carve-out manifest.
    final manifest = carveOutManifest ?? CarveOutManifest(projectRoot);
    final carveOutEntries = await manifest.load();
    final carveOutPaths = {for (final e in carveOutEntries) e.path};

    // Parse cycle logs for green entries (generated files).
    final cycleLogFiles = await _parseCycleLogFiles();

    for (final filePath in libFiles) {
      // Check carve-out first.
      if (carveOutPaths.contains(filePath)) {
        final entry = carveOutEntries.firstWhere((e) => e.path == filePath);
        carveOutRecords.add(ProvenanceRecord(
          filePath: filePath,
          source: ProvenanceSource.importCarveOut,
          invocation: 'carve-out: ${entry.reason}',
        ));
        continue;
      }

      // Check cycle log entries.
      if (cycleLogFiles.containsKey(filePath)) {
        attributed.add(cycleLogFiles[filePath]!);
        continue;
      }

      // Check setup/import provenance (main.dart and scaffold files).
      if (_isSetupFile(filePath)) {
        attributed.add(ProvenanceRecord(
          filePath: filePath,
          source: ProvenanceSource.setup,
          invocation: 'zfa setup (scaffold)',
        ));
        continue;
      }

      unattributed.add(filePath);
    }

    return ProvenanceAuditResult(
      attributed: attributed,
      carveOut: carveOutRecords,
      unattributed: unattributed,
    );
  }

  /// Write provenance.json from the audit result.
  Future<void> writeReport(ProvenanceAuditResult result) async {
    final allRecords = [...result.attributed, ...result.carveOut];
    final map = {
      'records': allRecords.map((r) => r.toJson()).toList(),
      'unattributed': result.unattributed,
      'counts': {
        'attributed': result.attributed.length,
        'carve_out': result.carveOut.length,
        'unattributed': result.unattributed.length,
        'total': result.total,
      },
    };
    final dir = Directory(p.join(projectRoot, '.zfa', 'corpus'));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'provenance.json'));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(map),
    );
  }

  /// Parse cycle-log.md files across all features for green entries.
  Future<Map<String, ProvenanceRecord>> _parseCycleLogFiles() async {
    final result = <String, ProvenanceRecord>{};
    final specsDir = Directory(p.join(projectRoot, 'specs'));
    if (!await specsDir.exists()) return result;

    await for (final entity in specsDir.list()) {
      if (entity is! Directory) continue;
      final cycleLog = File(p.join(entity.path, 'tdd', 'cycle-log.md'));
      if (!await cycleLog.exists()) continue;

      final content = await cycleLog.readAsString();
      final featureName = p.basename(entity.path);

      // Parse green entries that record generated file paths.
      // Format: "- green: <description>" or file path references.
      final lines = content.split('\n');
      for (final line in lines) {
        if (!line.contains('green:') && !line.contains('generated:')) {
          continue;
        }
        // Extract file paths from green entries.
        final pathMatch = RegExp(r'(lib/[\w/]+\.dart)').firstMatch(line);
        if (pathMatch != null) {
          final filePath = pathMatch.group(1)!;
          result[filePath] = ProvenanceRecord(
            filePath: filePath,
            source: ProvenanceSource.cycleLog,
            invocation: 'zfa make (cycle log)',
            feature: featureName,
          );
        }
      }
    }
    return result;
  }

  /// Check if a file is a setup/scaffold file (main.dart, app shell, etc.).
  bool _isSetupFile(String filePath) {
    return filePath == 'lib/main.dart' ||
        filePath.endsWith('/main.dart') ||
        filePath.contains('app_shell');
  }
}
