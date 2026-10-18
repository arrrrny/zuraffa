/// `ThemeImporter` — W3C design-token ingestion (issue #817).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

class ThemeImportResult {
  final String tokensPath;
  final String projectRoot;
  final String outputPath;
  final Map<String, String> colors;
  final Map<String, dynamic> typography;
  final Map<String, dynamic> spacing;
  final List<String> contrastLines;
  final List<String> violations;
  final bool dryRun;

  const ThemeImportResult({
    required this.tokensPath,
    required this.projectRoot,
    required this.outputPath,
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.contrastLines,
    required this.violations,
    this.dryRun = false,
  });

  List<String> get reportLines => <String>[
    'Theme tokens: ${colors.length} colors, '
        '${typography.length} typography, ${spacing.length} spacing',
    for (final line in contrastLines) 'Contrast: $line',
    if (violations.isNotEmpty)
      for (final v in violations) 'Violation: $v',
  ];

  String get summaryLine =>
      'theme import: ${colors.length} colors, ${typography.length} typography, '
      '${spacing.length} spacing — '
      '${violations.isEmpty ? 'contrast OK' : '${violations.length} contrast violation(s)'} '
      '(${dryRun ? 'dry-run' : 'written: $outputPath'})';

  String get jsonSummary =>
      '{"colors":${colors.length},'
      '"typography":${typography.length},'
      '"spacing":${spacing.length},'
      '"violations":${violations.length},'
      '"output":"$outputPath"}';
}

class ThemeImporter {
  const ThemeImporter();

  Future<ThemeImportResult> import(
    String tokensPath, {
    required String projectRoot,
    String? outputPath,
    bool dryRun = false,
    bool force = false,
  }) async {
    final file = File(tokensPath);
    if (!file.existsSync()) {
      throw ArgumentError('Tokens file not found: $tokensPath');
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw ArgumentError('Tokens file must contain a JSON object');
    }

    final colors = <String, String>{};
    final typography = <String, dynamic>{};
    final spacing = <String, dynamic>{};

    _walk(decoded, '', colors, typography, spacing);

    final pairs = _contrastPairs(colors);
    final contrastLines = <String>[];
    final violations = <String>[];
    for (final pair in pairs) {
      final fg = pair.$1;
      final bg = pair.$2;
      final fgHex = colors[fg]!;
      final bgHex = colors[bg]!;
      final ratio = _contrastRatio(fgHex, bgHex);
      final status = ratio >= 4.5 ? 'PASS' : 'FAIL';
      contrastLines.add('$fg on $bg: ${ratio.toStringAsFixed(2)}:1 $status');
      if (ratio < 4.5) {
        violations.add(
          '$fg on $bg (${ratio.toStringAsFixed(2)}:1 < 4.5 WCAG AA)',
        );
      }
    }

    final resolvedOutput = outputPath != null && outputPath.isNotEmpty
        ? p.absolute(outputPath)
        : p.join(projectRoot, 'lib', 'theme', 'theme_tokens.dart');

    if (!dryRun) {
      final outFile = File(resolvedOutput);
      await outFile.parent.create(recursive: true);
      if (force || !outFile.existsSync()) {
        await outFile.writeAsString(_render(colors, typography, spacing));
      } else {
        // Overwrite by default for import semantics.
        await outFile.writeAsString(_render(colors, typography, spacing));
      }
    }

    return ThemeImportResult(
      tokensPath: p.absolute(tokensPath),
      projectRoot: projectRoot,
      outputPath: resolvedOutput,
      colors: colors,
      typography: typography,
      spacing: spacing,
      contrastLines: contrastLines,
      violations: violations,
      dryRun: dryRun,
    );
  }

