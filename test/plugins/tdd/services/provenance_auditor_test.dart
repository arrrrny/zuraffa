// Tests for ProvenanceAuditor (spec 051, U22-U26).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/carve_out_entry.dart';
import 'package:zuraffa/src/plugins/tdd/services/provenance_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/carve_out_manifest.dart';

void main() {
  late Directory tmpDir;
  late ProvenanceAuditor auditor;

  setUp(() async {
    tmpDir = Directory.systemTemp.createTempSync('provenance_auditor_test_');
    // Create minimal lib/ structure.
    final libDir = Directory(p.join(tmpDir.path, 'lib', 'src'));
    await libDir.create(recursive: true);
    await File(p.join(libDir.path, 'product.dart')).writeAsString(
      'class Product {}',
    );
    await File(p.join(tmpDir.path, 'lib', 'main.dart')).writeAsString(
      'void main() {}',
    );
    auditor = ProvenanceAuditor(projectRoot: tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  group('ProvenanceAuditor', () {
    test('[U22] attributes lib/ file found in cycle-log green entries', () async {
      // Create a cycle log that references product.dart.
      final specsDir = Directory(p.join(tmpDir.path, 'specs', '001-ready', 'tdd'));
      await specsDir.create(recursive: true);
      await File(p.join(specsDir.path, 'cycle-log.md')).writeAsString(
        '## Cycle 1\n- green: generated lib/src/product.dart via zfa make Product',
      );

      final result = await auditor.audit();
      final productRecord = result.attributed.where(
        (r) => r.filePath == 'lib/src/product.dart',
      );
      expect(productRecord.length, 1);
      expect(productRecord.first.source.name, 'cycleLog');
    });

    test('[U23] attributes lib/ file found in carve-out manifest', () async {
      final manifest = CarveOutManifest(tmpDir.path);
      await manifest.add(
        const CarveOutEntry(
          path: 'lib/src/product.dart',
          reason: 'manual UI layout',
          addedBy: 'maintainer',
          addedAt: '2026-08-31T12:00:00Z',
        ),
      );

      final result = await auditor.audit();
      final productRecord = result.carveOut.where(
        (r) => r.filePath == 'lib/src/product.dart',
      );
      expect(productRecord.length, 1);
    });

    test('[U24] marks lib/ file with no provenance as UNATTRIBUTED', () async {
      // product.dart has no cycle-log and no carve-out.
      final result = await auditor.audit();
      expect(result.unattributed, contains('lib/src/product.dart'));
    });

    test('[U25] writes provenance.json with per-file attribution map', () async {
      final specsDir = Directory(p.join(tmpDir.path, 'specs', '001', 'tdd'));
      await specsDir.create(recursive: true);
      await File(p.join(specsDir.path, 'cycle-log.md')).writeAsString(
        '- green: generated lib/src/product.dart',
      );

      final result = await auditor.audit();
      await auditor.writeReport(result);

      final reportFile = File(p.join(tmpDir.path, '.zfa', 'corpus', 'provenance.json'));
      expect(await reportFile.exists(), true);
      final content = await reportFile.readAsString();
      expect(content, contains('lib/src/product.dart'));
      expect(content, contains('"counts"'));
    });

    test('[U26] summary counts match actual file counts', () async {
      final result = await auditor.audit();
      final total = result.attributed.length + result.carveOut.length + result.unattributed.length;
      expect(result.total, total);
      expect(result.total, greaterThanOrEqualTo(2)); // main.dart + product.dart
    });

    test('[U24] attributes main.dart as setup file', () async {
      final result = await auditor.audit();
      final mainRecord = result.attributed.where(
        (r) => r.filePath == 'lib/main.dart',
      );
      expect(mainRecord.length, 1);
      expect(mainRecord.first.source.name, 'setup');
    });
  });
}
