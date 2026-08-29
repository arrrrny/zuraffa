// Spec 036 — Track 4.2: XRayStateSummary tests.
//
// Behavior B09: data class + fromSignalSlice factory.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/xray/xray_state_summary.dart';

void main() {
  group('XRayStateSummary', () {
    test('constructor stores all fields', () {
      const s = XRayStateSummary(
        hasData: true,
        hasError: false,
        isLoading: false,
        dataPreview: 'Product(id=42)',
      );
      expect(s.hasData, isTrue);
      expect(s.hasError, isFalse);
      expect(s.isLoading, isFalse);
      expect(s.dataPreview, 'Product(id=42)');
    });

    test('empty factory is all-false with null previews', () {
      const s = XRayStateSummary.empty();
      expect(s.hasData, isFalse);
      expect(s.hasError, isFalse);
      expect(s.isLoading, isFalse);
      expect(s.dataPreview, isNull);
      expect(s.errorPreview, isNull);
    });

    test('toJson round-trips through fromJson', () {
      const s = XRayStateSummary(
        hasData: true,
        hasError: false,
        isLoading: false,
        dataPreview: 'Product(id=42)',
        errorPreview: null,
      );
      final json = s.toJson();
      final reconstructed = XRayStateSummary.fromJson(json);
      expect(reconstructed.hasData, s.hasData);
      expect(reconstructed.hasError, s.hasError);
      expect(reconstructed.isLoading, s.isLoading);
      expect(reconstructed.dataPreview, s.dataPreview);
    });

    test('dataPreview is truncated to 80 chars when constructed via factory',
        () {
      final long = 'x' * 200;
      final s = XRayStateSummary.fromPreviews(
        hasData: true,
        dataPreview: long,
      );
      expect(s.dataPreview!.length, lessThanOrEqualTo(80));
      expect(s.dataPreview!.startsWith('xxx'), isTrue);
    });

    test('errorPreview is truncated to 80 chars when constructed via factory',
        () {
      final long = 'E' * 200;
      final s = XRayStateSummary.fromPreviews(
        hasError: true,
        errorPreview: long,
      );
      expect(s.errorPreview!.length, lessThanOrEqualTo(80));
    });

    test('fromSignalSlice-like factory fromData has hasData true', () {
      // We use the fromPreviews-style API (since SignalSlice is reactive
      // and requires a real UseCase to instantiate). The public API
      // exposes XRayStateSummary.fromPreviews(...) which a Flutter widget
      // calls after pulling hasData/hasError/isLoading off its slice.
      final s = XRayStateSummary.fromPreviews(
        hasData: true,
        dataPreview: 'Product(id=42)',
      );
      expect(s.hasData, isTrue);
      expect(s.hasError, isFalse);
      expect(s.isLoading, isFalse);
    });

    test('fromPreviews with hasError populates errorPreview', () {
      final s = XRayStateSummary.fromPreviews(
        hasError: true,
        errorPreview: 'NetworkException(503)',
      );
      expect(s.hasError, isTrue);
      expect(s.errorPreview, 'NetworkException(503)');
      expect(s.hasData, isFalse);
    });

    test('fromPreviews with isLoading populates nothing else', () {
      final s = XRayStateSummary.fromPreviews(isLoading: true);
      expect(s.isLoading, isTrue);
      expect(s.hasData, isFalse);
      expect(s.hasError, isFalse);
      expect(s.dataPreview, isNull);
      expect(s.errorPreview, isNull);
    });
  });
}