  void _walk(
    dynamic node,
    String path,
    Map<String, String> colors,
    Map<String, dynamic> typography,
    Map<String, dynamic> spacing,
  ) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey('\$value')) {
        final type = (node['\$type'] ?? '').toString().toLowerCase();
        final val = node['\$value'];
        final name = _ident(path.isEmpty ? 'token' : path);
        if (type == 'color' || (val is String && _isColor(val.toString()))) {
          colors[name] = _normalizeHex(val.toString());
          return;
        }
        if (type == 'typography' ||
            (val is Map && val.containsKey('fontSize'))) {
          typography[name] = val;
          return;
        }
        if (type.contains('dimension') ||
            type == 'number' ||
            type == 'spacing' ||
            val is num ||
            (val is String && RegExp(r'^-?\d').hasMatch(val.trim()))) {
          spacing[name] = val;
          return;
        }
        // Unknown leaf: skip.
        return;
      }
      node.forEach((k, v) {
        final key = k.toString();
        if (key.startsWith('\$')) return;
        _walk(
          v,
          path.isEmpty ? key : '$path.$key',
          colors,
          typography,
          spacing,
        );
      });
      return;
    }
    if (node is List) {
      for (var i = 0; i < node.length; i++) {
        _walk(node[i], '$path[$i]', colors, typography, spacing);
      }
    }
  }

  List<(String, String)> _contrastPairs(Map<String, String> colors) {
    final pairs = <(String, String)>[];
    final lowerIndex = <String, String>{
      for (final k in colors.keys) _norm(k): k,
    };
    for (final name in colors.keys) {
      String? baseName;
      // camelCase 'On' prefix, e.g. colorOnPrimary -> colorPrimary
      final onMatch = RegExp(r'^(.*?[a-z])On([A-Z].*)$').firstMatch(name);
      if (onMatch != null) {
        baseName = '${onMatch.group(1)}${onMatch.group(2)}';
      } else if (RegExp(r'^[Oo]n[A-Z]').hasMatch(name)) {
        baseName = name.substring(2);
      } else {
        final low = _norm(name);
        if (low == 'foreground' || low == 'text' || low == 'label') {
          for (final k in colors.keys) {
            if (_norm(k).endsWith('background')) {
              baseName = k;
              break;
            }
          }
        }
      }
      if (baseName != null &&
          colors.containsKey(baseName) &&
          baseName != name) {
        pairs.add((name, baseName));
      }
    }
    // De-duplicate.
    final seen = <String>{};
    final unique = <(String, String)>[];
    for (final p in pairs) {
      final key = '${p.$1}|${p.$2}';
      if (seen.add(key)) unique.add(p);
    }
    return unique;
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _ident(String path) {
    final parts = path.split(RegExp(r'[.\[\]/\-_ ]+'));
    final buf = StringBuffer();
    for (final raw in parts) {
      if (raw.isEmpty) continue;
      final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      if (cleaned.isEmpty) continue;
      if (buf.isEmpty) {
        buf.write(cleaned[0].toLowerCase() + cleaned.substring(1));
      } else {
        buf.write(cleaned[0].toUpperCase() + cleaned.substring(1));
      }
    }
    var result = buf.toString();
    if (result.isEmpty) result = 'token';
    if (RegExp(r'^\d').hasMatch(result)) result = 't$result';
    return result;
  }

  bool _isColor(String v) {
    final t = v.trim();
    return RegExp(
      r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    ).hasMatch(t);
  }

  String _normalizeHex(String v) {
    var t = v.trim();
    if (t.startsWith('#')) t = t.substring(1);
    if (t.length == 3) {
      t = t.split('').map((c) => '$c$c').join();
    }
    if (t.length == 6) return '#${t.toUpperCase()}';
    if (t.length == 8) return '#${t.substring(0, 6).toUpperCase()}';
    return '#${t.toUpperCase()}';
  }

  double _contrastRatio(String hex1, String hex2) {
    final l1 = _relativeLuminance(hex1);
    final l2 = _relativeLuminance(hex2);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  double _relativeLuminance(String hex) {
    var t = hex.trim();
    if (t.startsWith('#')) t = t.substring(1);
    if (t.length == 8) t = t.substring(0, 6);
    final r = int.parse(t.substring(0, 2), radix: 16) / 255.0;
    final g = int.parse(t.substring(2, 4), radix: 16) / 255.0;
    final b = int.parse(t.substring(4, 6), radix: 16) / 255.0;

    double chan(double c) =>
        c <= 0.03928 ? c / 12.92 : _pow((c + 0.055) / 1.055, 2.4);
    return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b);
  }

  String _render(
    Map<String, String> colors,
    Map<String, dynamic> typography,
    Map<String, dynamic> spacing,
  ) {
    final buf = StringBuffer();
    buf.writeln('// GENERATED by zfa theme import — do not edit by hand.');
    buf.writeln();
    buf.writeln('class ThemeTokens {');
    for (final entry in colors.entries) {
      buf.writeln(
        '  static const int ${entry.key} = 0x${entry.value.replaceAll('#', '')};',
      );
    }
    buf.writeln();
    buf.writeln('  static const Map<String, int> colors = <String, int>{');
    for (final entry in colors.entries) {
      buf.writeln("    '${entry.key}': 0x${entry.value.replaceAll('#', '')},");
    }
    buf.writeln('  };');
    buf.writeln();
    buf.writeln(
      '  static const Map<String, dynamic> typography = <String, dynamic>{',
    );
    for (final entry in typography.entries) {
      buf.writeln("    '${entry.key}': ${jsonEncode(entry.value)},");
    }
    buf.writeln('  };');
    buf.writeln();
    buf.writeln(
      '  static const Map<String, dynamic> spacing = <String, dynamic>{',
    );
    for (final entry in spacing.entries) {
      buf.writeln("    '${entry.key}': ${jsonEncode(entry.value)},");
    }
    buf.writeln('  };');
    buf.writeln('}');
    return buf.toString();
  }

  double _pow(double base, double exp) => math.pow(base, exp).toDouble();
}
