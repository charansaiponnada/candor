/// User + model settings. Writes through to a [SettingsStore] on every change
/// (the file is a few bytes, so there is no "Save" button to forget).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/model_runner.dart';
import '../services/stores.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsStore store;
  final ModelRunner runner;

  const SettingsScreen(
      {super.key, required this.store, required this.runner});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _name = widget.store.displayName;
  late String _persona = widget.store.persona;
  late final Future<(bool supported, String name)> _gpu =
      widget.runner.gpuCapability();
  late final Future<List<String>> _models = widget.runner.listModels();

  // Controllers live for the screen's lifetime; recreating them per build
  // killed the field's undo/cursor state on every rebuild.
  late final TextEditingController _nameCtl =
      TextEditingController(text: widget.store.displayName)
        ..selection = TextSelection.collapsed(
            offset: widget.store.displayName.length);
  late final TextEditingController _personaCtl =
      TextEditingController(text: widget.store.persona)
        ..selection = TextSelection.collapsed(offset: widget.store.persona.length);

  @override
  void dispose() {
    _nameCtl.dispose();
    _personaCtl.dispose();
    super.dispose();
  }

  void _save() {
    widget.store
      ..displayName = _name.trim()
      ..persona = _persona.trim();
    unawaited(widget.store.save().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionTitle(context, 'You'),
          TextField(
            key: const ValueKey('display-name'),
            controller: _nameCtl,
            decoration: const InputDecoration(
              labelText: 'Name',
              helperText: 'Candor will address you by this name.',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              _name = v;
              _save();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _personaCtl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Persona',
              helperText:
                  'e.g. "short, plain answers" or "you are a patient tutor"',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              _persona = v;
              _save();
            },
          ),
          const SizedBox(height: 20),
          _sectionTitle(context, 'Appearance'),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'system', icon: Icon(Icons.brightness_auto_outlined), label: Text('System')),
                ButtonSegment(
                    value: 'light', icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                ButtonSegment(
                    value: 'dark', icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
              ],
              selected: {widget.store.themeMode},
              onSelectionChanged: (sel) {
                final mode = sel.first;
                setState(() =>
                    widget.store.themeMode = mode);
                unawaited(widget.store
                    .save()
                    .catchError((_) {}));
              },
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle(context, 'Models'),
          FutureBuilder<List<String>>(
            future: _models,
            builder: (context, snap) {
              final models = snap.data ?? const <String>[];
              if (models.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No bundled models found.'),
                );
              }
              final t1 = widget.store.tier1Model;
              final t2 = widget.store.tier2Model;
              return Column(
                children: [
                  _modelPicker('Tier-1 model', t1, models, (v) {
                    widget.store.tier1Model = v;
                    _save();
                  }),
                  const SizedBox(height: 12),
                  _modelPicker('Tier-2 model', t2, models, (v) {
                    widget.store.tier2Model = v;
                    _save();
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          FutureBuilder<(bool, String)>(
            future: _gpu,
            builder: (context, snap) {
              final supported = snap.data?.$1 ?? false;
              final detail = snap.data?.$2 ?? 'Checking…';
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use GPU (Vulkan)'),
                subtitle: Text(detail,
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: supported
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                            )),
                value: widget.store.useGpu,
                onChanged: (v) {
                  setState(() => widget.store.useGpu = v);
                  _save();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _modelPicker(String title, String current, List<String> options,
      ValueChanged<String> onChanged) {
    final all = options.contains(current) ? options : [current, ...options];
    return InputDecorator(
      decoration: InputDecoration(
        labelText: title,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButton<String>(
        key: ValueKey(title),
        value: current,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: [
          for (final m in all)
            DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700)),
      );
}