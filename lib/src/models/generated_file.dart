class GeneratedFile {
  final String path;
  final String type;
  final String action;
  final String? content;

  /// Spec 1334 (EPIC #1132 honesty sweep): WHY an `action: 'skipped'`
  /// entry was skipped. `'missing-dependency'` = a source file the
  /// generation depends on (UseCase / native mock / repository) does not
  /// exist — the run cannot produce its artifact and the capability
  /// verdict must fail. `'overwrite-conflict'` = the target already
  /// exists and `--force` was not passed — the historical benign skip.
  /// `null` on every pre-1334 entry (and on non-skipped actions); the
  /// zero-artifact gate only fires on `'missing-dependency'`, so legacy
  /// null-reason skips keep today's semantics.
  final String? skipReason;

  GeneratedFile({
    required this.path,
    required this.type,
    required this.action,
    this.content,
    this.skipReason,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'path': path,
    'action': action,
    'content': content,
    if (skipReason != null) 'skipReason': skipReason,
  };
}
