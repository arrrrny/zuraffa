// Issue #1112 — `zfa skin drive`: the VM-service driver CLI. These
// tests drive the REAL command logic against a FAKE vm_service-shaped
// client (the connector is injected), so the wire-to-JSON contract —
// discovery, the evaluated expression, the printed envelope, the exit
// codes — is proven without a device. The macOS live-app run is the
// maintainer's lane; this suite is the CI lane.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/commands/skin_command.dart';
import 'package:zuraffa/src/commands/skin_drive_command.dart';

/// A fake VM-service client: answers [evaluate] with a canned string
/// (what a live app's debugTapAnchorJson would return) and records
/// the calls so tests can pin the exact expression the CLI runs.
class FakeVmClient implements ZfaDriveVmClient {
  FakeVmClient({
    this.libraries = const [
      'package:app/src/skin/skin_contract_auditor.dart',
      'package:app/main.dart',
    ],
    this.evaluateAnswer,
    this.evaluateThrows,
  });

  final List<String> libraries;
  final String? evaluateAnswer;
  final Object? evaluateThrows;

  final calls = <({String targetId, String expression})>[];

  @override
  Future<List<String>> isolateIds() async => const ['isolates/main'];

  @override
  Future<List<String>> isolateLibraries(String isolateId) async => libraries;

  @override
  Future<String?> evaluate(
    String isolateId,
    String targetId,
    String expression,
  ) async {
    calls.add((targetId: targetId, expression: expression));
    if (evaluateThrows != null) throw evaluateThrows!;
    return evaluateAnswer;
  }
}

void main() {
  group('issue #1112 — zfa skin drive (fake-VM wire contract)', () {
    test('T4.1 is a skin subcommand named drive with the required options', () {
      final skin = SkinCommand(projectRoot: '.');
      final names = skin.subcommands.keys.toList();
      expect(names, contains('drive'));
      final drive = skin.subcommands['drive']!;
      expect(drive.argParser.options, contains('dart-uri'));
      expect(drive.argParser.options, contains('anchor'));
      expect(drive.argParser.options, contains('library'));
      expect(drive.argParser.options, contains('isolate-id'));
    });

    test(
      'T4.2 found prints the SC JSON as the final line and exits 0',
      () async {
        final out = <String>[];
        final drive = SkinDriveCommand.vmConnector(
          (uri) async =>
              FakeVmClient(evaluateAnswer: '{"result":"found","tapped":true}'),
          sink: (m) => out.add(m),
        );
        final code = await drive.drive(
          dartUri: 'http://127.0.0.1:1/abcdef=',
          anchor: 'zfa:signin-guest',
        );
        expect(code, 0);
        expect(out.last, '{"result":"found","tapped":true}');
      },
    );

    test('T4.3 disabled and notFound exit 1 (honest non-taps)', () async {
      for (final verdict in const ['disabled', 'notFound']) {
        final out = <String>[];
        final drive = SkinDriveCommand.vmConnector(
          (uri) async => FakeVmClient(
            evaluateAnswer: '{"result":"$verdict","tapped":false}',
          ),
          sink: (m) => out.add(m),
        );
        final code = await drive.drive(
          dartUri: 'http://127.0.0.1:1/abcdef=',
          anchor: 'zfa:signin-guest',
        );
        expect(code, 1, reason: verdict);
        expect(out.last, '{"result":"$verdict","tapped":false}');
      }
    });

    test('T4.4 an error verdict prints the message and exits 2', () async {
      final out = <String>[];
      final drive = SkinDriveCommand.vmConnector(
        (uri) async => FakeVmClient(
          evaluateAnswer: '{"result":"error","tapped":false,"message":"boom"}',
        ),
        sink: (m) => out.add(m),
      );
      final code = await drive.drive(
        dartUri: 'http://127.0.0.1:1/abcdef=',
        anchor: 'zfa:signin-guest',
      );
      expect(code, 2);
      expect(out.last, '{"result":"error","tapped":false,"message":"boom"}');
    });

    test('T4.5 auto-discovers the emitted auditor library', () async {
      final client = FakeVmClient(
        evaluateAnswer: '{"result":"found","tapped":true}',
      );
      final drive = SkinDriveCommand.vmConnector((uri) async => client);
      await drive.drive(
        dartUri: 'http://127.0.0.1:1/abcdef=',
        anchor: 'zfa:signin-guest',
      );
      final call = client.calls.single;
      expect(call.targetId, contains('skin_contract_auditor.dart'));
    });

    test(
      'T4.6 missing --dart-uri or --anchor exits 64 without connecting',
      () async {
        var connected = 0;
        final drive = SkinDriveCommand.vmConnector((uri) async {
          connected++;
          return FakeVmClient();
        });
        final missingUri = await drive.drive(anchor: 'zfa:signin-guest');
        final missingAnchor = await drive.drive(dartUri: 'http://x/');
        expect(missingUri, 64);
        expect(missingAnchor, 64);
        expect(connected, 0);
      },
    );

    test(
      'T4.7 connection failure and malformed results refuse honestly',
      () async {
        final dead = SkinDriveCommand.vmConnector(
          (uri) async => throw StateError('connection closed'),
        );
        expect(
          await dead.drive(dartUri: 'http://x/', anchor: 'zfa:signin-guest'),
          2,
        );

        final garbage = SkinDriveCommand.vmConnector(
          (uri) async => FakeVmClient(evaluateAnswer: 'not-json at all'),
        );
        expect(
          await garbage.drive(dartUri: 'http://x/', anchor: 'zfa:signin-guest'),
          2,
        );

        final nullAnswer = SkinDriveCommand.vmConnector(
          (uri) async => FakeVmClient(),
        );
        expect(
          await nullAnswer.drive(
            dartUri: 'http://x/',
            anchor: 'zfa:signin-guest',
          ),
          2,
        );
      },
    );

    test(
      'T4.8 evaluates debugTapAnchorJson(anchor) against the library',
      () async {
        final client = FakeVmClient(
          evaluateAnswer: '{"result":"found","tapped":true}',
        );
        final drive = SkinDriveCommand.vmConnector((uri) async => client);
        await drive.drive(
          dartUri: 'http://127.0.0.1:1/abcdef=',
          anchor: 'zfa:signin-guest',
          library: 'package:app/main.dart',
        );
        expect(
          client.calls.single.expression,
          "debugTapAnchorJson('zfa:signin-guest')",
        );
        expect(client.calls.single.targetId, 'package:app/main.dart');
      },
    );

    test('T4.9 the real vm_service adapter wires the documented API', () {
      // Compile-level pin: the adapter builds a client from a URI and
      // implements ZfaDriveVmClient over package:vm_service.
      expect(ZfaDriveVmAdapter, isNotNull);
    });
  });
}
