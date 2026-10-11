// Spec 1115 — the audit bus carries the feature identifier (issue #1115
// item 4): SliceManifest's xrayLayer and the audit-bus's feature field are
// the SAME identifier — one FeatureContract.id flows through slice + xray +
// auditor + receipt.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/domain/entities/feature_contract/feature_id.dart';
import 'package:zuraffa/src/skin/skin_audit_controller.dart';

void main() {
  group('SkinAuditController.feature (spec 1115 #4)', () {
    test('is typed FeatureId and defaults to null', () {
      expect(SkinAuditController().feature, isNull);
      expect(
        SkinAuditController(feature: FeatureId.parse('004-login-ui')).feature,
        FeatureId.parse('004-login-ui'),
      );
    });

    test('the bus core still publishes violations unchanged', () {
      final controller = SkinAuditController(
        feature: FeatureId.parse('004-login-ui'),
      );
      expect(controller.publish(const []), isFalse);
      expect(controller.hasViolations, isFalse);
    });
  });
}
