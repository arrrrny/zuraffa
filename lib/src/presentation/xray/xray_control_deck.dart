// X-Ray Control Deck -- sliding drawer with synthetic payload injection.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'xray_mock_entry.dart';
import 'xray_mode.dart';

/// Callback invoked when a mock entry is tapped.
///
/// Receives the raw [payload] from the [XRayMockEntry].
/// The consumer is responsible for converting it to the correct
/// Params type and calling the UseCase.
typedef XRayMockInjector = void Function(dynamic payload);

/// A sliding drawer that appears when X-Ray mode is active,
/// listing all registered mock scenarios as tappable buttons.
///
/// Usage in generated code:
/// ```dart
/// XRayControlDeck(
///   useCaseName: 'ScanBarcodeUseCase',
///   injector: (payload) => scanBarcodeUseCase(payload as String),
///   entries: [
///     XRayMockEntry(name: 'Valid Product A', payload: '123456789', type: XRayMockType.valid),
///     XRayMockEntry(name: 'Invalid Barcode', payload: '000000', type: XRayMockType.error),
///   ],
/// )
/// ```
///
/// In release mode this widget is a zero-allocation pass-through.
class XRayControlDeck extends StatefulWidget {
  /// Label for the UseCase being mocked (shown in the deck header).
  final String useCaseName;

  /// Callback invoked when a mock button is tapped.
  final XRayMockInjector injector;

  /// The list of mock entries to display.
  final List<XRayMockEntry> entries;

  /// Optional height fraction of the screen for the deck (0.0-1.0).
  final double heightFactor;

  const XRayControlDeck({
    super.key,
    required this.useCaseName,
    required this.injector,
    this.entries = const [],
    this.heightFactor = 0.4,
  });

  @override
  State<XRayControlDeck> createState() => _XRayControlDeckState();
}

class _XRayControlDeckState extends State<XRayControlDeck>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;
  String? _lastInjected;
  Timer? _feedbackTimer;

  static const Color _deckAccent = Color(0xFF00FFFF);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _inject(XRayMockEntry entry) {
    widget.injector(entry.payload);
    setState(() {
      _lastInjected = entry.name;
    });
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _lastInjected = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!XRayMode.isEnabled) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Toggle button.
        Positioned(
          right: 8,
          bottom: 8,
          child: GestureDetector(
            onTap: _toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xCC1A1A2E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _deckAccent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOpen ? Icons.close : Icons.science,
                    color: _deckAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _lastInjected ?? 'MOCK DECK',
                    style: TextStyle(
                      color: _lastInjected != null
                          ? const Color(0xFF66FF66)
                          : _deckAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Sliding panel.
        if (_isOpen)
          Positioned.fill(
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildPanel(),
            ),
          ),
      ],
    );
  }

  Widget _buildPanel() {
    final entries = widget.entries;
    return Container(
      color: const Color(0xE61A1A2E),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0x33FFFFFF)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science, color: Color(0xFF00FFFF), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Control Deck',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          widget.useCaseName,
                          style: const TextStyle(
                            color: Color(0xAAFFFFFF),
                            fontSize: 11,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${entries.length} mock${entries.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Color(0x88FFFFFF),
                      fontSize: 11,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            // Entry list.
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No mock scenarios registered.\n'
                  'Add @XRayMock annotations or use registerEntries().',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(8),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) =>
                      _buildEntryButton(entries[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryButton(XRayMockEntry entry) {
    final color = _colorForType(entry.type);
    final icon = _iconForType(entry.type);

    return GestureDetector(
      onTap: () => _inject(entry),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (entry.description != null)
                    Text(
                      entry.description!,
                      style: const TextStyle(
                        color: Color(0x88FFFFFF),
                        fontSize: 11,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  Text(
                    'payload: ${_truncate(entry.payload.toString(), 40)}',
                    style: const TextStyle(
                      color: Color(0x55FFFFFF),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              icon,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForType(XRayMockType type) {
    switch (type) {
      case XRayMockType.valid:
        return const Color(0xFF66FF66);
      case XRayMockType.error:
        return const Color(0xFFFF6666);
      case XRayMockType.unknown:
        return const Color(0xFFAAAAAA);
    }
  }

  String _iconForType(XRayMockType type) {
    switch (type) {
      case XRayMockType.valid:
        return '\u2705';
      case XRayMockType.error:
        return '\u274C';
      case XRayMockType.unknown:
        return '\u26AA';
    }
  }

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}\u2026';
  }
}

/// Global registry for mock entries, allowing programmatic registration.
///
/// Used when YAML-based or annotation-based generation is not desired,
/// or for dynamic/runtime registration.
///
/// ```dart
/// XRayControlDeckRegistry.registerEntries(
///   'ScanBarcodeUseCase',
///   [
///     XRayMockEntry(name: 'Quick Test', payload: 'abc123', type: XRayMockType.valid),
///   ],
/// );
/// ```
class XRayControlDeckRegistry {
  XRayControlDeckRegistry._();

  static final Map<String, List<XRayMockEntry>> _entries = {};

  /// Register mock entries for a given UseCase name.
  static void registerEntries(
    String useCaseName,
    List<XRayMockEntry> entries,
  ) {
    if (kReleaseMode) return;
    _entries[useCaseName] = List.unmodifiable(entries);
  }

  /// Retrieve all entries for a given UseCase name.
  static List<XRayMockEntry> entriesFor(String useCaseName) {
    if (kReleaseMode) return const [];
    return List.unmodifiable(_entries[useCaseName] ?? const []);
  }

  /// Retrieve entries for all registered UseCases.
  static Map<String, List<XRayMockEntry>> get allEntries {
    if (kReleaseMode) return const {};
    return Map.unmodifiable(_entries);
  }

  /// Clear all registered entries (for testing).
  @visibleForTesting
  static void clear() {
    _entries.clear();
  }
}
