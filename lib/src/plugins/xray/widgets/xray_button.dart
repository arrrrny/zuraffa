import 'dart:convert';

import 'package:flutter/material.dart';

import '../xray_element_key.dart';
import '../xray_plugin.dart';

/// One action button in an [XRaySection] grid.
///
/// - [XRayButton.endpoint] dispatches to the api bridge: `NoParams`-style
///   endpoints (empty `params`) call straight through; endpoints with
///   declared params open the inline [_XRayParamForm] first.
/// - [XRayButton.element] wraps a registry [XRayElement]: runs its
///   `onInvoke` when present, otherwise shows its metadata.
///
/// Both carry a deterministic [XRayElementKey]-derived [Key] so a
/// DTD/VM-Service agent can find and tap them blind.
class XRayButton extends StatefulWidget {
  final Key elementKey;
  final String label;
  final XRayEndpointInfo? endpoint;
  final XRayElement? element;

  const XRayButton.endpoint({
    required this.elementKey,
    required this.label,
    required XRayEndpointInfo this.endpoint,
    super.key,
  }) : element = null;

  XRayButton.element({
    required this.elementKey,
    required XRayElement this.element,
    super.key,
  }) : label = element.name,
       endpoint = null;

  @override
  State<XRayButton> createState() => _XRayButtonState();
}

class _XRayButtonState extends State<XRayButton> {
  bool _busy = false;

