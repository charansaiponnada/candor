import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/model_runner.dart';
import '../services/stores.dart';

/// Prompt Lab — Gallery's lab for single-turn experiments, done on-device.
/// Adjust sampling (temperature, top-k, top-p, repeat penalty) per tier,
/// fire a one-shot ask, watch it stream with live timing.
class PromptLabScreen extends StatefulWidget {
  final SettingsStore? store;
  const PromptLabScreen({super.key, this.store});

  @override
  State<PromptLabScreen> createState() => _PromptLabScreenState();
}

class _PromptLabScreenState extends State<PromptLabScreen> {
  final _input = TextEditingController(text: 'Write a haiku about a lighthouse.');
  Tier _tier = Tier.tier1;
  String _output = '';
  bool _running = false;

  /// Live local copies; committed to the store on change (see _save).
  late double _temp = _currentStore.t1Temp;
  late double _topP = _currentStore.t1TopP;
  late int _topK = _currentStore.t1TopK;
  late double _repPen = _currentStore.t1RepeatPenalty;

  SettingsStore get _currentStore => widget.store ?? SettingsStore.defaults();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _pickTier(Tier t) {
    setState(() {
      _tier = t;
      _temp = t == Tier.tier1 ? _currentStore.t1Temp : _currentStore.t2Temp;
      _topP = t == Tier.tier1 ? _currentStore.t1TopP : _currentStore.t2TopP;
      _topK = t == Tier.tier1 ? _currentStore.t1TopK : _currentStore.t2TopK;
      _repPen =
          t == Tier.tier1 ? _currentStore.t1RepeatPenalty : _currentStore.t2RepeatPenalty;
    });
  }

  void _save() {
    final s = _currentStore;
    if (_tier == Tier.tier1) {
      s.t1Temp = _temp;
      s.t1TopP = _topP;
      s.t1TopK = _topK;
      s.t1RepeatPenalty = _repPen;
    } else {
      s.t2Temp = _temp;
      s.t2TopP = _topP;
      s.t2TopK = _topK;
      s.t2RepeatPenalty = _repPen;
    }
    if (widget.store != null) {
      unawaited(widget.store!.save().catchError((_) {}));
    }
  }

  Future<void> _run() async {
    final query = _input.text.trim();
    if (query.isEmpty || _running) return;
    setState(() {
      _running = true;
      _output = '';
    });
    try {
      final r = await ModelRunner(settings: _currentStore).generate(
        _tier,
        query,
        onToken: (t) {
          if (mounted) setState(() => _output += t);
        },
      );
      if (mounted) {
        setState(() => _output =
            '${r.text}\n\n— ${r.latencyMs.toStringAsFixed(1)} ms · ${_tier.name}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _output = 'failed: $e');
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt Lab'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SegmentedButton<Tier>(
            segments: const [
              ButtonSegment(value: Tier.tier1, label: Text('Tier-1 · 0.5B')),
              ButtonSegment(value: Tier.tier2, label: Text('Tier-2 · 1.5B')),
            ],
            selected: {_tier},
            onSelectionChanged: (sel) => _pickTier(sel.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'A prompt to test…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _slider('Temperature', _temp, 0.0, 2.0, 0.05, (v) {
            setState(() => _temp = v);
            _save();
          }),
          _slider('Top-p', _topP, 0.0, 1.0, 0.05, (v) {
            setState(() => _topP = v);
            _save();
          }),
          _slider('Top-k', _topK.toDouble(), 1.0, 100.0, 1.0, (v) {
            setState(() => _topK = v.round());
            _save();
          }),
          _slider('Repeat penalty', _repPen, 1.0, 2.0, 0.05, (v) {
            setState(() => _repPen = v);
            _save();
          }),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_running ? 'Running…' : 'Run'),
          ),
          if (_output.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(_output,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max, double div,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text('$label  ${value.toStringAsFixed(value >= 100 ? 0 : 2)}',
                style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}