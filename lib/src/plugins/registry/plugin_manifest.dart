import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// A signed capability manifest describing what a plugin may do.
///
/// Capabilities:
/// - [writePaths]: glob/path prefixes the plugin is allowed to write.
/// - [commands]: CLI commands the plugin provides.
/// - [tools]: agent/MCP tools the plugin registers.
class PluginManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final List<String> writePaths;
  final List<String> commands;
  final List<String> tools;
  final String signature;

  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description = '',
    this.writePaths = const [],
    this.commands = const [],
    this.tools = const [],
    this.signature = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'capabilities': {
      'write_paths': writePaths,
      'commands': commands,
      'tools': tools,
    },
    'signature': signature,
  };

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final caps = (json['capabilities'] as Map?) ?? const {};
    return PluginManifest(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? json['id'] ?? '').toString(),
      version: (json['version'] ?? '0.0.0').toString(),
      description: (json['description'] ?? '').toString(),
      writePaths: _stringList(caps['write_paths']),
      commands: _stringList(caps['commands']),
      tools: _stringList(caps['tools']),
      signature: (json['signature'] ?? '').toString(),
    );
  }

  static List<String> _stringList(Object? v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  /// Canonical bytes used for signing (everything except signature).
  String canonical() {
    final map = {
      'id': id,
      'name': name,
      'version': version,
      'description': description,
      'capabilities': {
        'write_paths': writePaths,
        'commands': commands,
        'tools': tools,
      },
    };
    return jsonEncode(map);
  }

  /// HMAC-SHA256 signature using the provided key (v0 signing).
  static String sign(String canonical, {String key = defaultSigningKey}) {
    final hmac = Hmac(sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(canonical)).toString();
  }

  bool verify({String key = defaultSigningKey}) {
    if (signature.isEmpty) return false;
    return signature == sign(canonical(), key: key);
  }

  static const String defaultSigningKey = 'zuraffa-plugin-dev-signing-key';
}

/// Loads a manifest from a file path (manifest.json) or directory.
PluginManifest? loadManifest(String path) {
  try {
    final type = FileSystemEntity.typeSync(path);
    File manifestFile;
    if (type == FileSystemEntityType.directory) {
      manifestFile = File(p.join(path, 'manifest.json'));
    } else {
      manifestFile = File(path);
    }
    if (!manifestFile.existsSync()) return null;
    final decoded = jsonDecode(manifestFile.readAsStringSync());
    if (decoded is! Map<String, dynamic>) return null;
    return PluginManifest.fromJson(decoded);
  } catch (_) {
    return null;
  }
}
