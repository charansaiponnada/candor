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
  models.dart              Tier/ThermalLevel/FinalTier enums, ChatMessage, Conversation,
                           EscalationRecord (the JSONL row, PRD §6.5)
  services/
    device_state.dart      native MethodChannel bridge (battery, thermal, model-file prep,
                           bundled-model listing) + real-vs-simulated readout + demo override
    model_runner.dart      llama_flutter_android wrapper, single controller, resident
                           (tier, model, gpu) caching, single-pass confidence parsing,
                           settings-driven model choice + optional Vulkan offload
    router.dart            decision table + EscalationLog (JSON-lines file)
    tools.dart             tool context: regex intent detector + intent executor
                           (open app, set timer, SMS/email draft, open website)
    stores.dart            JSON-file persistence: ChatStore (conversations.json,
                           corrupt file preserved as .bak) + SettingsStore (settings.json)
  screens/
    chat_screen.dart       conversation-backed Claude-style chat: borderless answers,
                           quiet `● Tier-1 · 12.4s · conf 0.95` attribution, typing dots,
                           multi-turn history fed back as ChatML context
    conversations_screen.dart chat history list: newest-first, swipe-to-delete, "New chat"
    settings_screen.dart   name/persona, per-tier model dropdowns, GPU (Vulkan) switch
                           with a live capability line
    debug_panel.dart       live device readout, latency pitch data, simulate toggle
android/…/MainActivity.kt  one MethodChannel "candor/device":
                           getBatteryPercent (BatteryManager)
                           getThermalStatus (PowerManager, API 29+)
                           prepareModel (stream-copy bundled GGUF out of assets)
                           listModels (assets/models for the picker)
test/                      decision-table + log + prompt-assembly tests with stubbed
                           runner/monitor + store/conversation/settings tests
                           (57 tests total, all pass)
