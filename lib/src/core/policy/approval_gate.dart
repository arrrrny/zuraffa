import 'dart:io';

import 'sign_off_ledger.dart';

class ApprovalGate {
  ApprovalGate({
    required this.projectRoot,
    required this.gateId,
    required this.missionId,
    required this.requestPayload,
    this.identity,
    this.ledger,
  });

  final String projectRoot;
  final String gateId;
  final String missionId;
  final Map<String, dynamic> requestPayload;
  final String? identity;
  final SignOffLedger? ledger;

  SignOffLedger get _ledger =>
      ledger ?? SignOffLedger(projectRoot: projectRoot);

  String get _identity =>
      identity ??
      (Platform.environment['USER'] ??
          Platform.environment['USERNAME'] ??
          'unknown');

  Future<bool> check({bool assumeYes = false}) async {
    final autoApprove = Platform.environment['ZFA_POLICY_AUTO_APPROVE'] == '1';

    if (assumeYes || autoApprove) {
      await _ledger.append(
        missionId: missionId,
        gate: gateId,
        requestPayload: requestPayload,
        decision: 'approved',
        identity: _identity,
      );
      return true;
    }

    if (!stdin.hasTerminal) {
      // Non-interactive (agent/CI) runs must not silently pass the human
      // checkpoint. Only an explicit --yes or ZFA_POLICY_AUTO_APPROVE=1
      // approves; otherwise the gate records `pending` and blocks.
      await _ledger.append(
        missionId: missionId,
        gate: gateId,
        requestPayload: requestPayload,
        decision: 'pending',
        identity: _identity,
      );
      stderr.writeln(
        'Gate "$gateId" requires approval. Run interactively, pass '
        '--yes, or set ZFA_POLICY_AUTO_APPROVE=1. Pending entry recorded.',
      );
      return false;
    }

    stdout.write('Gate "$gateId" requires approval. Approve? [y/N] ');
    final line = stdin.readLineSync()?.trim().toLowerCase() ?? '';
    final approved = line == 'y' || line == 'yes';
    await _ledger.append(
      missionId: missionId,
      gate: gateId,
      requestPayload: requestPayload,
      decision: approved ? 'approved' : 'denied',
      identity: _identity,
    );
    if (!approved) {
      stderr.writeln('Gate "$gateId" denied.');
    }
    return approved;
  }
}
