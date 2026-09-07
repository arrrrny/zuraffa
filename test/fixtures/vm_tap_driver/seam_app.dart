// Issue #1112 fixture — a LIVE seam app for the VmTapDriver proof.
//
// This is the pure-Dart miniature of the emitted kit's driver seam:
// a library exposing `debugTapAnchorJson(String zfaKey)` whose JSON
// contract is byte-identical to the kit's (`{"result":"found",
// "tapped":true}` ...). The driver under test connects to THIS
// process's VM service, enumerates libraries, finds this one, and
// evaluates — exactly what `zfa skin drive` does against
// `flutter run` / the widget-test runner.
//
// The tap handlers are REAL functions: invoking the guest anchor
// prints `TAPPED:<anchor>` to stdout, proving the driver ran the
// genuine callback (not a stub).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

/// The mini registry — the same semantics as ZfaAnchorRegistry.
final Map<String, void Function()> _handlers = {};

/// The disabled anchor: registered, but the enabled flag is false
/// (the kit's ZfaButton contractEnabled=false state).
const Set<String> _disabledAnchors = {'log-out'};

/// The keep-alive port (never closed while the fixture runs).
ReceivePort? keepAlive;

String debugTapAnchorJson(String zfaKey) {
  final id = _normalize(zfaKey);
  if (!_handlers.containsKey(id)) {
    return jsonEncode({'result': 'notFound', 'tapped': false});
  }
  if (_disabledAnchors.contains(id)) {
    return jsonEncode({'result': 'disabled', 'tapped': false});
  }
  _handlers[id]!();
  return jsonEncode({'result': 'found', 'tapped': true});
}

String _normalize(String keyOrId) =>
    keyOrId.startsWith('zfa:') ? keyOrId.substring(4) : keyOrId;

void _register(String id, void Function() onTap) => _handlers[id] = onTap;

Future<void> main() async {
  _register('signin-guest', () => print('TAPPED:signin-guest'));
  _register('log-out', () => print('TAPPED:log-out'));

  // The readiness marker the driver test waits for: after this line
  // the seam library is loaded and the handlers are registered.
  print('SEAM_READY');

  // Stay alive so the VM service (and the isolate's libraries) remain
  // reachable for the driver under test; the test kills the process.
  // The open receive port (plus a heartbeat timer) keeps the event
  // loop busy — an idle isolate lets the VM exit.
  keepAlive = ReceivePort();
  Timer.periodic(const Duration(seconds: 1), (_) {});
  await Completer<void>().future;
}
