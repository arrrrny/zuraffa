// Tests for ProvenanceRecord model (spec 051).
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/provenance_record.dart';

void main() {
  group('ProvenanceRecord', () {
    test('toJson and fromJson round-trip', () {
      final record = ProvenanceRecord(
        filePath: 'lib/src/domain/entities/product/product.dart',
        source: ProvenanceSource.cycleLog,
        invocation: 'zfa make Product --preset=crud',
        feature: '001-app-bootstrap',
        timestamp: '2026-08-31T12:00:00Z',
      );
      final json = record.toJson();
      final record2 = ProvenanceRecord.fromJson(json);
      expect(record2.filePath, 'lib/src/domain/entities/product/product.dart');
      expect(record2.source, ProvenanceSource.cycleLog);
      expect(record2.invocation, 'zfa make Product --preset=crud');
      expect(record2.feature, '001-app-bootstrap');
      expect(record2.timestamp, '2026-08-31T12:00:00Z');
    });

    test('setup source round-trips', () {
      final record = ProvenanceRecord(
        filePath: 'lib/main.dart',
        source: ProvenanceSource.setup,
        invocation: 'zfa setup myapp',
      );
      final json = record.toJson();
      final record2 = ProvenanceRecord.fromJson(json);
      expect(record2.source, ProvenanceSource.setup);
      expect(record2.feature, isNull);
    });
  });
}
