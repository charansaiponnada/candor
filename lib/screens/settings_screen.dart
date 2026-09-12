/// User + model settings. Writes through to a [SettingsStore] on every change
/// (the file is a few bytes, so there is no "Save" button to forget).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/model_runner.dart';
import '../services/stores.dart';
import '../widgets/glass.dart';

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
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GlassCard(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, 'You'),
                const SizedBox(height: 12),
                GlassTextField(
                  key: const ValueKey('display-name'),
                  controller: _nameCtl,
                  labelText: 'Name',
                  helperText: 'Candor will address you by this name.',
                  onChanged: (v) {
                    _name = v;
                    _save();
                  },
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: _personaCtl,
                  minLines: 2,
                  maxLines: 4,
                  labelText: 'Persona',
                  helperText:
                      'e.g. "short, plain answers" or "you are a patient tutor"',
                  onChanged: (v) {
                    _persona = v;
                    _save();
                  },
                ),
              ],
            ),
          ),
          GlassCard(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, 'Appearance'),
                const SizedBox(height: 12),
                GlassSegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'system',
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System')),
                    ButtonSegment(
                        value: 'light',
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light')),
                    ButtonSegment(
                        value: 'dark',
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark')),
                  ],
                  selected: {widget.store.themeMode},
                  onSelectionChanged: (sel) {
                    final mode = sel.first;
                    setState(() => widget.store.themeMode = mode);
                    unawaited(widget.store.save().catchError((_) {}));
                  },
                ),
              ],
            ),
          ),
          GlassCard(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, 'Models'),
                const SizedBox(height: 12),
                FutureBuilder<List<String>>(
                  future: _models,
                  builder: (context, snap) {
                    final models = snap.data ?? const <String>[];
                    if (models.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No bundled models found.',
                            style: TextStyle(color: cs.textTertiary)),
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
              ],
            ),
          ),
          GlassCard(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, 'Performance'),
                const SizedBox(height: 12),
                FutureBuilder<(bool, String)>(
                  future: _gpu,
                  builder: (context, snap) {
                    final supported = snap.data?.$1 ?? false;
                    final detail = snap.data?.$2 ?? 'Checking…';
                    return GlassContainer(
                      padding: const EdgeInsets.all(16),
                      surfaceLevel: GlassSurfaceLevel.level2,
                      border: GlassBorder.subtle,
                      borderRadius: CandorRadius.md,
                      onTap: () {
                        setState(
                            () => widget.store.useGpu = !widget.store.useGpu);
                        _save();
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Use GPU (Vulkan)',
                                    style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(detail,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: supported
                                              ? cs.tier1
                                              : cs.textTertiary,
                                        )),
                              ],
                            ),
                          ),
                          Switch(
                            value: widget.store.useGpu,
                            onChanged: (v) {
                              setState(() => widget.store.useGpu = v);
                              _save();
                            },
                            activeThumbColor: cs.accent,
                            activeTrackColor: cs.accentContainer,
                            inactiveThumbColor: cs.textDisabled,
                            inactiveTrackColor: cs.glassSurface2,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelPicker(String title, String current, List<String> options,
      ValueChanged<String> onChanged) {
    final all = options.contains(current) ? options : [current, ...options];
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      surfaceLevel: GlassSurfaceLevel.level2,
      border: GlassBorder.subtle,
      borderRadius: CandorRadius.md,
      child: DropdownButton<String>(
        key: ValueKey(title),
        value: current,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: CandorColors.black,
        style: TextStyle(color: Theme.of(context).colorScheme.textPrimary),
        items: [
          for (final m in all)
            DropdownMenuItem(
              value: m,
              child: Text(m, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.textSecondary),
      ),
    );
  }

  static Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.accent,
                fontWeight: FontWeight.w700)),
      );
}