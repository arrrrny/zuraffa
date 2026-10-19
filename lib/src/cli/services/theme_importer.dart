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
  final bool written;

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
    this.written = true,
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
      '(${dryRun
          ? 'dry-run'
          : (written ? 'written: $outputPath' : 'skipped: $outputPath')})';

  String get jsonSummary =>
      '{"colors":${colors.length},'
      '"typography":${typography.length},'
      '"spacing":${spacing.length},'
      '"violations":${violations.length},'
      '"output":${jsonEncode(outputPath)}}';
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

    // Phase 1: collect leaf tokens.
    final leaves = <_Leaf>[];
    _collect(decoded, '', leaves);

    final byPath = <String, _Leaf>{for (final l in leaves) l.path: l};

    final colors = <String, String>{};
    final typography = <String, dynamic>{};
    final spacing = <String, dynamic>{};

    final colorNames = <String, String>{};
    final typoNames = <String, String>{};
    final spacingNames = <String, String>{};

    for (final leaf in leaves) {
      final name = ident(leaf.path.isEmpty ? 'token' : leaf.path);
      final type = leaf.type;
      final resolved = _resolveValue(leaf.path, leaf.value, byPath, <String>{});

      // Color handling.
      final hex = _colorToHex(resolved);
      if (type == 'color') {
        if (resolved is String && !_isColor(resolved.toString().trim())) {
          // Non-hex string colour (red, rgb(...)): skip rather than crash.
          // But if it is an alias that resolved to a hex, hex is set.
          if (hex == null) continue;
        }
        if (hex == null) {
          if (resolved is Map) {
            throw ArgumentError(
              'Unsupported color value for ${leaf.path}: $resolved',
            );
          }
          continue;
        }
        _checkCollision(colorNames, name, leaf.path);
        colorNames[name] = leaf.path;
        colors[name] = hex;
        continue;
      }
      if (hex != null && (resolved is String || resolved is Map)) {
        // Untyped colour token (hex string or structured colour).
        if (resolved is Map && _colorToHex(resolved) == null) {
          continue;
        }
        _checkCollision(colorNames, name, leaf.path);
        colorNames[name] = leaf.path;
        colors[name] = hex;
        continue;
      }

      if (type == 'typography' ||
          (resolved is Map && resolved.containsKey('fontSize'))) {
        _checkCollision(typoNames, name, leaf.path);
        typoNames[name] = leaf.path;
        typography[name] = resolved;
        continue;
      }

      // Spacing bucket.
      final nameLower = name.toLowerCase();
      final isNonSpacingName =
          nameLower.contains('weight') ||
          nameLower.contains('opacity') ||
          nameLower.contains('radius') ||
          nameLower.contains('fontsize') ||
          nameLower.contains('lineheight') ||
          nameLower.contains('duration') ||
          nameLower.contains('zindex');
      final isNumeric =
          resolved is num ||
          (resolved is String && RegExp(r'^-?\d').hasMatch(resolved.trim()));
      final explicitSpacing =
          type == 'spacing' || type.contains('dimension');
      final numberOk =
          (type == 'number' || type.isEmpty) && !isNonSpacingName;
      if (explicitSpacing || (isNumeric && numberOk && _isSpacingName(name))) {
        _checkCollision(spacingNames, name, leaf.path);
        spacingNames[name] = leaf.path;
        spacing[name] = resolved;
        continue;
      }
      // Unknown leaf: skip.
    }

    final pairs = contrastPairs(colors);
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

    var written = false;
    if (!dryRun) {
      final outFile = File(resolvedOutput);
      final existed = outFile.existsSync();
      await outFile.parent.create(recursive: true);
      if (force || !existed) {
        await outFile.writeAsString(_render(colors, typography, spacing));
        written = true;
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
      written: written || dryRun,
    );
  }

  void _collect(dynamic node, String path, List<_Leaf> out) {
    if (node is Map<String, dynamic>) {
      if (node.containsKey('\$value')) {
        final type = (node['\$type'] ?? '').toString().toLowerCase();
        out.add(_Leaf(path.isEmpty ? 'token' : path, type, node['\$value']));
        return;
      }
      node.forEach((k, v) {
        final key = k.toString();
        if (key.startsWith('\$')) return;
        _collect(v, path.isEmpty ? key : '$path.$key', out);
      });
      return;
    }
    if (node is List) {
      for (var i = 0; i < node.length; i++) {
        _collect(node[i], '$path[$i]', out);
      }
    }
  }

  dynamic _resolveValue(
    String path,
    dynamic val,
    Map<String, _Leaf> byPath,
    Set<String> seen,
  ) {
    if (val is String) {
      final m = RegExp(r'^\s*\{(.+)\}\s*$').firstMatch(val);
      if (m != null) {
        final ref = m.group(1)!.trim();
        if (seen.contains(ref)) {
          throw ArgumentError('Cyclic token reference: $ref');
        }
        final refLeaf = byPath[ref];
        if (refLeaf == null) {
          throw ArgumentError('Unresolved token reference: $ref');
        }
        final nextSeen = Set<String>.from(seen)..add(ref);
        return _resolveValue(ref, refLeaf.value, byPath, nextSeen);
      }
    }
    if (val is Map) {
      // Resolve aliases inside structured values shallowly.
      final out = Map<String, dynamic>.from(val);
      for (final k in out.keys.toList()) {
        out[k] = _resolveValue(path, out[k], byPath, seen);
      }
      return out;
    }
    return val;
  }

  bool _isSpacingName(String name) {
    final l = name.toLowerCase();
    return l.contains('spacing') ||
        l.contains('space') ||
        l.contains('gap') ||
        l.contains('padding') ||
        l.contains('margin') ||
        l.contains('inset') ||
        l.contains('size');
  }

  void _checkCollision(Map<String, String> names, String name, String path) {
    if (names.containsKey(name)) {
      throw ArgumentError(
        'Identifier collision: "$name" from "$path" and "${names[name]}"',
      );
    }
  }

  String? _colorToHex(dynamic val) {
    if (val is String) {
      final t = val.trim();
      if (_isColor(t)) return normalizeHex(t);
      return null;
    }
    if (val is Map) {
      if (val.containsKey('hex')) {
        final h = val['hex'].toString().trim();
        if (_isColor(h)) return normalizeHex(h);
      }
      final cs = (val['colorSpace'] ?? val['color_space'] ?? '')
          .toString()
          .toLowerCase();
      final comps = val['components'];
      if (comps is List && comps.length >= 3) {
        int toByte(dynamic x) {
          final d = (x is num)
              ? x.toDouble()
              : double.tryParse(x.toString()) ?? 0.0;
          final v = d <= 1.0 ? (d * 255).round() : d.round();
          return v.clamp(0, 255);
        }

        final r = toByte(comps[0]);
        final g = toByte(comps[1]);
        final b = toByte(comps[2]);
        var hex = '${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}';
        if (comps.length >= 4) {
          final a = toByte(comps[3]);
          hex = '$hex${a.toRadixString(16).padLeft(2, '0')}';
        }
        if (cs.isEmpty || cs == 'srgb' || cs == 'display-p3') {
          return '#${hex.toUpperCase()}';
        }
        return null;
      }
    }
    return null;
  }

  List<(String, String)> contrastPairs(Map<String, String> colors) {
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
        // Top-level on-color naming, e.g. onPrimary -> primary.
        final raw = name.substring(2);
        baseName = raw.isEmpty ? raw : raw[0].toLowerCase() + raw.substring(1);
      } else {
        final low = _norm(name);
        if (low == 'foreground' || low == 'text' || low == 'label') {
          for (final k in colors.keys) {
            if (_norm(k).endsWith('background')) {
              baseName = k;
              break;
            }
          }
        } else {
          // Grouped foreground/background pairs, e.g. colorForeground ->
          // colorBackground.
          final fgMatch = RegExp(
            r'^(.*?)(Foreground|Text|Label)$',
            caseSensitive: false,
          ).firstMatch(name);
          if (fgMatch != null) {
            final base = fgMatch.group(1)!;
            final candidates = <String>[
              if (base.isNotEmpty) '$base${_bgSuffix(name)}' else 'background',
              if (base.isNotEmpty) '${base}Background',
              if (base.isNotEmpty) '${base}Bg',
            ];
            for (final c in candidates) {
              final resolved = lowerIndex[_norm(c)];
              if (resolved != null) {
                baseName = resolved;
                break;
              }
            }
            // Fallback: any key sharing the base and ending in background.
            if (baseName == null) {
              for (final k in colors.keys) {
                if (_norm(k).startsWith(_norm(base)) &&
                    _norm(k).endsWith('background')) {
                  baseName = k;
                  break;
                }
              }
            }
          }
        }
      }
      // Resolve baseName to an actual color key, with a case-insensitive
      // fallback via lowerIndex for the camelCase branch.
      String? resolved;
      if (baseName != null) {
        if (colors.containsKey(baseName)) {
          resolved = baseName;
        } else {
          resolved = lowerIndex[_norm(baseName)];
        }
      }
      if (resolved != null && resolved != name) {
        pairs.add((name, resolved));
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

  String _bgSuffix(String name) {
    // Preserve the casing style of the original name's suffix.
    return 'Background';
  }

  String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static const Set<String> _dartKeywords = <String>{
    'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
    'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
    'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
    'factory', 'false', 'final', 'finally', 'for', 'Function', 'get', 'hide',
    'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
    'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
    'return', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this',
    'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with', 'yield',
  };

  String ident(String path) {
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
    // Avoid Dart reserved words and generated member names.
    if (_dartKeywords.contains(result) ||
        result == 'colors' ||
        result == 'typography' ||
        result == 'spacing') {
      result = '${result}_';
    }
    return result;
  }

  bool _isColor(String v) {
    final t = v.trim();
    return RegExp(
      r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    ).hasMatch(t);
  }

  String normalizeHex(String v) {
    var t = v.trim();
    if (t.startsWith('#')) t = t.substring(1);
    if (t.length == 3) {
      t = t.split('').map((c) => '$c$c').join();
    }
    if (t.length == 6 || t.length == 8) return '#${t.toUpperCase()}';
    return '#${t.toUpperCase()}';
  }

  double _contrastRatio(String hex1, String hex2) {
    // Composite alpha if present.
    final c1 = _parseColor(hex1);
    final c2 = _parseColor(hex2);
    // If foreground (first) has alpha, composite over background.
    double l1;
    if (c1.a < 1.0) {
      final er = c1.r * c1.a + c2.r * (1 - c1.a);
      final eg = c1.g * c1.a + c2.g * (1 - c1.a);
      final eb = c1.b * c1.a + c2.b * (1 - c1.a);
      l1 = _luminance(er, eg, eb);
    } else {
      l1 = _luminance(c1.r, c1.g, c1.b);
    }
    final l2 = _luminance(c2.r, c2.g, c2.b);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  _Rgb _parseColor(String hex) {
    var t = hex.trim();
    if (t.startsWith('#')) t = t.substring(1);
    if (t.length == 3) {
      t = t.split('').map((c) => '$c$c').join();
    }
    if (t.length == 6) t = '${t}FF';
    final r = int.parse(t.substring(0, 2), radix: 16) / 255.0;
    final g = int.parse(t.substring(2, 4), radix: 16) / 255.0;
    final b = int.parse(t.substring(4, 6), radix: 16) / 255.0;
    final a = int.parse(t.substring(6, 8), radix: 16) / 255.0;
    return _Rgb(r, g, b, a);
  }

  double _luminance(double r, double g, double b) {
    double chan(double c) =>
        c <= 0.03928 ? c / 12.92 : _pow((c + 0.055) / 1.055, 2.4);
    return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b);
  }

  double _pow(double base, double exp) => math.pow(base, exp).toDouble();

  // (removed unused helper)
  String _render(
    Map<String, String> colors,
    Map<String, dynamic> typography,
    Map<String, dynamic> spacing,
  ) {
    final buf = StringBuffer();
    buf.writeln('// GENERATED by zfa theme import — do not edit by hand.');
    buf.writeln();
    buf.writeln("import 'package:flutter/material.dart';");
    buf.writeln();
    buf.writeln('class ThemeTokens {');
    for (final entry in colors.entries) {
      buf.writeln(
        '  static const int ${entry.key} = ${_colorInt(entry.value)};',
      );
    }
    buf.writeln();
    buf.writeln('  static const Map<String, int> colors = <String, int>{');
    for (final entry in colors.entries) {
      buf.writeln("    '${entry.key}': ${_colorInt(entry.value)},");
    }
    buf.writeln('  };');
    buf.writeln();
    buf.writeln(
      '  static const Map<String, dynamic> typography = <String, dynamic>{',
    );
    for (final entry in typography.entries) {
      buf.writeln("    '${entry.key}': ${_dartLiteral(entry.value)},");
    }
    buf.writeln('  };');
    buf.writeln();
    buf.writeln(
      '  static const Map<String, dynamic> spacing = <String, dynamic>{',
    );
    for (final entry in spacing.entries) {
      buf.writeln("    '${entry.key}': ${_dartLiteral(entry.value)},");
    }
    buf.writeln('  };');
    buf.writeln();
    buf.writeln('  static ThemeData lightTheme() {');
    buf.writeln('    return ThemeData(');
    buf.writeln('      useMaterial3: true,');
    buf.writeln('      colorScheme: ColorScheme.fromSeed(');
    final seed = colors.isNotEmpty ? _colorInt(colors.values.first) : '0xFF6750A4';
    buf.writeln('        seedColor: Color($seed),');
    buf.writeln('        brightness: Brightness.light,');
    buf.writeln('      ),');
    buf.writeln('    );');
    buf.writeln('  }');
    buf.writeln('}');
    return buf.toString();
  }

  String _colorInt(String hex) {
    var t = hex.trim().replaceAll('#', '');
    if (t.length == 3) {
      t = t.split('').map((c) => '$c$c').join();
    }
    if (t.length == 6) return '0xFF$t';
    if (t.length == 8) {
      final rgb = t.substring(0, 6);
      final a = t.substring(6, 8);
      return '0x$a$rgb';
    }
    return '0xFF$t';
  }

  String _dartLiteral(dynamic v) {
    if (v == null) return 'null';
    if (v is bool) return v.toString();
    if (v is num) return v.toString();
    if (v is String) {
      final sb = StringBuffer("'");
      for (final c in v.split('')) {
        switch (c) {
          case '\\':
            sb.write('\\\\');
            break;
          case "'":
            sb.write("\\'");
            break;
          case '\$':
            sb.write('\\\$');
            break;
          case '\n':
            sb.write('\\n');
            break;
          case '\r':
            sb.write('\\r');
            break;
          case '\t':
            sb.write('\\t');
            break;
          default:
            sb.write(c);
        }
      }
      sb.write("'");
      return sb.toString();
    }
    if (v is List) {
      return '[${v.map(_dartLiteral).join(', ')}]';
    }
    if (v is Map) {
      final entries = v.entries
          .map((e) => '${_dartLiteral(e.key)}: ${_dartLiteral(e.value)}')
          .join(', ');
      return '{$entries}';
    }
    return jsonEncode(v);
  }
}

class _Leaf {
  final String path;
  final String type;
  final dynamic value;
  const _Leaf(this.path, this.type, this.value);
}

class _Rgb {
  final double r, g, b, a;
  const _Rgb(this.r, this.g, this.b, this.a);
}
