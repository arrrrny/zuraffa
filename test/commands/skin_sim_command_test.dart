// Issue #1112 — `zfa skin sim`: the deterministic simulate-side lane.
// Skin behaviors are driven through the SAME anchor protocol the
// live driver uses (the registry behind debugTapAnchor) — no
// synthetic clicks, identical JSON, CI-runnable on every host OS.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/skin_command.dart';
import 'package:zuraffa/src/commands/skin_sim_command.dart';

void main() {
  late Directory temp;
  late String manifestPath;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('zfa_skin_sim_test');
    manifestPath = '${temp.path}/skin-sim.json';
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  void writeManifest(String body) {
    File(manifestPath).writeAsStringSync(body);
  }

  SkinSimCommand sim() =>
      SkinCommand(projectRoot: '.').subcommands['sim']! as SkinSimCommand;

  group('issue #1112 — zfa skin sim (deterministic anchor replay)', () {
    test('T7.1 is a skin subcommand named sim with --manifest', () {
      final skin = SkinCommand(projectRoot: '.');
      expect(skin.subcommands.keys, contains('sim'));
      final command = skin.subcommands['sim']!;
      expect(command.argParser.options, contains('manifest'));
    });

    test('T7.2 one TapResult JSON line per tap (same protocol)', () async {
      writeManifest(const JsonEncoder().convert({
        'scenario': 'signin-guest-flow',
        'anchors': [
          {'id': 'signin-guest', 'enabled': true},
        ],
        'taps': ['zfa:signin-guest'],
      }));
      final out = <String>[];
      final code = await sim().simulate(
        manifestPath: manifestPath,
        sink: out.add,
      );
      expect(code, 0);
      expect(
        out.where((line) => line.startsWith('{')).toList(),
        ['{"result":"found","tapped":true}'],
      );
      expect(out.last, contains('skin sim:'));
    });

    test('T7.3 declared expectations met → summary + exit 0', () async {
      writeManifest(const JsonEncoder().convert({
        'scenario': 'mixed',
        'anchors': [
          {'id': 'signin-guest', 'enabled': true},
          {'id': 'signin-log-out', 'enabled': false},
        ],
        'taps': [
          {'tap': 'zfa:signin-guest', 'expect': 'found'},
          {'tap': 'zfa:signin-log-out', 'expect': 'disabled'},
        ],
      }));
      final out = <String>[];
      final code = await sim().simulate(
        manifestPath: manifestPath,
        sink: out.add,
      );
      expect(code, 0);
      expect(
        out.where((line) => line.startsWith('{')).toList(),
        [
          '{"result":"found","tapped":true}',
          '{"result":"disabled","tapped":false}',
        ],
      );
      expect(out.last, contains('scenario=mixed'));
      expect(out.last, contains('found=1'));
      expect(out.last, contains('disabled=1'));
    });

    test('T7.4 expectation drift → drift lines + exit 1', () async {
      writeManifest(const JsonEncoder().convert({
        'scenario': 'drifty',
        'anchors': [
          {'id': 'signin-guest', 'enabled': true},
        ],
        'taps': [
          {'tap': 'zfa:signin-guest', 'expect': 'disabled'},
        ],
      }));
      final out = <String>[];
      final code = await sim().simulate(
        manifestPath: manifestPath,
        sink: out.add,
      );
      expect(code, 1);
      expect(
        out.any((line) => line.contains('drift')),
        isTrue,
        reason: out.join('\n'),
      );
    });

    test('T7.5 a malformed manifest refuses honestly (exit 2)', () async {
      writeManifest('{"scenario": "broken", ');
      final out = <String>[];
      final code = await sim().simulate(
        manifestPath: manifestPath,
        sink: out.add,
      );
      expect(code, 2);
      expect(
        out.last,
        '{"result":"error","tapped":false,"message":"invalid JSON"}',
      );
    });
  });
}
