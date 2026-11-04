/// The pre-tunnel authentication probe (specs/1724-zuraffa-tunnel - issue
/// #2045, FR-004).
///
/// Local services are local for a reason: before a port is exposed to the
/// internet the wrapper probes it, and only an endpoint that answers with an
/// authentication challenge (401/403) may be tunneled without the explicit
/// operator override.
library;

import 'dart:async';
import 'dart:io';

enum EndpointProbeResult {
  /// The endpoint answered 401/403 — an authentication challenge.
  authenticated,

  /// The endpoint answered anything else — publishing it is the operator's
  /// explicit decision.
  unauthenticated,

  /// Nothing answered — there is nothing to tunnel (or the wrapped app has
  /// not opened its port yet).
  unreachable,

  /// The connection was ACCEPTED but no HTTP answer ever came back within
  /// the timeout — something is listening, the probe is just the wrong
  /// shape for it (e.g. an MCP endpoint that only speaks POST, or a very
  /// slow app). Not the same as `unreachable`: the fix line must not claim
  /// nothing is there.
  unresponsive,
}

class EndpointAuthProbe {
  const EndpointAuthProbe();

  /// Probes [target] with a GET and classifies the answer.
  ///
  /// [client] is owned by the caller (not closed here) when supplied;
  /// otherwise a throwaway client is created and closed.
  Future<EndpointProbeResult> probe(
    Uri target, {
    HttpClient? client,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ownClient = client == null;
    final hc = client ?? (HttpClient()..connectionTimeout = timeout);
    try {
      final HttpClientRequest request;
      try {
        request = await hc.openUrl('GET', target).timeout(timeout);
      } on TimeoutException {
        // The CONNECT never completed — nothing accepted the connection.
        return EndpointProbeResult.unreachable;
      }
      request.followRedirects = false;
      final HttpClientResponse response;
      try {
        response = await request.close().timeout(timeout);
      } on TimeoutException {
        // The connection was ACCEPTED but no HTTP answer arrived in time —
        // something is listening. Distinguishing this from `unreachable`
        // keeps the operator's fix line honest (an MCP endpoint that only
        // speaks POST is not "nothing").
        return EndpointProbeResult.unresponsive;
      }
      // The status is known as soon as the headers arrive — a long-lived
      // body (an SSE stream) must never hold the classification hostage,
      // so the drain is bounded and a drain timeout is non-fatal.
      final status = response.statusCode;
      await response.drain<void>().timeout(timeout, onTimeout: () {});
      if (status == HttpStatus.unauthorized || status == HttpStatus.forbidden) {
        return EndpointProbeResult.authenticated;
      }
      return EndpointProbeResult.unauthenticated;
    } on SocketException {
      // Connection refused: truly nothing there.
      return EndpointProbeResult.unreachable;
    } on HttpException {
      return EndpointProbeResult.unreachable;
    } finally {
      if (ownClient) {
        hc.close(force: true);
      }
    }
  }
}
