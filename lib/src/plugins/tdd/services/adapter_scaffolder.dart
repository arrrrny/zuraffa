/// `AdapterScaffolder` — scaffolds the REAL adapter behind the SAME
/// generated interface (spec 1193, issue #1193 step 2: the hand-delta
/// seam — receipted, never pretended generated).
///
/// Spec 913's refusal ("realize never generates real implementations")
/// stands: the scaffolder does NOT implement the adapter. It emits the
/// honest starting point a developer fills in by hand:
///
///   - the stub class implements the SAME interface the certified mock
///     implements (parsed from the mock's own declaration),
///   - every interface method is stubbed with `throw UnimplementedError()`
///     — the swap cannot fake real behavior,
///   - the file is stamped `hand-delta seam` and carries NO `// GENERATED`
///     mark — its provenance is a hand-delta receipt in the feature's
///     provenance ledger (recorded by the command), never a generation
///     receipt.
///
/// The scaffolder fails closed: an interface it cannot fully stub
/// (getters, fields, constructors — anything beyond method signatures)
/// is a refusal naming the file the developer writes by hand.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Raised when the scaffold cannot proceed honestly: no interface on the
/// mock's declaration, the interface class not found under lib/, or
/// members the scaffolder refuses to guess (getters/fields/ctors).
class ScaffoldException implements Exception {
  const ScaffoldException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The result of a successful scaffold.
class ScaffoldResult {
  const ScaffoldResult({
    required this.file,
    required this.adapterClass,
    required this.interfaceName,
    required this.interfaceFile,
    required this.methods,
    required this.created,
  });

  /// Absolute path of the scaffolded adapter file.
  final String file;

  /// The adapter class name that was scaffolded.
  final String adapterClass;

  /// The interface the adapter now implements (the SAME interface the
  /// mock implements).
  final String interfaceName;

  /// Absolute path of the interface's file.
  final String interfaceFile;

  /// The stubbed method names, in interface declaration order.
  final List<String> methods;

  /// False when the file already existed (re-scaffold is a no-op — the
  /// developer's filled-in work is never clobbered).
  final bool created;
}

class AdapterScaffolder {
  AdapterScaffolder({required this.projectRoot});

  /// The target project root.
  final String projectRoot;

  String get _libRoot => p.join(projectRoot, 'lib');

  /// Scaffold [adapterClass] behind the same interface [mockFile]
  /// implements. [mockFile] is the certified mock's implementation file
  /// (the scaffolder reads the interface from ITS declaration, so the
  /// seam is provably the same interface the mock-era suite exercised).
  ///
  /// With [write] = false the scaffold is only VALIDATED (the --dry-run
  /// preview): the plan is computed, nothing lands on disk, and the
  /// result's `created` is false.
  Future<ScaffoldResult> scaffold({
    required String adapterClass,
    required String mockFile,
    bool write = true,
  }) async {
    final mockSource = await File(mockFile).readAsString();
    final mockClass = _className(mockSource);
    if (mockClass == null) {
      throw ScaffoldException(
        'cannot scaffold $adapterClass: the mock file '
        '${_rel(mockFile)} declares no class — nothing to read the '
        'interface from.',
      );
    }
    final interfaceName = _implementedInterface(mockSource, mockClass);
    if (interfaceName == null) {
      throw ScaffoldException(
        'cannot scaffold $adapterClass: the mock class $mockClass declares '
        'no implements/extends interface — the same-interface claim has no '
        'anchor. Write the adapter by hand.',
      );
    }
    final interfaceFile = await _locateClassFile(interfaceName);
    if (interfaceFile == null) {
      throw ScaffoldException(
        'cannot scaffold $adapterClass: no file under lib/ declares the '
        'interface $interfaceName the mock implements. Write the adapter '
        'by hand.',
      );
    }

    final methods = await _extractMethods(interfaceFile, interfaceName);
    if (methods == null) {
      throw ScaffoldException(
        'cannot scaffold $adapterClass: the interface $interfaceName '
        '(${_rel(interfaceFile)}) carries members the scaffolder refuses to '
        'guess (getters, fields, constructors, or defaulted methods) — '
        'write the adapter by hand so every member is honestly provided.',
      );
    }
    if (methods.isEmpty) {
      throw ScaffoldException(
        'cannot scaffold $adapterClass: the interface $interfaceName '
        '(${_rel(interfaceFile)}) declares no methods — write the adapter '
        'by hand.',
      );
    }

    // Co-located with the mock datasource (the generated per-entity
    // directory), named after the adapter class.
    final file = p.join(p.dirname(mockFile), '${_snake(adapterClass)}.dart');
    if (!write) {
      return ScaffoldResult(
        file: file,
        adapterClass: adapterClass,
        interfaceName: interfaceName,
        interfaceFile: interfaceFile,
        methods: [for (final m in methods) m.signature],
        created: false,
      );
    }
    final existed = await File(file).exists();
    if (existed) {
      // Re-scaffold is a no-op: the developer's filled-in work is never
      // clobbered. The caller receipts only genuinely created files.
      return ScaffoldResult(
        file: file,
        adapterClass: adapterClass,
        interfaceName: interfaceName,
        interfaceFile: interfaceFile,
        methods: [for (final m in methods) m.signature],
        created: false,
      );
    }

    final relImport = _relativeImport(file, interfaceFile);
    final buffer = StringBuffer()
      ..writeln(
        '// SCAFFOLDED by zfa tdd realize (spec 1193) — the '
        'hand-delta seam.',
      )
      ..writeln(
        '// Receipted in the feature provenance ledger as a '
        'hand-delta; NEVER pretended',
      )
      ..writeln(
        '// generated. Fill in the real implementation behind the '
        'SAME interface:',
      )
      ..writeln('// $interfaceName.')
      ..writeln()
      ..writeln("import '$relImport';")
      ..writeln()
      ..writeln('class $adapterClass implements $interfaceName {');
    for (final method in methods) {
      buffer
        ..writeln('  @override')
        ..writeln('  ${method.signature} {')
        ..writeln('    throw UnimplementedError();')
        ..writeln('  }')
        ..writeln();
    }
    buffer
      ..writeln('}')
      ..writeln();

    await File(file).writeAsString(buffer.toString());
    return ScaffoldResult(
      file: file,
      adapterClass: adapterClass,
      interfaceName: interfaceName,
      interfaceFile: interfaceFile,
      methods: [for (final m in methods) m.signature],
      created: true,
    );
  }

