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
    model_runner.dart      llama_flutter_android wrapper, single controller,
                           resident-tier caching + single-pass confidence parsing
    router.dart            decision table + EscalationLog (JSON-lines file)
  screens/
    chat_screen.dart       Claude-style chat: borderless answers, quiet
                           `● Tier-1 · 12.4s · conf 0.95` attribution, typing dots
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
| high (≥ 0.7) | any | Tier-1 answer, badge `Tier-1` |
| low (< 0.7, or missing tag → 0.0, or empty answer) | OK | run Tier-2, badge `Tier-2` |
| low (< 0.7…) | constrained | Tier-1 answer anyway, badge `Tier-1 (constrained)` + degradation note |

Every query appends one JSON line to `<app-docs>/escalations.jsonl`
(`EscalationRecord`), the input for the future self-improvement research.

## Known limitations / decisions (PRD §9 asks to state these)

- **Confidence proxy is self-assessed, not logprob-based.** The `llama_flutter_android`
  plugin streams `String` tokens and exposes no token logprobs, so the PRD's
  avg/min-logprob confidence is impossible without forking the plugin. Instead,
  Tier-1 is prompted to open its reply with a `conf:<X>` line, parsed from the
  same single generation pass (no second inference). The parser accepts
  `conf:`/`Conf=`/`confidence=<X>` case- and format-variants; the tag line is
  always stripped from the displayed answer.
- **Missing tag = low confidence.** Measured on-device (Sep 2026): the 0.5B
  model reports 0.95–0.99 even when it confabulates, but *omits* the tag (or
  writes `Conf=<X>`) when it can't answer. An unparsable/missing tag therefore
  parses to **0.0** — "can't confirm ⇒ defer" — and raises the threshold above
  which Tier-1 is trusted to **0.7**. Forced as a last gate: an empty Tier-1
  answer escalates regardless of reported confidence.
- **Load-on-demand, one model at a time, last tier cached.** The plugin supports
  a single loaded model per process (`isModelLoaded` is one global flag), so two
  resident models are impossible without forking it. The last loaded tier stays
  resident for reuse (consecutive same-tier queries skip the ~1–3 s load) and is
  disposed only on a tier switch (PRD §9's load-on-demand fallback). Only one
  model sits in RAM (≈0.5 GB or ≈1.1 GB). Escalations pay Tier-1's pass +
  swap-to-Tier-2.
- **CPU-only inference** (`gpuLayers: 0`) for deterministic behavior across
  devices. 8 threads, 256 max tokens. The plugin supports Vulkan
  (`detectGpu().recommendedGpuLayers`); switch if Tier-1 latency is disappointing.
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

First launch copies the bundled models into app storage (streaming, ~seconds);
the splash shows "Preparing on-device models…". Tiers load on demand at first
query.

## Pitch data (fill after device measurement)

| Path | Latency |
|---|---|
| Tier-1 only | _measure in Debug & Demo panel_ |
| Escalated (Tier-1 → Tier-2) | _measure in Debug & Demo panel_ |

Offline proof: enable airplane mode, run again — the app keeps working.