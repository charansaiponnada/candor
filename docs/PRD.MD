# PRD — On-Device SLM Assistant (Two-Tier, Trust-Transparent)
Name: Candor — short, memorable, directly evokes the trust-signaling angle. "Candor: an assistant that tells you when it's holding back."
## 1. Product overview

An Android app that runs a two-tier quantized language model cascade fully offline. A small model (Tier-1) answers by default; a larger model (Tier-2) is used only when the query seems to need it AND the device has resource headroom. The app explicitly tells the user which tier answered and why, rather than silently switching.

**Non-negotiable constraint:** zero network calls at inference time. Everything — model loading, inference, routing — happens on-device.

## 2. Goals

- Working offline chat UI backed by a local LLM
- A router that escalates between two models based on (a) Tier-1's own confidence and (b) live battery/thermal state
- Visible, honest UI feedback when the app is running in a constrained/degraded mode
- A debug-only toggle to simulate constrained device state for demo purposes, clearly labeled as simulated

## 2.1 Build priority for this hackathon (read before starting)

Given the time constraint, effort is not spent evenly across the app. In order:

1. **Working backend loop** — Tier-1 answers, router branches correctly, Tier-2 escalates when it should. Nothing else matters if this is broken.
2. **Material 3 UI that makes the tier badge and degradation note impossible to miss** — this is where judges actually perceive the project's novelty. Treat this as core work, not polish.
3. **Light benchmarking** — one honest latency number per path (Tier-1-only vs. escalated) is enough for the pitch. Do not spend time on statistically rigorous benchmarking here.
4. **Explicitly not this build's job**: cross-device validation, formal accuracy evaluation, anything from the research-paper track. Skip it now.

## 3. Non-goals (out of scope for this build)

- No live on-device fine-tuning or the self-improvement loop — that's a research roadmap item, not part of this app
- No multilingual support — single language (English) for v1
- No cloud fallback of any kind
- No user accounts, sync, or persistence beyond local chat history

## 4. Target platform and stack

- Android, minimum API 29 (needed for `PowerManager.getCurrentThermalStatus()`)
- Target a mid-range device profile (assume 6–8GB RAM) for sizing model choices
- **Framework: Flutter, with Material 3 (`useMaterial3: true`) as the design system** — chosen for UI velocity, since the transparency/trust messaging is the project's core differentiator and needs to be visually clear, not just functionally correct
- Thermal status (`PowerManager.getCurrentThermalStatus()`) is not exposed by existing Flutter plugins as of this build — implement a small native Kotlin `MethodChannel` just for this one call; everything else can stay in Dart

## 5. Models

- **Tier-1**: Qwen2.5-0.5B-Instruct, GGUF, Q4_K_M quantization
- **Tier-2**: Qwen2.5-1.5B-Instruct, GGUF, Q4_K_M quantization
- Inference via the `llama_flutter_android` plugin (llama.cpp-backed, GGUF support, Vulkan acceleration) rather than hand-rolling JNI bindings
- Both models ship bundled with the app or are downloaded once on first launch and cached locally (no network needed after that) — pick whichever is simpler to implement first; bundling is simpler for a hackathon build

## 6. Core functional requirements

### 6.1 Chat interface (Material 3)
- Single-screen chat UI built with Flutter's Material 3 widgets (`ChatBubble`-style custom widget on top of `Card`/`Container`, `FilledButton` for send, `TextField` with Material 3 styling for input)
- Each assistant message carries a tier badge as a Material 3 `Chip` or `Badge` — "Tier-1" and "Tier-2" should be visually distinct (different `ColorScheme` tonal colors, not just text)
- Degraded/constrained responses get a visible inline banner on that message (Material 3 `Card` with a warning tonal color, e.g. `colorScheme.errorContainer` or a custom amber tone), not just a text label — this needs to be readable at a glance during a live demo, including from a few feet away if presenting on a projected screen
- Use `ColorScheme.fromSeed()` to generate a cohesive Material 3 palette rather than default colors, so the app doesn't look like an unstyled template

### 6.2 Inference engine wrapper
- A single interface, e.g. `ModelRunner`, with methods to load a given tier's model and run generation given a prompt
- Generation call must return both the text output and a confidence signal (derived from token-level logprobs of the generated response — average or minimum logprob across generated tokens is sufficient for v1)
- Must support having both models loaded, or loading on demand — pick based on measured memory headroom during Phase 1; document the choice and the tradeoff (escalation latency vs. memory footprint) in the README

