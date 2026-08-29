/// Agent UI Render — barrel re-export of the public ui.render surface.
///
/// Adds an agent-facing `ui.render` tool plus a streaming UI event channel and
/// the action-loop closure. An agent calls `ui.render` with a component tree;
/// the tool validates it against the active UI Vocabulary Schema, records the
/// rendered tree in the mission trace, and emits streaming events for the host
/// UI to render. User interactions route back to the agent as semantic actions
/// (gated by a policy shell for confirm-tier actions). Per-mission-type
/// vocabulary narrowing restricts the agent's allowed components.
///
/// Pure-Dart — no `package:flutter` imports. See `specs/023-agent-plugin-ui-render/`
/// for the full spec.
library;

export 'ui_vocabulary_schema.dart';
export 'semantic_action.dart';
export 'rendered_view.dart';
export 'ui_render_event.dart';
export 'ui_event_channel.dart';
export 'policy_gate.dart';
export 'mission_trace_recorder.dart';
export 'vocabulary_narrowing.dart';
export 'ui_render_tool.dart';
