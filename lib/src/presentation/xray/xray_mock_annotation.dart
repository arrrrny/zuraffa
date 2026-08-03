// X-Ray mock annotation -- marks UseCases with synthetic test payloads.
//
// Usage:
// ```dart
// @XRayMock(name: 'Valid Product A', payload: '123456789')
// class ScanBarcodeUseCase extends UseCase<Product, String> { ... }
//
// @XRayMock.fromYaml('assets/mocks/barcodes.yaml')
// class ScanBarcodeUseCase extends UseCase<Product, String> { ... }
// ```

/// Annotation for declaring synthetic mock payloads on UseCases.
///
/// These are scanned at build time by `zfa build` (or `zfa xray deck`)
/// to generate Control Deck entries. They are never included in release builds.
class XRayMock {
  /// Human-readable name shown on the Control Deck button.
  final String name;

  /// The synthetic payload to inject into the UseCase when tapped.
  /// Typically a JSON string, barcode value, or any raw input.
  final String payload;

  /// Optional type hint: 'valid', 'error', or null (unknown).
  /// Controls color coding on the Control Deck button.
  final String? type;

  /// Optional YAML file path containing mock scenarios.
  /// When non-null, the annotation acts as a YAML reference and
  /// [name]/[payload] may be empty.
  final String? yamlPath;

  /// Direct annotation with name and payload.
  const XRayMock({
    required this.name,
    required this.payload,
    this.type,
  }) : yamlPath = null;

  /// YAML-based annotation -- scenarios loaded from a file.
  const XRayMock.fromYaml(this.yamlPath)
      : name = '',
        payload = '',
        type = null;
}