### 6.3 Device signal service
- A service/class, e.g. `DeviceStateMonitor`, exposing:
  - `getBatteryPercent(): Int` via `BatteryManager`
  - `getThermalStatus(): Int` via `PowerManager.getCurrentThermalStatus()` (map to an enum: NONE, LIGHT, MODERATE, SEVERE, CRITICAL+)
- Must be pollable on demand (called at query time), not just a background listener
- Include a debug override: a boolean flag + a manually settable thermal/battery value, toggled from a debug UI panel, clearly visually distinguished (e.g., a persistent banner "SIMULATED CONSTRAINED MODE" whenever the override is active)

### 6.4 Router logic
- A `Router` component that, per query:
  1. Runs Tier-1, gets draft answer + confidence score
  2. Reads device state via `DeviceStateMonitor`
  3. Decision table:
     - If confidence is high → return Tier-1 answer, tag "Tier-1"
     - If confidence is low AND device state allows (battery above threshold, e.g. 20%, AND thermal status below MODERATE) → run Tier-2, return that answer, tag "Tier-2"
     - If confidence is low AND device state does NOT allow → return Tier-1 answer anyway, tag "Tier-1 (constrained)", attach the degradation note
  4. Log every query as an `EscalationRecord` (see data model below) regardless of outcome — this log is not used live in this app, but should be structured cleanly since it's the input to the future self-improvement research work

### 6.5 Data model
```
EscalationRecord {
  timestamp: Long
  query: String
  tier1Answer: String
  tier1Confidence: Float
  batteryPercent: Int
  thermalStatus: Enum
  escalated: Boolean
  tier2Answer: String?         // null if not escalated
  finalTierUsed: "tier1" | "tier1_constrained" | "tier2"
}
```
- Store as local JSON lines file or a simple local SQLite table — either is fine, pick whichever is faster to implement

### 6.6 Debug/demo panel
- Separate screen, reached via a Material 3 `IconButton` (settings icon) in the app bar — fast to reach, not buried in a menu
- Live readout of actual battery % and thermal status, styled as Material 3 `ListTile`s or stat cards, not raw debug text
- Toggle: "Simulate constrained mode" (overrides the values the router sees) — use a Material 3 `Switch`, with a persistent `Banner` or colored app-bar state shown app-wide whenever it's active, so it's obvious during the demo that constrained mode is on
- Toggle: reset to real device values
- This panel is presented live in front of judges — it should look intentional and designed, not like a debug leftover

## 7. Non-functional requirements

- **Privacy**: no network permission requested beyond what's unavoidable for the base template; ideally the app should function correctly with network access fully disabled at the OS level, and this should be demonstrable live (airplane mode test)
- **Latency**: log and display (in the debug panel) the response time for both Tier-1-only and Tier-1+Tier-2 escalation paths — this becomes pitch material
- **Memory**: log peak memory usage in the debug panel if feasible; if not feasible in the timeframe, at minimum note it manually in testing

## 8. Milestones and acceptance criteria

| Phase | Done when |
|---|---|
| Foundation | Tier-1 alone answers a query fully offline on a real device via `llama_flutter_android`; battery/thermal values read correctly (thermal via the native MethodChannel) in a standalone test screen |
| Model Integration | Tier-2 loads and answers; confidence score is extracted from Tier-1 generation without a second inference pass |
| Gating & Transparency (backend) | Router correctly branches per the decision table above — prioritize this working correctly before touching UI polish |
| UI Pass (Material 3) | Tier badges, degradation banners, and the debug/demo panel are built out fully in Material 3 and are clearly legible in a live demo setting — this is core work, not an afterthought |
| Light Benchmarking & Finalization | One latency number per path recorded for the pitch; airplane-mode offline proof works; README explains the architecture; repo clean; demo rehearsed against the debug panel |

## 9. Open assumptions to confirm during build (not blocking, but flag if wrong)

- Confidence proxy (avg/min token logprob) is assumed "good enough" for v1 — no time to validate this against a labeled dataset in this build; state this as a known limitation, don't try to fix it now
- Both models are assumed to fit in memory simultaneously on the target device; if not, switch to load-on-demand and note the latency cost this adds to escalation