```

### Router decision table (PRD §6.4)

Per query: run Tier-1 → read device state → decide.

Escalate to Tier-2 only when Tier-1 is *low*:

- **low** = a parsed `conf:<X>` tag < 0.7, OR the answer is empty, OR the
  answer looks like a refusal (measured on-device: the 0.5B reports 0.95–0.99
  even when it confabulates, but refuses or goes quiet when stuck).
- A **missing/unparsable tag parses to 0.0 but is trusted** when the answer is
  substantive and non-refusal — the 0.5B omits its tag on good answers too.

| Tier-1 output | Device state (battery ≥ 20% AND thermal < MODERATE) | Result |
|---|---|---|
| parsed conf ≥ 0.7 (or missing tag + substantive answer) | any | Tier-1 answer, badge `Tier-1` |
| low (parsed conf < 0.7, or empty, or refusal) | OK | run Tier-2, badge `Tier-2` |
| low | constrained | Tier-1 answer anyway, badge `Tier-1 (constrained)` + degradation note |

If Tier-2 itself declines (refusal), the final answer falls back to the
Tier-1 draft with the note "The larger on-device model declined this ask;
kept the Tier-1 answer." — a failure never degrades into a canned apology.

Every query appends one JSON line to `<app-docs>/escalations.jsonl`
(`EscalationRecord`), the input for the future self-improvement research.

## Tool context (beyond a chatbot)

Action asks are executed on-device **before** any model pass — deterministic,
offline, no extra inference:

- "open the camera / whatsapp / settings / …" → launches the matching app
  (package candidates per app, resolves the first installed one)
- "set a timer for 10 minutes" → Clock's `ACTION_SET_TIMER` with `LENGTH`
  (duration **alarms** — "set an alarm for 15 secs" — route here too; only
   time-of-day alarms, "set an alarm for 7 AM", fall through to the model)
- "text mom that I'll be late" → SMS draft (recipient + body)
- "email the team about the demo" → mail draft
- "open github.com" → browser (`ACTION_VIEW`)

Regex intent detection in `services/tools.dart`; execution via
`android_intent_plus` platform intents. A tool run renders a distinct action
card instead of an answer bubble. Ordinary questions can't be mis-routed
(each pattern requires a concrete target: an app name, a duration, a domain).
Android `<queries>` visibility for https/sms/text/SET_TIMER is declared in the
manifest. Samsung's timer activity refuses `ACTION_SET_TIMER` unless the
caller holds `com.android.alarm.permission.SET_ALARM` (a `normal` permission),
so the manifest declares both that legacy name and `android.permission.SET_ALARM`.
If no app can handle an intent, the card shows "Couldn't do that" instead of a
crypto error.

## Chat history & personalization

- **Multi-conversation chat history.** Every completed turn lands in
  `<app-docs>/conversations.json` (ChatStore). The chat list shows the newest
  thread first (title from the first question, snippet from the last reply);
  swipe deletes, "New chat" opens a fresh thread. A corrupted history file is
  preserved as `.bak` instead of being wiped.
- **Multi-turn memory.** The last 6 prior turns (empty rows skipped, adjacent
  same-role turns merged, tool cards treated as assistant turns) are fed back
  into the ChatML context, so follow-ups like "what about the second one?" work.
- **Name & persona.** Settings → `displayName` / `persona` are appended at the
  **end** of the system prompt, so Tier-1's two-line `conf:` output contract is
  untouched. Changes apply on the next query.
- **Model selection.** Settings lets you pick which bundled GGUF serves each
  tier (the picker reads `assets/models`), and flip `Use GPU (Vulkan)` — inputs
  are applied on the next query (the resident model reloads when the model or
  GPU setting changes).

## Known limitations / decisions (PRD §9 asks to state these)

- **Confidence proxy is self-assessed, not logprob-based.** The `llama_flutter_android`
  plugin streams `String` tokens and exposes no token logprobs, so the PRD's
  avg/min-logprob confidence is impossible without forking the plugin. Instead,
  Tier-1 is prompted to open its reply with a `conf:<X>` line, parsed from the
  same single generation pass (no second inference). The parser accepts
  `conf:`/`Conf=`/`confidence=<X>` case- and format-variants; the tag line is
  always stripped from the displayed answer.
- **Missing tag = 0.0, but trusted when substantive.** Measured on-device
  (Sep 2026): the 0.5B omits its `conf:<X>` tag on good answers (e.g. a solid
  rain poem) and refuses or returns empty only when stuck; the 1.5B refuses
  innocuous creative asks ("write me a hamlet on rain") even with a
  creative-writing system prompt. So a missing/unparsable tag parses to 0.0
  but *does not* escalate by itself. Escalation is gated on a parsed conf
  < 0.7, an empty answer, or a refusal match — and a Tier-2 refusal falls back
  to the Tier-1 draft instead of showing a canned apology.
- **Creative writing is explicitly authorized** in both tiers' system prompts
  ("Creative writing … is welcome and allowed"); the first build's refusal of
  the rain-hamlet request was a prompt cause, not a safety one.
- **Load-on-demand, one model at a time, last tier cached.** The plugin supports
  a single loaded model per process (`isModelLoaded` is one global flag), so two
  resident models are impossible without forking it. The last loaded tier stays
  resident for reuse (consecutive same-tier queries skip the ~1–3 s load) and is
  disposed only on a tier switch (PRD §9's load-on-demand fallback). Only one
  model sits in RAM (≈0.5 GB or ≈1.1 GB). Escalations pay Tier-1's pass +
  swap-to-Tier-2.
- **CPU-only by default, Vulkan optional.** `gpuLayers: 0` unless `Use GPU
  (Vulkan)` is on in Settings (off by default for deterministic cross-device
  behavior); when on, offload depth uses the plugin's
  `detectGpu().recommendedGpuLayers` recommendation (0 if Vulkan is
  unavailable). 8 threads; 200 max tokens for Tier-1, 256 for Tier-2.
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

## Pitch data (measured on SM-E366B, Q4_K_M, CPU-only)

| Path | Latency |
|---|---|
| Tier-1 only | ≈ 4–7 s (e.g. 4.0 s, 6.7 s, 7.3 s on simple factual asks) |
| Escalated (Tier-1 → Tier-2) | Tier-1 pass + model swap to the 1.5B (adds its load + pass); strictly device-dependent — read the live value per query in Debug & Demo |

The Debug & Demo panel shows a running latency read for both paths.
Offline proof: enable airplane mode, run again — the app keeps working.
Permission proof: `android/app/src/main/AndroidManifest.xml` (the release
manifest) declares no `INTERNET` permission — the app is architecturally
incapable of a network call. (The debug-flavor manifest adds it only for
Flutter's hot-reload tooling; it's stripped from release builds.)