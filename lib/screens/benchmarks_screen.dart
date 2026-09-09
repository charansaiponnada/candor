import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device_state.dart';
import '../services/model_runner.dart';

/// On-device model benchmark — the Gallery's "Model Management & Benchmark"
/// feature, but measured on this phone, offline. Load time, streaming
/// tokens/sec, file size and compute device per bundled model.
class BenchmarksScreen extends StatefulWidget {
  const BenchmarksScreen({super.key});

  @override
  State<BenchmarksScreen> createState() => _BenchmarksScreenState();
}

class _BenchmarksScreenState extends State<BenchmarksScreen> {
  late final Future<List<String>> _models = DeviceStateMonitor.instance.listModels();
  late final Future<Map<String, int>> _sizes = DeviceStateMonitor.instance.modelSizes();
  final Map<String, BenchResult> _results = {};
  bool _running = false;

  Future<void> _run(String model) async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final r = await ModelRunner().benchmark(model, gpu: false);
      setState(() => _results[model] = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Benchmark failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _fmtBytes(int b) => b >= (1 << 30)
      ? '${(b / (1 << 30)).toStringAsFixed(2)} GB'
      : b >= (1 << 20)
          ? '${(b / (1 << 20)).toStringAsFixed(0)} MB'
          : '$b B';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Models & Benchmarks'),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<Map<String, int>>(
        future: _sizes,
        builder: (context, snap) {
          final sizes = snap.data ?? const <String, int>{};
          return FutureBuilder<List<String>>(
            future: _models,
            builder: (context, msnap) {
              final models = msnap.data ?? const <String>[];
              if (models.isEmpty) {
                return const Center(child: Text('No bundled models found.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: models.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final name = models[i];
                  final r = _results[name];
                  final size = sizes[name];
                  return Material(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.memory_rounded,
                                    color: cs.onPrimaryContainer),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                        size != null
                                            ? _fmtBytes(size)
                                            : 'Size unavailable (not prepared yet)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _running ? null : () => _run(name),
                                icon: r != null
                                    ? const Icon(Icons.replay_rounded, size: 18)
                                    : const Icon(Icons.play_arrow_rounded, size: 18),
                                label: Text(r != null ? 'Re-run' : 'Run'),
                              ),
                            ],
                          ),
                          if (r != null) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                _stat(cs, 'Load', '${r.loadMs} ms'),
                                _stat(cs, 'Speed', '${r.tokensPerSec.toStringAsFixed(1)} tok/s'),
                                _stat(cs, 'Device', r.device),
                                _stat(cs, 'Threads', '${r.threads}'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _stat(ColorScheme cs, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
        ],
      );
}