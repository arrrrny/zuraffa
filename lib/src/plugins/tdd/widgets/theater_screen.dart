/// `TheaterScreen` — the read-only three-pane replay TUI behind
/// `zfa tdd theater <feature>` (spec 1006, issue #1006).
///
/// A standalone minimal TUI built directly on nocterm — the same
/// pure-Dart terminal engine the tui plugin's runtime wraps (the issue's
/// "standalone minimal TUI otherwise" branch: the runtime named at
/// `lib/src/tui/` does not exist, and wiring the tdd plugin into the tui
/// *generator* plugin would be the repo's first cross-plugin import).
///
/// Layout (issue contract):
///
///  - **Left** — spec annotation cards, one per registered behavior,
///    scrollable, click (or Enter) to expand: the card grows inline to
///    show the description, the paired test and the subject; activating
///    a card also drives the right pane to the behavior's receipt.
///  - **Right** — the cycle-log timeline in file order; clicking a cycle
///    shows its evidence diff (command, exit, criterion, test, the
///    captured output, generation steps, chain hashes); the receipt view
///    (from a behavior activation) shows the derived `action:`, the
///    `evidence:` line and the `file:` line with its #807 backing.
///  - **Bottom** — the live status line: behavior/green/red counts, the
///    cycle and receipt counts, and the key map. `[?]` opens the
///    classifier verdict for the selected behavior.
///
/// Read-only by construction: the screen holds only transient selection
/// state and renders exclusively from the [TheaterSnapshot] loaded from
/// `.zfa/receipts/` and `specs/<feature>/tdd/`. It performs no I/O.
library;

import 'package:nocterm/nocterm.dart' as nocterm;

import '../services/theater_data.dart';

/// The right pane's mode: the timeline, a behavior's receipt, or a
/// cycle's evidence diff.
enum TheaterDetailMode { timeline, receipt, cycle }

class TheaterScreen extends nocterm.StatefulComponent {
  const TheaterScreen({required this.snapshot, super.key});

  final TheaterSnapshot snapshot;

  @override
  nocterm.State<TheaterScreen> createState() => _TheaterScreenState();
}

class _TheaterScreenState extends nocterm.State<TheaterScreen> {
  /// The selected behavior card (left pane).
  int _behaviorIndex = 0;

  /// The selected timeline row (right pane, timeline mode).
  int _cycleIndex = 0;

  /// Which pane owns the arrow keys.
  bool _focusLeft = true;

  /// The expanded behavior cards (left pane).
  final Set<String> _expanded = {};

  /// The right pane's mode.
  TheaterDetailMode _mode = TheaterDetailMode.timeline;

  /// The behavior whose receipt the right pane shows (receipt mode).
  TheaterBehavior? _receiptBehavior;

  /// The cycle whose diff the right pane shows (cycle mode).
  TheaterCycle? _cycleDetail;

  /// Whether the classifier-verdict overlay is open.
  bool _verdictOpen = false;

  static const double _leftWidth = 40;

  TheaterSnapshot get _snapshot => component.snapshot;

