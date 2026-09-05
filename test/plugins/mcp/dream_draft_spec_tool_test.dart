/// Unit behaviors U5–U8 for spec 1010-zfa-dream-one-command-app
/// (tdd/test-list.md): the MCP v2 `dream_draft_spec` tool — the LLM
/// integration seam the dream command orchestrates.
///
/// The deterministic-drafter pass-through (U6) is proven against the REAL
/// `zfa tdd plan` command: the draft must be schema-constrained, not free
/// prose. The LLM path (U7) uses a fake `LlmClient` (the only existing
/// completion abstraction — no new client is introduced).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:zuraffa/src/agent/runtime/llm_client.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/mcp/v2_tools.dart';

import '../tdd/helpers/spec_fixture.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dream_v2_tool_');
  });

  tearDown(() async {
    exitCode = 0;
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// Extracts the JSON payload a v2 tool returns.
  Map<String, dynamic> payload(Map<String, dynamic>? result) {
    expect(result, isNotNull);
    final content = result!['content'] as List;
    final text = (content.first as Map)['text'] as String;
    return Map<String, dynamic>.from(
      (jsonDecode(text) as Map).cast<String, dynamic>(),
    );
  }

  test('U5: dream_draft_spec is listed by v2ToolDefinitions (12 tools) with '
      'a valid input schema', () {
    final tools = v2ToolDefinitions();
    expect(tools.length, 12);
    final tool = tools.firstWhere((t) => t['name'] == 'dream_draft_spec');
    final schema = tool['inputSchema'] as Map<String, dynamic>;
    expect(schema['type'], 'object');
    final props = schema['properties'] as Map<String, dynamic>;
    expect(props.containsKey('feature'), isTrue);
    expect(props.containsKey('description'), isTrue);
    expect(props.containsKey('feedback'), isTrue);
    final required = schema['required'] as List;
    expect(required, contains('description'));
    expect(tool['description'], isA<String>());
  });

  test('U5b: handleV2ToolCall dispatches dream_draft_spec (no LLM) and '
      'returns the draft fields', () async {
    final result = await handleV2ToolCall(
      toolName: 'dream_draft_spec',
      args: {
        'feature': '1010-demo',
        'description':
            'A page that lists the user\'s favorite deals, '
            'sorted by expiration',
      },
      projectRoot: tmp.path,
    );

    final data = payload(result);
    expect(data['drafter'], 'deterministic');
    final spec = data['specMarkdown'] as String;
    final plan = data['planMarkdown'] as String;
    expect(spec, contains('**Template Version**: `zuraffa-1.0`'));
    expect(spec, contains('## Key Entities'));
    expect(spec, contains('## External Dependencies & Contracts'));
    expect(spec, contains('## Layer Contracts'));
    expect(spec, contains('## AdaptiveViewSlots'));
    expect(spec, contains('## Skin Contract'));
    expect(plan, contains('# Implementation Plan'));
  });

  test(
    'U6: the deterministic draft passes the REAL zfa tdd plan (exit 0)',
    () async {
      final result = await handleV2ToolCall(
        toolName: 'dream_draft_spec',
        args: {
          'feature': '1010-demo',
          'description':
              'A page that lists the user\'s favorite deals, '
              'sorted by expiration',
        },
        projectRoot: tmp.path,
      );
      final data = payload(result);
      final featureDir = makeFeatureDir(tmp.path, '1010-demo');
      await writeSpec(featureDir, data['specMarkdown'] as String);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'plan',
        '1010-demo',
        '--project',
        tmp.path,
      ]);

      expect(exitCode, 0, reason: out);
      // plan prints its success line via stdout.writeln, which
      // runCapturing does not capture (the plan_gen_contract_test note) —
      // the artifact set + exit code are the proof.
      expect(
        File(p.join(featureDir, 'tdd', 'test-list.md')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(featureDir, 'tdd', 'traceability.md')).existsSync(),
        isTrue,
      );
    },
  );

  test('U7: an injected LlmClient returning labeled fenced blocks is used '
      'verbatim (drafter=llm)', () async {
    const specBody = '''
**Template Version**: `zuraffa-1.0`

# Spec: 1010-demo

## Acceptance Scenarios

1. **Given** a fresh state **When** the user invokes the feature
   **Then** the system responds

## Key Entities

| Entity | Fields | Purpose |
|--------|--------|---------|
| LlmAuthoredDeal | `id: String` | authored by the fake LLM |
''';
    final prompts = <String>[];
    final fake = _RecordingLlmClient((prompt) {
      prompts.add(prompt);
      return '```dream-spec\n$specBody\n```\n'
          '```dream-plan\n# Implementation Plan: 1010-demo\nLLM plan.\n```';
    });

    final result = await handleV2ToolCall(
      toolName: 'dream_draft_spec',
      args: {'feature': '1010-demo', 'description': 'llm-authored feature'},
      projectRoot: tmp.path,
      llmClient: fake,
    );

    final data = payload(result);
    expect(data['drafter'], 'llm');
    // Verbatim: the LLM's block content (fence-adjacent newlines
    // excluded).
    expect(data['specMarkdown'] as String, specBody.trim());
    expect(data['planMarkdown'] as String, contains('LLM plan.'));
    // The prompt carried the schema constraint (deliverable 1a).
    expect(prompts, isNotEmpty);
    for (final needle in [
      'Key Entities',
      'External Dependencies & Contracts',
      'Layer Contracts',
      'AdaptiveViewSlots',
      'Skin Contract',
      'llm-authored feature',
    ]) {
      expect(prompts.first, contains(needle), reason: prompts.first);
    }
  });

  test('U7b: an empty LLM completion falls back to the deterministic '
      'drafter, labeled (never a silent pass)', () async {
    final fake = _RecordingLlmClient((_) => '');

    final result = await handleV2ToolCall(
      toolName: 'dream_draft_spec',
      args: {'feature': '1010-demo', 'description': 'fallback feature'},
      projectRoot: tmp.path,
      llmClient: fake,
    );

    final data = payload(result);
    expect(data['drafter'], 'deterministic');
    expect(data['specMarkdown'] as String, isNotEmpty);
  });

  test('U8: feedback repair — the ingest rename suggestion is applied '
      'deterministically', () async {
    final first = await handleV2ToolCall(
      toolName: 'dream_draft_spec',
      args: {'feature': '1010-demo', 'description': 'manage credentials'},
      projectRoot: tmp.path,
    );
    final firstSpec = payload(first)['specMarkdown'] as String;
    final firstEntity = _firstEntityName(firstSpec);

    final repaired = await handleV2ToolCall(
      toolName: 'dream_draft_spec',
      args: {
        'feature': '1010-demo',
        'description': 'manage credentials',
        'feedback':
            'zfa tdd ingest: entity name collision — $firstEntity collides '
            'with the zuraffa framework export. --> fix: rename the entity, '
            "e.g. '${firstEntity}Entity'",
      },
      projectRoot: tmp.path,
    );

    final repairedSpec = payload(repaired)['specMarkdown'] as String;
    expect(_firstEntityName(repairedSpec), '${firstEntity}Entity');
  });
}

/// First Key Entities DATA row's entity name (the header row
/// `| Entity | Fields | Purpose |` and the separator are skipped).
String _firstEntityName(String specMd) {
  final section = specMd.substring(specMd.indexOf('## Key Entities'));
  for (final line in section.split('\n')) {
    final m = RegExp(
      r'^\|\s*([A-Za-z][A-Za-z0-9_]*)\s*\|',
    ).firstMatch(line.trim());
    if (m == null) continue;
    final name = m.group(1)!;
    if (name == 'Entity') continue; // header row
    if (RegExp(r'^-+$').hasMatch(name)) continue; // separator
    return name;
  }
  fail('no Key Entities data row found in:\n$specMd');
}

class _RecordingLlmClient implements LlmClient {
  _RecordingLlmClient(this.responder);

  final String Function(String prompt) responder;

  @override
  Future<String> complete(String prompt) async => responder(prompt);
}