  /// The first class declared in [source].
  String? _className(String source) {
    final m = RegExp(r'class\s+([A-Za-z_][A-Za-z0-9_]*)').firstMatch(source);
    return m?.group(1);
  }

  /// The interface [mockClass] implements or extends (`implements X` /
  /// `extends X` / `implements X with Y` — the FIRST type is the
  /// contract; mixins are not interfaces to satisfy).
  String? _implementedInterface(String source, String mockClass) {
    final decl = RegExp(
      'class\\s+$mockClass\\b[^{]*\\b(?:implements|extends)\\s+'
      '([A-Za-z_][A-Za-z0-9_]*)',
    );
    return decl.firstMatch(source)?.group(1);
  }

  /// The file under lib/ declaring [className], or null.
  Future<String?> _locateClassFile(String className) async {
    final decl = RegExp('class\\s+$className\\b');
    for (final file in await _dartFiles()) {
      if (decl.hasMatch(await File(file).readAsString())) return file;
    }
    return null;
  }

  /// The abstract method signatures of [className] in [file], verbatim
  /// (return type + name + parameter list). Null when the class carries
  /// members the scaffolder refuses to guess: getters, fields,
  /// constructors, factory or defaulted members — anything the generated
  /// stub would silently omit.
  Future<List<_InterfaceMethod>?> _extractMethods(
    String file,
    String className,
  ) async {
    final source = await File(file).readAsString();
    final body = _classBody(source, className);
    if (body == null) return null;

    final methods = <_InterfaceMethod>[];
    final methodRe = RegExp(
      r'^\s*(?:@override\s+)?([A-Za-z_][A-Za-z0-9_]*(?:\s*<[^=;]*?>)?\??)'
      r'\s+([a-z_][A-Za-z0-9_]*)\s*\(([^;]*?)\)\s*;',
      multiLine: true,
      dotAll: true,
    );
    final keywordTypes = const {
      'const',
      'final',
      'static',
      'var',
      'late',
      'factory',
      'get',
      'set',
      'void',
      'abstract',
    };
    for (final match in methodRe.allMatches(body)) {
      final type = match.group(1)!.trim();
      final name = match.group(2)!;
      // Constructor patterns (`const Foo();`) and member keywords are
      // not methods — but they ARE members the stub must not silently
      // omit, so any non-method declaration line is a refusal trigger.
      if (keywordTypes.contains(type) || name == className) return null;
      final params = match.group(3)!.trim();
      methods.add(
        _InterfaceMethod(name: name, signature: '$type $name($params)'),
      );
    }

    // Every `;`-terminated line OUTSIDE the captured method spans must
    // be a comment — anything else is a member the stub would silently
    // omit (getters, fields, operators, constructors): fail closed.
    final remainder = StringBuffer();
    var cursor = 0;
    for (final match in methodRe.allMatches(body)) {
      remainder.write(body.substring(cursor, match.start));
      cursor = match.end;
    }
    remainder.write(body.substring(cursor));
    for (final line in remainder.toString().split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('//') || t.startsWith('/*')) continue;
      if (t.endsWith(';')) return null;
    }
    return methods;
  }

  /// The brace-matched body of [className]'s declaration, or null.
  String? _classBody(String source, String className) {
    final decl = RegExp('class\\s+$className\\b[^{]*\\{');
    final start = decl.firstMatch(source);
    if (start == null) return null;
    var depth = 0;
    for (var i = start.end - 1; i < source.length; i++) {
      final c = source[i];
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) return source.substring(start.end - 1, i + 1);
      }
    }
    return null;
  }

  Future<List<String>> _dartFiles() async {
    final lib = Directory(_libRoot);
    if (!await lib.exists()) return const [];
    final files = <String>[];
    await for (final entity in lib.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path);
      }
    }
    files.sort();
    return files;
  }

  String _relativeImport(String fromFile, String targetFile) {
    final rel = p.relative(targetFile, from: p.dirname(fromFile));
    return p.posix
        .normalize(p.posix.joinAll(p.split(rel)))
        .replaceAll('\\', '/');
  }

  String _rel(String file) => p.relative(file, from: projectRoot);

  String _snake(String s) {
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '-' || c == ' ' || c == '_') {
        out.write('_');
      } else if (c.toUpperCase() == c && c.toLowerCase() != c && i > 0) {
        out.write('_');
        out.write(c.toLowerCase());
      } else {
        out.write(c.toLowerCase());
      }
    }
    return out.toString();
  }
}

class _InterfaceMethod {
  const _InterfaceMethod({required this.name, required this.signature});
  final String name;
  final String signature;
}
