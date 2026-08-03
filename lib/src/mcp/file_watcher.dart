// MCP Server 2.0 — File system watcher for streaming notifications.

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

/// A file change event pushed to MCP clients.
class McpFileEvent {
  final String type; // 'created' | 'modified' | 'deleted'
  final String path; // relative to project root
  final DateTime timestamp;

  const McpFileEvent({
    required this.type,
    required this.path,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'path': path,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}

/// Watches the project's lib/src/ directory for .dart file changes.
class McpFileWatcher {
  final String projectRoot;
  final StreamController<McpFileEvent> _controller =
      StreamController<McpFileEvent>.broadcast();
  StreamSubscription<FileSystemEvent>? _subscription;
  bool _running = false;

  McpFileWatcher({required this.projectRoot});

  /// Stream of file change events.
  Stream<McpFileEvent> get events => _controller.stream;

  /// Whether the watcher is actively running.
  bool get isRunning => _running;

  /// Starts watching lib/src/ recursively.
  Future<void> start() async {
    if (_running) return;

    final watchDir = p.join(projectRoot, 'lib', 'src');
    final dir = Directory(watchDir);
    if (!await dir.exists()) return;

    _subscription = dir.watch(recursive: true).listen(
      _handleEvent,
      onError: (error) {
        // Log filesystem watch errors but don't crash
        // ignore: avoid_print
        print('[McpFileWatcher] Watch error: $error');
      },
    );
    _running = true;
  }

  /// Stops watching.
  Future<void> stop() async {
    _running = false;
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  void _handleEvent(FileSystemEvent event) {
    if (!event.path.endsWith('.dart')) return;

    String relativePath;
    try {
      relativePath = p.relative(event.path, from: projectRoot);
    } catch (_) {
      relativePath = event.path;
    }

    String type;
    switch (event.type) {
      case FileSystemEvent.create:
        type = 'created';
        break;
      case FileSystemEvent.modify:
        type = 'modified';
        break;
      case FileSystemEvent.delete:
        type = 'deleted';
        break;
      case FileSystemEvent.move:
        type = 'deleted';
        break;
      default:
        return;
    }

    _controller.add(McpFileEvent(
      type: type,
      path: relativePath,
      timestamp: DateTime.now().toUtc(),
    ));
  }

  /// Emits a synthetic regeneration notification (e.g. after zfa build).
  void notifyRegeneration(List<String> affectedPaths) {
    final now = DateTime.now().toUtc();
    for (final path in affectedPaths) {
      _controller.add(McpFileEvent(
        type: 'modified',
        path: path,
        timestamp: now,
      ));
    }
  }
}
