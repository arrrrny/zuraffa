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
      final request = await hc.openUrl('GET', target).timeout(timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      if (response.statusCode == HttpStatus.unauthorized ||
          response.statusCode == HttpStatus.forbidden) {
        return EndpointProbeResult.authenticated;
      }
      return EndpointProbeResult.unauthenticated;
    } on SocketException {
      return EndpointProbeResult.unreachable;
    } on HttpException {
      return EndpointProbeResult.unreachable;
    } on TimeoutException {
      return EndpointProbeResult.unreachable;
    } finally {
      if (ownClient) {
        hc.close(force: true);
      }
    }
  }
}