  Future<void> _guarded(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error, stack) {
      debugPrint('x-ray action failed: $error\n$stack');
      _snack('Error: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Endpoint path
  // ---------------------------------------------------------------------

  Future<void> _runEndpoint(Map<String, String> params) {
    return _guarded(() async {
      final response = await XRayPlugin().invoke(
        widget.endpoint!.method,
        params: params,
      );
      _snack(_describeResponse(response.result ?? ''));
    });
  }

  String _describeResponse(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded['status'] == 'success'
          ? 'OK: ${jsonEncode(decoded['data'])}'
          : 'Error: ${decoded['failure']?['message'] ?? decoded['failure']}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _onEndpointPressed() async {
    if (widget.endpoint!.params.isEmpty) {
      await _runEndpoint(const {});
      return;
    }
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _XRayParamForm(endpoint: widget.endpoint!),
    );
    if (values != null) await _runEndpoint(values);
  }

  // ---------------------------------------------------------------------
  // Element path
  // ---------------------------------------------------------------------

  Future<void> _onElementPressed() {
    final element = widget.element!;
    return _guarded(() async {
      if (element.onInvoke != null) {
        _snack(await element.onInvoke!());
      } else {
        _snack(
          '${element.type.name}: '
          '${element.domain != null ? '${element.domain}.' : ''}'
          '${element.name}',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: widget.elementKey,
      onPressed: _busy
          ? null
          : (widget.endpoint != null ? _onEndpointPressed : _onElementPressed),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A2D34),
        foregroundColor: const Color(0xFFE6E6E6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        alignment: Alignment.centerLeft,
      ),
      child: _busy
          ? const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.label, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Inline form for endpoints whose `params` map is non-empty.
///
/// When params is a single `{'args': '<EntityName>'}` entry whose entity
/// schema was registered via [XRayPlugin.registerEntitySchema], renders
/// typed fields (String → text, int/double → number, bool → switch,
/// DateTime → date picker) and submits a JSON blob. Otherwise falls back
/// to one raw text field per declared param.
class _XRayParamForm extends StatefulWidget {
  final XRayEndpointInfo endpoint;
  const _XRayParamForm({required this.endpoint});

  @override
  State<_XRayParamForm> createState() => _XRayParamFormState();
}

class _XRayParamFormState extends State<_XRayParamForm> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, DateTime> _dateValues = {};

  /// Shown when submit is blocked by unparseable numeric input.
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final entityFields = _entityFields();
    if (entityFields != null) {
      for (final field in entityFields) {
        switch (field.type) {
          case 'bool':
            _boolValues[field.name] = false;
          case 'DateTime':
            break; // picked on demand
          default:
            _controllers[field.name] = TextEditingController();
        }
      }
    } else {
      for (final name in widget.endpoint.params.keys) {
        _controllers[name] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<XRayEntityField>? _entityFields() {
    final params = widget.endpoint.params;
    if (params.length == 1 && params.containsKey('args')) {
      return XRayPlugin().entityFieldsFor(params['args']!);
    }
    return null;
  }

  /// Collects the form values, or returns null — leaving the dialog open
  /// with a visible error — when a numeric field holds unparseable text.
  /// A debug tool must surface bad input, not silently submit 0.
  Map<String, String>? _collectValues() {
    final entityFields = _entityFields();
    if (entityFields == null) {
      return {
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      };
    }
    final Map<String, dynamic> json = {};
    for (final field in entityFields) {
      switch (field.type) {
        case 'int':
          final raw = _controllers[field.name]?.text ?? '';
          final parsed = int.tryParse(raw);
          if (parsed == null && raw.isNotEmpty) {
            setState(() => _validationError =
                '${field.name}: "$raw" is not a valid int');
            return null;
          }
          json[field.name] = parsed ?? 0;
        case 'double':
          final raw = _controllers[field.name]?.text ?? '';
          final parsed = double.tryParse(raw);
          if (parsed == null && raw.isNotEmpty) {
            setState(() => _validationError =
                '${field.name}: "$raw" is not a valid double');
            return null;
          }
          json[field.name] = parsed ?? 0.0;
        case 'bool':
          json[field.name] = _boolValues[field.name] ?? false;
        case 'DateTime':
          // Unpicked dates deliberately default to now — surfaced in the UI.
          json[field.name] = (_dateValues[field.name] ?? DateTime.now())
              .toIso8601String();
        default:
          json[field.name] = _controllers[field.name]?.text ?? '';
      }
    }
    return {'args': jsonEncode(json)};
  }

  Future<void> _pickDate(String fieldName) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateValues[fieldName] ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateValues[fieldName] = picked);
  }

  @override
  Widget build(BuildContext context) {
    final entityFields = _entityFields();
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2025),
      title: Text(
        widget.endpoint.usecase,
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _validationError!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ),
            if (entityFields != null)
              for (final field in entityFields) _buildEntityField(field)
            else
              for (final entry in widget.endpoint.params.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    key: XRayElementKey.formField(
                      widget.endpoint.method,
                      entry.key,
                    ),
                    controller: _controllers[entry.key],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: '${entry.key} (${entry.value})',
                      labelStyle: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: XRayElementKey.formSubmit(widget.endpoint.method),
          onPressed: () {
            final values = _collectValues();
            // Invalid input keeps the dialog open with a visible error.
            if (values != null) Navigator.of(context).pop(values);
          },
          child: const Text('Call'),
        ),
      ],
    );
  }

  Widget _buildEntityField(XRayEntityField field) {
    final key = XRayElementKey.formField(widget.endpoint.method, field.name);
    final label = '${field.name} (${field.type})';
    switch (field.type) {
      case 'int':
      case 'double':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            key: key,
            controller: _controllers[field.name],
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelStyle: TextStyle(color: Colors.white54),
            ).copyWith(labelText: label),
          ),
        );
      case 'bool':
        return SwitchListTile(
          key: key,
          title: Text(field.name, style: const TextStyle(color: Colors.white)),
          value: _boolValues[field.name] ?? false,
          onChanged: (v) => setState(() => _boolValues[field.name] = v),
        );
      case 'DateTime':
        final value = _dateValues[field.name];
        return ListTile(
          key: key,
          title: Text(
            value == null
                ? '$label — tap to pick (defaults to now)'
                : value.toIso8601String(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          trailing: const Icon(Icons.calendar_today, color: Colors.white54),
          onTap: () => _pickDate(field.name),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            key: key,
            controller: _controllers[field.name],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelStyle: TextStyle(color: Colors.white54),
            ).copyWith(labelText: label),
          ),
        );
    }
  }
}