  @override
  nocterm.Component build(nocterm.BuildContext context) {
    final content = nocterm.Column(
      children: [
        _buildHeader(),
        nocterm.Expanded(
          child: nocterm.Row(
            crossAxisAlignment: nocterm.CrossAxisAlignment.stretch,
            children: [_buildLeftPane(), _buildRightPane()],
          ),
        ),
        _buildStatusBar(),
      ],
    );
    final overlay = _buildVerdictOverlay();
    if (overlay == null) {
      return nocterm.Focusable(
        focused: true,
        onKeyEvent: _onKey,
        child: content,
      );
    }
    return nocterm.Focusable(
      focused: true,
      onKeyEvent: _onKey,
      child: nocterm.Stack(
        children: [
          nocterm.Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: content,
          ),
          nocterm.Positioned(top: 8, left: 30, width: 52, child: overlay),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // Header + status bar (top and bottom panes).
  // -----------------------------------------------------------------

  nocterm.Component _buildHeader() => nocterm.DecoratedBox(
    decoration: const nocterm.BoxDecoration(color: nocterm.Colors.blue),
    child: nocterm.Padding(
      padding: const nocterm.EdgeInsets.symmetric(horizontal: 1),
      child: nocterm.Text(
        'zfa tdd theater — ${_snapshot.feature} (read-only)',
        style: const nocterm.TextStyle(
          color: nocterm.Colors.white,
          fontWeight: nocterm.FontWeight.bold,
        ),
      ),
    ),
  );

  nocterm.Component _buildStatusBar() {
    final selected = _selectedBehavior;
    final focusHint = _focusLeft ? 'behaviors' : 'timeline';
    return nocterm.DecoratedBox(
      decoration: const nocterm.BoxDecoration(
        color: nocterm.Colors.brightBlack,
      ),
      child: nocterm.Padding(
        padding: const nocterm.EdgeInsets.symmetric(horizontal: 1),
        child: nocterm.Text(
          'behaviors=${_snapshot.behaviors.length} '
          'green=${_snapshot.greenCount} red=${_snapshot.redCount} '
          'cycles=${_snapshot.cycles.length} '
          'receipts=${_snapshot.receiptCount} '
          '| sel: ${selected?.id ?? '-'} ($focusHint) '
          '| Tab pane · Enter open · [?] verdict · q quit',
          style: const nocterm.TextStyle(color: nocterm.Colors.white),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Left pane: the spec annotation cards.
  // -----------------------------------------------------------------

  nocterm.Component _buildLeftPane() {
    return nocterm.SizedBox(
      width: _leftWidth,
      child: nocterm.DecoratedBox(
        decoration: nocterm.BoxDecoration(
          border: nocterm.BoxBorder.all(color: nocterm.Colors.grey),
          title: nocterm.BorderTitle(text: 'Behaviors (spec cards)'),
        ),
        child: nocterm.ListView(
          children: [
            for (var i = 0; i < _snapshot.behaviors.length; i++)
              _buildBehaviorCard(
                _snapshot.behaviors[i],
                selected: i == _behaviorIndex,
              ),
          ],
        ),
      ),
    );
  }

  nocterm.Component _buildBehaviorCard(
    TheaterBehavior behavior, {
    required bool selected,
  }) {
    final expanded = _expanded.contains(behavior.id);
    final children = <nocterm.Component>[
      nocterm.GestureDetector(
        onTap: () => _activateBehavior(behavior),
        child: nocterm.DecoratedBox(
          decoration: nocterm.BoxDecoration(
            color: selected ? nocterm.Colors.blue : null,
          ),
          child: nocterm.Padding(
            padding: const nocterm.EdgeInsets.symmetric(horizontal: 1),
            child: nocterm.Text(
              '${expanded ? 'v' : '>'} ${behavior.id} '
              '${behavior.criterion} ${_statusLabel(behavior.status)}',
              style: nocterm.TextStyle(
                color: selected
                    ? nocterm.Colors.white
                    : _statusColor(behavior.status),
                fontWeight: selected ? nocterm.FontWeight.bold : null,
              ),
            ),
          ),
        ),
      ),
    ];
    if (expanded) {
      children.addAll([
        _pad(_line('desc: ${behavior.description}', nocterm.Colors.white)),
        _pad(_line('test: ${behavior.testPath}', nocterm.Colors.grey)),
        _pad(_line('subject: ${behavior.subjectPath}', nocterm.Colors.grey)),
      ]);
    }
    return nocterm.Column(
      crossAxisAlignment: nocterm.CrossAxisAlignment.start,
      children: children,
    );
  }

  // -----------------------------------------------------------------
  // Right pane: the timeline / receipt / cycle diff.
  // -----------------------------------------------------------------

  nocterm.Component _buildRightPane() {
    return nocterm.Expanded(
      child: nocterm.DecoratedBox(
        decoration: nocterm.BoxDecoration(
          border: nocterm.BoxBorder.all(color: nocterm.Colors.grey),
          title: nocterm.BorderTitle(text: 'Cycle timeline (evidence)'),
        ),
        child: nocterm.ListView(children: _rightPaneChildren()),
      ),
    );
  }

  List<nocterm.Component> _rightPaneChildren() {
    switch (_mode) {
      case TheaterDetailMode.timeline:
        return _buildTimeline();
      case TheaterDetailMode.receipt:
        return _buildReceiptView(_receiptBehavior!);
      case TheaterDetailMode.cycle:
        return _buildCycleView(_cycleDetail!);
    }
  }

  List<nocterm.Component> _buildTimeline() {
    if (_snapshot.cycles.isEmpty) {
      return [
        _pad(
          _line(
            _snapshot.cycleLogPresent
                ? '(no machine entries in the cycle log)'
                : '(no cycle log at tdd/cycle-log.md)',
            nocterm.Colors.grey,
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < _snapshot.cycles.length; i++)
        _buildTimelineRow(_snapshot.cycles[i], selected: i == _cycleIndex),
    ];
  }

  nocterm.Component _buildTimelineRow(
    TheaterCycle cycle, {
    required bool selected,
  }) {
    return nocterm.GestureDetector(
      onTap: () => _activateCycle(cycle),
      child: nocterm.DecoratedBox(
        decoration: nocterm.BoxDecoration(
          color: selected && !_focusLeft ? nocterm.Colors.blue : null,
        ),
        child: nocterm.Padding(
          padding: const nocterm.EdgeInsets.symmetric(horizontal: 1),
          child: nocterm.Text(
            '${cycle.behaviorId} (${cycle.kind}) '
            'exit ${cycle.exitCode ?? '?'} '
            '${(cycle.at ?? '').split('T').first}',
            style: nocterm.TextStyle(
              color: selected && !_focusLeft
                  ? nocterm.Colors.white
                  : _kindColor(cycle.kind),
            ),
          ),
        ),
      ),
    );
  }

  /// The receipt view: the derived proof action, the evidence line and
  /// the file line with its #807 receipt backing (issue #1006: "click a
  /// behavior → show the receipt").
  List<nocterm.Component> _buildReceiptView(TheaterBehavior behavior) {
    final receipt = behavior.receipt;
    final lines = <nocterm.Component>[
      _pad(
        _line(
          'receipt — ${behavior.id} (${behavior.criterion})',
          nocterm.Colors.white,
          bold: true,
        ),
      ),
      _pad(_line('action: ${receipt.action}', _statusColor(behavior.status))),
      _pad(_line('evidence: ${receipt.evidence}', nocterm.Colors.white)),
      _pad(_line('file: ${receipt.file}', nocterm.Colors.white)),
    ];
    if (receipt.receiptAction != null) {
      lines.addAll([
        _pad(
          _line(
            'receipt-file: ${receipt.receiptFile} '
            '(${receipt.receiptAction}, ${receipt.bytes ?? '?'} bytes)',
            nocterm.Colors.grey,
          ),
        ),
        _pad(_line('sha256: ${receipt.sha256}', nocterm.Colors.grey)),
        _pad(
          _line(
            'recorded: ${receipt.at} by ${receipt.command}',
            nocterm.Colors.grey,
          ),
        ),
        _pad(_line('repro: ${receipt.repro}', nocterm.Colors.grey)),
      ]);
    } else {
      lines.add(
        _pad(
          _line(
            'receipt-file: (no #807 receipt covers this behavior yet)',
            nocterm.Colors.grey,
          ),
        ),
      );
    }
    return lines;
  }

  /// The cycle view: the recorded evidence diff (issue #1006: "click a
  /// cycle → show the diff").
  List<nocterm.Component> _buildCycleView(TheaterCycle cycle) {
    final lines = <nocterm.Component>[
      _pad(
        _line(
          'cycle — ${cycle.behaviorId} (${cycle.kind})',
          nocterm.Colors.white,
          bold: true,
        ),
      ),
      _pad(_line('command: ${cycle.command ?? '-'}', nocterm.Colors.white)),
      _pad(_line('exit: ${cycle.exitCode ?? '?'}', nocterm.Colors.white)),
      _pad(_line('criterion: ${cycle.criterion ?? '-'}', nocterm.Colors.white)),
      _pad(_line('test: ${cycle.test ?? '-'}', nocterm.Colors.white)),
      if (cycle.classification != null)
        _pad(
          _line(
            'classification: ${cycle.classification}',
            nocterm.Colors.yellow,
          ),
        ),
      if (cycle.redEvidence != null)
        _pad(_line('evidence: ${cycle.redEvidence}', nocterm.Colors.yellow)),
      _pad(_line('at: ${cycle.at ?? '-'}', nocterm.Colors.grey)),
    ];
    for (final step in cycle.generationSteps) {
      lines.add(
        _pad(
          _line(
            'step: ${step.command} (exit ${step.exitCode ?? '?'}) '
            '${step.purpose ?? ''}',
            nocterm.Colors.grey,
          ),
        ),
      );
    }
    if (cycle.hash != null) {
      lines.add(_pad(_line('hash: ${cycle.hash}', nocterm.Colors.grey)));
    }
    lines.add(_pad(_line('output:', nocterm.Colors.white)));
    for (final line in cycle.output.split('\n')) {
      lines.add(_pad(_line(line, nocterm.Colors.white)));
    }
    return lines;
  }

  // -----------------------------------------------------------------
  // The classifier-verdict overlay ([?]).
  // -----------------------------------------------------------------

  nocterm.Component? _buildVerdictOverlay() {
    if (!_verdictOpen) return null;
    final behavior = _selectedBehavior;
    final verdict = behavior?.verdict;
    if (behavior == null || verdict == null) {
      return _overlayPanel([
        _line(
          'classifier verdict — ${behavior?.id ?? '-'}: no classified red '
          'recorded for this behavior.',
          nocterm.Colors.white,
        ),
        _line('(any key closes)', nocterm.Colors.grey),
      ]);
    }
    return _overlayPanel([
      _line(
        'classifier verdict — ${behavior.id}',
        nocterm.Colors.white,
        bold: true,
      ),
      _line('class: ${verdict.classificationLabel}', nocterm.Colors.yellow),
      if (verdict.remediationHint.isNotEmpty)
        _line('hint: ${verdict.remediationHint}', nocterm.Colors.white),
      if (verdict.evidence != null)
        _line('evidence: ${verdict.evidence}', nocterm.Colors.yellow),
      _line('(any key closes)', nocterm.Colors.grey),
    ]);
  }

  nocterm.Component _overlayPanel(List<nocterm.Component> lines) {
    return nocterm.DecoratedBox(
      decoration: nocterm.BoxDecoration(
        color: nocterm.Colors.black,
        border: nocterm.BoxBorder.all(color: nocterm.Colors.yellow),
        title: nocterm.BorderTitle(text: '[?] classifier verdict'),
      ),
      child: nocterm.Padding(
        padding: const nocterm.EdgeInsets.all(1),
        child: nocterm.Column(
          crossAxisAlignment: nocterm.CrossAxisAlignment.start,
          mainAxisSize: nocterm.MainAxisSize.min,
          children: lines,
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Input: keyboard + mouse.
  // -----------------------------------------------------------------

  bool _onKey(nocterm.KeyboardEvent event) {
    if (_verdictOpen) {
      _verdictOpen = false;
      _rerender();
      return true;
    }
    final key = event.logicalKey;
    if (key == nocterm.LogicalKey.keyQ) {
      nocterm.shutdownApp();
      return true;
    }
    if (key == nocterm.LogicalKey.tab) {
      _focusLeft = !_focusLeft;
      _rerender();
      return true;
    }
    if (key == nocterm.LogicalKey.question) {
      _openVerdict();
      return true;
    }
    if (key == nocterm.LogicalKey.escape ||
        key == nocterm.LogicalKey.backspace) {
      if (_mode != TheaterDetailMode.timeline) {
        _mode = TheaterDetailMode.timeline;
        _rerender();
        return true;
      }
      return false;
    }
    if (key == nocterm.LogicalKey.enter) {
      _activateSelection();
      return true;
    }
    if (key == nocterm.LogicalKey.arrowUp) {
      _moveSelection(-1);
      return true;
    }
    if (key == nocterm.LogicalKey.arrowDown) {
      _moveSelection(1);
      return true;
    }
    if (key == nocterm.LogicalKey.arrowLeft && !_focusLeft) {
      _focusLeft = true;
      _rerender();
      return true;
    }
    if (key == nocterm.LogicalKey.arrowRight && _focusLeft) {
      _focusLeft = false;
      _rerender();
      return true;
    }
    return false;
  }

  void _activateSelection() {
    if (_focusLeft) {
      final behavior = _selectedBehavior;
      if (behavior != null) _activateBehavior(behavior);
    } else if (_mode == TheaterDetailMode.timeline &&
        _snapshot.cycles.isNotEmpty) {
      _activateCycle(
        _snapshot.cycles[_cycleIndex.clamp(0, _snapshot.cycles.length - 1)],
      );
    }
  }

  void _activateBehavior(TheaterBehavior behavior) {
    setState(() {
      _behaviorIndex = _snapshot.behaviors.indexOf(behavior);
      if (_expanded.contains(behavior.id)) {
        _expanded.remove(behavior.id);
      } else {
        _expanded.add(behavior.id);
      }
      // Issue contract: clicking a behavior shows its receipt.
      _mode = TheaterDetailMode.receipt;
      _receiptBehavior = behavior;
      _cycleDetail = null;
    });
  }

  void _activateCycle(TheaterCycle cycle) {
    setState(() {
      _cycleIndex = _snapshot.cycles.indexOf(cycle);
      // Issue contract: clicking a cycle shows the diff.
      _mode = TheaterDetailMode.cycle;
      _cycleDetail = cycle;
      _receiptBehavior = null;
    });
  }

  void _openVerdict() {
    setState(() {
      _verdictOpen = true;
    });
  }

  void _moveSelection(int delta) {
    setState(() {
      if (_focusLeft) {
        _behaviorIndex = (_behaviorIndex + delta).clamp(
          0,
          _snapshot.behaviors.isEmpty ? 0 : _snapshot.behaviors.length - 1,
        );
      } else if (_mode == TheaterDetailMode.timeline &&
          _snapshot.cycles.isNotEmpty) {
        _cycleIndex = (_cycleIndex + delta).clamp(
          0,
          _snapshot.cycles.length - 1,
        );
      }
    });
  }

  TheaterBehavior? get _selectedBehavior => _snapshot.behaviors.isEmpty
      ? null
      : _snapshot.behaviors[_behaviorIndex.clamp(
          0,
          _snapshot.behaviors.length - 1,
        )];

  void _rerender() {
    setState(() {});
  }

  // -----------------------------------------------------------------
  // Small rendering helpers.
  // -----------------------------------------------------------------

  nocterm.Component _pad(nocterm.Component child) => nocterm.Padding(
    padding: const nocterm.EdgeInsets.symmetric(horizontal: 1),
    child: child,
  );

  nocterm.Component _line(
    String text,
    nocterm.Color color, {
    bool bold = false,
  }) {
    return nocterm.Text(
      text,
      style: nocterm.TextStyle(
        color: color,
        fontWeight: bold ? nocterm.FontWeight.bold : null,
      ),
    );
  }

  static String _statusLabel(TheaterProofStatus status) {
    switch (status) {
      case TheaterProofStatus.green:
        return 'green';
      case TheaterProofStatus.red:
        return 'red';
      case TheaterProofStatus.pending:
        return 'pending';
    }
  }

  static nocterm.Color _statusColor(TheaterProofStatus status) {
    switch (status) {
      case TheaterProofStatus.green:
        return nocterm.Colors.green;
      case TheaterProofStatus.red:
        return nocterm.Colors.red;
      case TheaterProofStatus.pending:
        return nocterm.Colors.yellow;
    }
  }

  static nocterm.Color _kindColor(String kind) {
    switch (kind) {
      case 'green':
        return nocterm.Colors.green;
      case 'red':
        return nocterm.Colors.red;
      case 'refactor':
        return nocterm.Colors.cyan;
      default:
        return nocterm.Colors.white;
    }
  }
}
