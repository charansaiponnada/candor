# Candor

An Android app that runs a **two-tier quantized SLM cascade fully offline**. A small
model (Tier-1: Qwen2.5-0.5B-Instruct) answers by default; a larger model
(Tier-2: Qwen2.5-1.5B-Instruct) runs only when the query seems to need it **and**
the device has resource headroom. Candor always tells you which tier answered and
why — "an assistant that tells you when it's holding back."

Zero network calls at inference time. Battery/thermal state gate the escalation.

## Architecture

```
lib/
  main.dart                M3 theme (useMaterial3 + ColorScheme.fromSeed) + startup wiring
  models.dart              Tier/ThermalLevel/FinalTier enums, ChatMessage,
                           EscalationRecord (the JSONL row, PRD §6.5)
  services/
    device_state.dart      native MethodChannel bridge (battery, thermal, model-file prep)
                           + real-vs-simulated readout + demo override
    model_runner.dart      llama_flutter_android wrapper, one LlamaController per tier,
                           single-pass confidence parsing
    router.dart            decision table + EscalationLog (JSON-lines file)
  screens/
    chat_screen.dart       chat UI: tier badge Chip, constrained Card banner
    debug_panel.dart       live device readout, latency pitch data, simulate toggle
android/…/MainActivity.kt  one MethodChannel "candor/device":
                           getBatteryPercent (BatteryManager)
                           getThermalStatus (PowerManager, API 29+)
                           prepareModel (stream-copy bundled GGUF out of assets)
test/router_test.dart      decision-table + log tests with stubbed runner/monitor
```

### Router decision table (PRD §6.4)

Per query: run Tier-1 → read device state → decide.

| Tier-1 confidence | Device state (battery ≥ 20% AND thermal < MODERATE) | Result |
|---|---|---|
| high (≥ 0.5) | any | Tier-1 answer, badge `Tier-1` |
| low (< 0.5) | OK | run Tier-2, badge `Tier-2` |
| low (< 0.5) | constrained | Tier-1 answer anyway, badge `Tier-1 (constrained)` + degradation note |

Every query appends one JSON line to `<app-docs>/escalations.jsonl`
(`EscalationRecord`), the input for the future self-improvement research.

## Known limitations / decisions (PRD §9 asks to state these)

- **Confidence proxy is self-assessed, not logprob-based.** The `llama_flutter_android`
  plugin streams `String` tokens and exposes no token logprobs, so the PRD's
  avg/min-logprob confidence is impossible without forking the plugin. Instead,
  Tier-1 is prompted to open its reply with a `conf=<0.00-1.00>` line, parsed from
  the same single generation pass (no second inference). If parsing fails the
  confidence defaults to `0.5`. Weak proxy, accepted for this build, to be
  replaced by logprob-based confidence.
- **Both models load at startup** (≈1.4 GB resident: 400 MB + 1 GB). Escalation is
  therefore pure Tier-2 inference with no reload latency. Tradeoff: a device with
  too little RAM should switch to *load-on-demand* (single controller, reload per
  escalation) at the cost of escalation latency. Measured on the target device —
  see below.
- **CPU-only inference** (`gpuLayers: 0`) for deterministic behavior across
  devices. The plugin supports Vulkan (`detectGpu().recommendedGpuLayers`); switch
  if Tier-1 latency is disappointing.
- Chat history is in-memory only; only the escalation log persists.
- No accuracy evaluation, device matrix, or fine-tuning loop — explicitly out of
  scope for this build (PRD §3, §2.1).

## Build & run

```powershell
# 1) fetch the two Qwen GGUFs into android/app/src/main/assets/models/ (~1.4 GB)
powershell -ExecutionPolicy Bypass -File tools/download_models.ps1

# 2) build / install on a connected device (minSdk 29+)
flutter pub get
flutter build apk --debug
flutter install
```

First launch copies the bundled models into app storage (streaming, ~seconds),
then loads both models — the splash screen shows "Loading on-device models…".

## Pitch data (fill after device measurement)

| Path | Latency |
|---|---|
| Tier-1 only | _measure in Debug & Demo panel_ |
| Escalated (Tier-1 → Tier-2) | _measure in Debug & Demo panel_ |

Offline proof: enable airplane mode, run again — the app keeps working.