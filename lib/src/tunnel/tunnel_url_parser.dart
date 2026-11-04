/// Parses the ephemeral quick-tunnel URL out of cloudflared's decorated log
/// lines (specs/1724-zuraffa-tunnel — issue #2045, FR-001).
///
/// Quick mode's URL arrives as free text like:
/// `|  https://funny-words-here.trycloudflare.com  |` — the parser is
/// deliberately narrow: only `https://<sub>.trycloudflare.com` matches, so
/// unrelated https URLs in the log stream are never mistaken for the tunnel
/// address.
library;

class TunnelUrlParser {
  const TunnelUrlParser();

  static final RegExp _quickUrl = RegExp(
    // `api.` is the quick-tunnel CONTROL endpoint — a failed request logs
    // `https://api.trycloudflare.com/tunnel`, which is not a tunnel address.
    r'https://(?!api\.)[A-Za-z0-9-]+\.trycloudflare\.com',
  );

  /// The first quick-tunnel URL found in [line], or `null`.
  Uri? parse(String line) {
    final match = _quickUrl.firstMatch(line);
    if (match == null) return null;
    return Uri.tryParse(match.group(0)!);
  }
}
