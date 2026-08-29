// Spec 036 — Track 4.2: XRayBoxLabel format tests.
//
// Behavior B10: format produces canonical inline label string.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_box_label.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';

void main() {
  group('XRayBoxLabel', () {
    test('format produces canonical label with all four parts', () {
      const label = XRayBoxLabel(
        nodeId: 'ProfileViewNode.editProfileButton',
        status: 'enabled',
        boundAction: 'onEditTapped',
        stateSummary: XRayStateSummary(
          hasData: true,
          hasError: false,
          isLoading: false,
        ),
      );
      final formatted = label.format();
      expect(formatted, contains('ProfileViewNode.editProfileButton'));
      expect(formatted, contains('enabled'));
      expect(formatted, contains('onEditTapped'));
      expect(formatted, contains('data'));
    });

    test('format omits boundAction segment when null', () {
      const label = XRayBoxLabel(
        nodeId: 'HomeNode.fab',
        status: 'disabled',
        boundAction: null,
        stateSummary: XRayStateSummary.empty(),
      );
      final formatted = label.format();
      expect(formatted, contains('HomeNode.fab'));
      expect(formatted, contains('disabled'));
      expect(
        formatted,
        contains('idle'),
        reason: 'all-false state summary should be rendered as "idle"',
      );
    });

    test('format shows error state when hasError true', () {
      const label = XRayBoxLabel(
        nodeId: 'ProfileNode.saveButton',
        status: 'enabled',
        boundAction: 'onSave',
        stateSummary: XRayStateSummary(
          hasData: false,
          hasError: true,
          isLoading: false,
          errorPreview: 'NetworkException(503)',
        ),
      );
      final formatted = label.format();
      expect(formatted, contains('error'));
    });

    test('format shows loading state when isLoading true', () {
      const label = XRayBoxLabel(
        nodeId: 'ProfileNode.saveButton',
        status: 'enabled',
        boundAction: 'onSave',
        stateSummary: XRayStateSummary(
          hasData: false,
          hasError: false,
          isLoading: true,
        ),
      );
      final formatted = label.format();
      expect(formatted, contains('loading'));
    });

    test('format shows idle when all-false summary', () {
      const label = XRayBoxLabel(
        nodeId: 'n1',
        status: 'enabled',
        boundAction: 'onTap',
        stateSummary: XRayStateSummary.empty(),
      );
      final formatted = label.format();
      expect(formatted, contains('idle'));
    });

    test('format includes data preview when present', () {
      const label = XRayBoxLabel(
        nodeId: 'n1',
        status: 'enabled',
        boundAction: 'onTap',
        stateSummary: XRayStateSummary(
          hasData: true,
          hasError: false,
          isLoading: false,
          dataPreview: 'Product(id=42)',
        ),
      );
      final formatted = label.format();
      expect(formatted, contains('Product(id=42)'));
    });
  });
}
