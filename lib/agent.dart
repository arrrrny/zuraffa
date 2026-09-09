/// Dedicated import URI for the Zuraffa agent runtime (issue #1344).
///
/// The agent runtime is NOT exported from the default
/// `package:zuraffa/zuraffa.dart` barrel — re-exporting it collided with
/// ecosystem packages (zuraffa_agent) that declare same-named domain
/// entities (`LlmClient`, `RiskTier`, `ToolResult`, and the wider
/// agent-domain name class), producing ambiguous-import errors at load
/// time.
///
/// Consumers who want the agent runtime import it explicitly:
///
/// ```dart
/// import 'package:zuraffa/agent.dart';
/// ```
///
/// This facade re-exports the real barrel at
/// `package:zuraffa/zuraffa/agent.dart` (which documents the gated surface
/// in full) so both URIs work; they expose identical declarations. This is
/// a non-breaking narrowing of the default export surface — the same split
/// pattern as Flutter's material vs widgets libraries.
library;

export 'zuraffa/agent.dart';
