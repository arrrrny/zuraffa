import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../xray_element_key.dart';
import '../xray_plugin.dart';

/// A single action button rendered inside an [XRaySection].
///
/// - Carries a deterministic [Key] from [XRayElementKey] so a DTD/VM
///   Service agent can find and tap it without inspecting the tree first.
/// - `NoParams`-style endpoints (`params` empty) call straight through.
/// - Endpoints with declared params open a small inline form first (see
///   [_XRayParamForm]) built from `endpoint.params` (name -> Dart type),
///   satisfying the "createProduct opens a form" behavior from the spec.
class XRayButton extends StatefulWidget {
  final Key elementKey;
  final String label;
  final XRayEndpointInfo endpoint;

  const XRayButton({
    required this.elementKey,
    required this.label,
    required this.endpoint,
    super.key,
  });

  @override
  State<XRayButton> createState() => _XRayButtonState();
}

class _XRayButtonState extends State<XRayButton> {
  bool _busy = false;

  Future<void> _run(Map<String, String> params) async {
    setState(() => _busy = true);
    try {
      final response = await XRayPlugin().invoke(
        widget.endpoint.method,
        params: params,
      );
      if (!mounted) return;
      _showResult(response);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(developer.ServiceExtensionResponse response) {
    final raw = response.result ?? '';
    String message;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      message = decoded['status'] == 'success'
          ? 'OK: ${jsonEncode(decoded['data'])}'
          : 'Error: ${decoded['failure']?['message'] ?? decoded['failure']}';
    } catch (_) {
      message = raw;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _onPressed() async {
    if (widget.endpoint.params.isEmpty) {
      await _run(const {});
      return;
    }
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _XRayParamForm(endpoint: widget.endpoint),
    );
    if (values != null) {
      await _run(values);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: widget.elementKey,
      onPressed: _busy ? null : _onPressed,
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
          : Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

/// Inline form for endpoints whose `params` map is non-empty.
///
/// When `params` has a single `args` entry whose value matches a registered
/// entity schema (e.g. `{'args': 'Todo'}`) and the app registered it via
/// [XRayPlugin.registerEntitySchema], the form renders typed fields per
/// entity field (String → text, int → number, bool → switch, DateTime →
/// date picker). Otherwise it falls back to one raw text field per param.
class _XRayParamForm extends StatefulWidget {
  final XRayEndpointInfo endpoint;
  const _XRayParamForm({required this.endpoint});

  @override
  State<_XRayParamForm> createState() => _XRayParamFormState();
}

class _XRayParamFormState extends State<_XRayParamForm> {
  final Map<String, TextEditingController> _controllers = {};
  bool _boolValue = false;
  DateTime? _dateValue;

  @override
  void initState() {
    super.initState();
    final entityFields = _entityFields();
    if (entityFields != null) {
      // Create controllers for typed entity fields (skip bool/DateTime —
      // those use dedicated state vars).
      for (final field in entityFields) {
        if (field.type != 'bool' && field.type != 'DateTime') {
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

  /// If params is {'args': 'Todo'} and Todo is registered, return fields.
  List<XRayEntityField>? _entityFields() {
    final params = widget.endpoint.params;
    if (params.length == 1 && params.containsKey('args')) {
      return XRayPlugin().entityFieldsFor(params['args']!);
    }
    return null;
  }

  /// Show date picker and set [_dateValue].
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateValue ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateValue = picked);
  }

  Map<String, String> _collectValues() {
    final entityFields = _entityFields();
    if (entityFields != null) {
      // Build a JSON blob from typed fields.
      final Map<String, dynamic> json = {};
      for (final field in entityFields) {
        final ctrl = _controllers[field.name];
        switch (field.type) {
          case 'int':
            json[field.name] = int.tryParse(ctrl?.text ?? '') ?? 0;
          case 'double':
            json[field.name] = double.tryParse(ctrl?.text ?? '') ?? 0.0;
          case 'bool':
            json[field.name] = field.name == _boolFieldName() ? _boolValue : false;
          case 'DateTime':
            json[field.name] = _dateValue?.toIso8601String() ?? DateTime.now().toIso8601String();
          default:
            json[field.name] = ctrl?.text ?? '';
        }
      }
      return {'args': jsonEncode(json)};
    }
    // Fallback: raw text fields.
    return {
      for (final entry in _controllers.entries)
        entry.key: entry.value.text,
    };
  }

  /// For a single-bool entity, find the bool field name.
  String _boolFieldName() {
    final fields = _entityFields();
    if (fields == null) return '';
    return fields.where((f) => f.type == 'bool').firstOrNull?.name ?? '';
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
            if (entityFields != null)
              ...entityFields.map((field) => _buildEntityField(field))
            else
              ...widget.endpoint.params.entries.map((entry) {
                return Padding(
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
                );
              }),
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
            Navigator.of(context).pop(_collectValues());
          },
          child: const Text('Call'),
        ),
      ],
    );
  }

  Widget _buildEntityField(XRayEntityField field) {
    final key = XRayElementKey.formField(widget.endpoint.method, field.name);
    switch (field.type) {
      case 'int':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            key: key,
            controller: _controllers[field.name],
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '${field.name} (int)',
              labelStyle: const TextStyle(color: Colors.white54),
            ),
          ),
        );
      case 'double':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            key: key,
            controller: _controllers[field.name],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '${field.name} (double)',
              labelStyle: const TextStyle(color: Colors.white54),
            ),
          ),
        );
      case 'bool':
        return SwitchListTile(
          key: key,
          title: Text(field.name, style: const TextStyle(color: Colors.white)),
          value: _boolValue,
          onChanged: (v) => setState(() => _boolValue = v),
        );
      case 'DateTime':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            key: key,
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '${field.name} (DateTime)',
                labelStyle: const TextStyle(color: Colors.white54),
              ),
              child: Text(
                _dateValue != null
                    ? '${_dateValue!.year}-${_dateValue!.month.toString().padLeft(2, '0')}-${_dateValue!.day.toString().padLeft(2, '0')}'
                    : 'Pick date...',
                style: TextStyle(
                  color: _dateValue != null ? Colors.white : Colors.white38,
                ),
              ),
            ),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            key: key,
            controller: _controllers[field.name],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: '${field.name} (${field.type})',
              labelStyle: const TextStyle(color: Colors.white54),
            ),
          ),
        );
    }
  }
}
