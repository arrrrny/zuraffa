/// Entity file lookup for the TDD plugin (bug #829): where a generated
/// entity lives, and whether it already exists.
///
/// The `zfa entity create` core command regenerates the entity file
/// unconditionally — re-running it over an existing entity silently
/// destroys hand-tuned fields. The loop's entity orchestration
/// (`tdd run` phase 0 and the make plan) therefore checks existence
/// FIRST and reuses the existing file: an entity is created only when
/// it is genuinely absent, never overwritten.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Mirror of wire_command's snake-case conversion (CamelCase / dashes →
/// snake_case), shared by the run driver's phase 0 and the make plan.
String toSnakeCase(String s) {
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

/// Locate the generated entity file for [entityName] under [cwd]: the
/// canonical `<entities>/<snake>/<snake>.dart` path first, then a
/// recursive search fallback (config can move the output dir). Null
/// when no such entity file exists — the caller must create it before
/// anything generates against it.
Future<String?> locateEntityFile(String cwd, String entityName) async {
  final snake = toSnakeCase(entityName);
  final entitiesRoot = Directory(
    p.join(cwd, 'lib', 'src', 'domain', 'entities'),
  );
  final canonical = File(p.join(entitiesRoot.path, snake, '$snake.dart'));
  if (await canonical.exists()) return canonical.path;
  if (!await entitiesRoot.exists()) return null;
  final target = '$snake.dart';
  await for (final f in entitiesRoot.list(recursive: true)) {
    if (f is File && p.basename(f.path) == target) return f.path;
  }
  return null;
}

/// Issue #1429: locate the phase-0 scaffold for [entityName] AND classify
/// the shape the rollback verbs may delete: the canonical per-entity
/// directory (`<entities>/<snake>/` — the scaffold source plus any
/// sibling generated part files) when the located file follows the
/// `<entities>/<snake>/<snake>.dart` layout, or just the located FILE
/// when a recursive fallback found it outside the canonical layout (a
/// foreign directory layout is never a rollback target). Nulls when no
/// scaffold exists.
Future<({String? file, String? dir})> locateEntityScaffold(
  String cwd,
  String entityName,
) async {
  final located = await locateEntityFile(cwd, entityName);
  if (located == null) return (file: null, dir: null);
  final snake = toSnakeCase(entityName);
  final normalized = p.normalize(located);
  final canonicalDir = p.join(cwd, 'lib', 'src', 'domain', 'entities', snake);
  final isCanonical =
      p.relative(normalized, from: canonicalDir) == '$snake.dart';
  return (file: normalized, dir: isCanonical ? canonicalDir : null);
}
