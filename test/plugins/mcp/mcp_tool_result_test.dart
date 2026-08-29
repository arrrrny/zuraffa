import 'package:test/test.dart';
import 'package:zuraffa/src/core/module/mcp_tool.dart';

void main() {
  group('McpToolResult.artifactRef (ref-only pattern, #384 req #5)', () {
    test('ok result serialises artifactRef when set', () {
      final r = McpToolResult.ok('done', artifactRef: 'sha256:ab/cat.png');
      final json = r.toJson();
      expect(json['artifactRef'], 'sha256:ab/cat.png');
      expect(json['content'], [
        {'type': 'text', 'text': 'done'},
      ]);
    });

    test('ok result omits artifactRef when null', () {
      final json = McpToolResult.ok('done').toJson();
      expect(json.containsKey('artifactRef'), isFalse);
    });

    test('artifact factory carries only the ref plus summary text', () {
      final r = McpToolResult.artifact('sha256:ab/cat.png', text: 'screenshot');
      expect(r.artifactRef, 'sha256:ab/cat.png');
      expect(r.text, 'screenshot');
      expect(r.isError, isFalse);
      expect(r.toJson()['artifactRef'], 'sha256:ab/cat.png');
    });

    test('error result can carry an artifactRef', () {
      final r = McpToolResult.error('boom', artifactRef: 'sha256:ab/err.json');
      expect(r.isError, isTrue);
      expect(r.toJson()['artifactRef'], 'sha256:ab/err.json');
    });
  });
}
