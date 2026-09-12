import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' hide Router;

import '../models.dart';
import '../services/device_state.dart';
import '../services/router.dart';
import '../widgets/glass.dart';

/// Debug/demo panel (PRD §6.6): live real device readout, latency pitch data,
/// and the simulated-constrained-mode toggle. Presented live to judges, so it
/// uses real M3 components, not raw debug text.
class DebugPanel extends StatefulWidget {
  final DeviceStateMonitor monitor;
  final Router router;

  const DebugPanel({super.key, required this.monitor, required this.router});

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late Future<DeviceState> _realState;

  @override
  void initState() {
    super.initState();
    _realState = widget.monitor.readReal();
  }

  void _refresh() => setState(() => _realState = widget.monitor.readReal());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('Debug & Demo'),
        actions: [
          GlassIconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-read device values',
            onPressed: _refresh,
            size: 40,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 32),
        children: [
          Text('Device state',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: cs.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _LiveReadout(state: _realState),
          const SizedBox(height: 24),
          _SimulateCard(monitor: widget.monitor),
          const SizedBox(height: 24),
          Text('Latency (pitch data)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: cs.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _LatencyCard(router: widget.router),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      surfaceLevel: GlassSurfaceLevel.level2,
      border: GlassBorder.subtle,
      child: child,
    );
  }
}

class _LiveReadout extends StatelessWidget {
  final Future<DeviceState> state;
  const _LiveReadout({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      child: FutureBuilder<DeviceState>(
        future: state,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Reading device…'),
                ],
              ),
            );
          }
          final d = snap.data!;
          return Column(
            children: [
              ListTile(
                leading: Icon(Icons.battery_full,
                    color: d.batteryPercent < 20 ? cs.error : cs.accent),
                title: const Text('Battery'),
                trailing: Text('${d.batteryPercent}%'),
                subtitle: LinearProgressIndicator(
                  value: d.batteryPercent / 100,
                  color: d.batteryPercent < 20 ? cs.error : cs.accent,
                  backgroundColor: cs.glassSurface2,
                ),
              ),
              ListTile(
                leading: Icon(
                    Icons.thermostat,
                    color: d.thermal.index >= ThermalLevel.moderate.index
                        ? cs.error
                        : cs.accent),
                title: const Text('Thermal status'),
                trailing: Text(switch (d.thermal) {
                  ThermalLevel.none => 'NONE',
                  ThermalLevel.light => 'LIGHT',
                  ThermalLevel.moderate => 'MODERATE',
                  ThermalLevel.severe => 'SEVERE',
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SimulateCard extends StatelessWidget {
  final DeviceStateMonitor monitor;
  const _SimulateCard({required this.monitor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(Icons.science_outlined, color: cs.accent),
            title: const Text('Simulate constrained mode'),
            subtitle: const Text('Router sees 5% battery, SEVERE thermal — '
                'blocks the larger model. Reset turns it off.'),
            value: monitor.simulating.value,
            onChanged: (v) => monitor.simulating.value = v,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: monitor.simulating,
            builder: (_, on, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  on
                      ? 'SIMULATED — real device values still shown above; the router ignores them while this is on.'
                      : 'Off. The router reads the real battery/thermal values above.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: on ? Theme.of(context).colorScheme.error : cs.textSecondary,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatencyCard extends StatelessWidget {
  final Router router;
  const _LatencyCard({required this.router});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: [
          _latencyTile(context, 'Tier-1 only', router.lastTier1Ms, router.tier1Count, '${router.constrainedCount.value} constrained'),
          _latencyTile(context, 'Escalated (Tier-1 → Tier-2)', router.lastEscalatedMs, router.tier2Count, null),
        ],
      ),
    );
  }

  Widget _latencyTile(BuildContext context, String title, ValueListenable<double?> ms,
      ValueListenable<int> count, String? extraInfo) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double?>(
      valueListenable: ms,
      builder: (_, v, _) => ListTile(
        title: Text(title),
        subtitle: Text(v == null ? 'No query yet' : '${(v / 1000).toStringAsFixed(1)}s'),
        trailing: ValueListenableBuilder<int>(
          valueListenable: count,
          builder: (_, runs, _) => Text(
            '$runs runs${extraInfo != null ? ' • $extraInfo' : ''}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.textSecondary),
          ),
        ),
      ),
    );
  }
}