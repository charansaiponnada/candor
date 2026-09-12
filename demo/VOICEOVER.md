# Candor — Project Explanation Video (Voiceover Script)

Length: ~5 min · Read naturally, no rush · Sections are timecoded to the on-screen demo.

---

## 1. Opening (0:00 – 0:20)
> "Hi everyone. This is Candor — a private AI assistant that runs **entirely on your phone**. No internet, no cloud, no data leaving your device. Everything you see here generated live, right now, on this handset."

*On screen: app launching into chat.*

## 2. The problem (0:20 – 0:45)
> "Most chat assistants today are cloud apps. Your conversations go to a server, the model runs somewhere far away, and that only works with a network connection.
> Candor flips that. The actual AI models are bundled inside the APK and run on-device, on this phone's CPU. The release build literally ships with **no internet permission** — so it cannot phone home even if it wanted to."

*On screen: swipe to "New chat"; show the "Fully on-device · works offline" subtitle.*

## 3. Two-tier engine — the honest model cascade (0:45 – 1:10)
> "And here's the interesting part — Candor doesn't run one model. It runs **two**, and it's honest about which one answered.
> A small, fast 0.5 billion parameter model answers by default. When it answers with high confidence, you see its badge. When it struggles or admits low confidence, Candor escalates to a bigger 1.5 billion parameter model — but only if the phone has the battery and thermal headroom."

*On screen: the attribution badges under each answer.*

## 4. Demo — deterministic skills (1:10 – 1:45)
> "Let's see it. I'll tap the suggestion for a square root. Instead of guessing with the language model, Candor's calculator *skill* catches it — a deterministic math engine that can't hallucinate numbers."
> "This is huge for a small model: arithmetic that is always exactly right, instantly, with zero tokens spent on inference."

*On screen: tap "What is the square root of 144?" → instant exact answer.*

## 5. Demo — Tier-1 language model (1:45 – 2:30)
> "Now a question the small model actually enjoys — explaining recursion to a 12-year-old. Watch the answer stream in with its attribution badge: **Tier-1**, milliseconds, and the model's self-assessed confidence. Every reply carries this badge, so the assistant never pretends."

*On screen: tap the recursion prompt → streaming markdown answer + Tier-1 conf badge.*

## 6. Demo — escalation to Tier-2 (2:30 – 3:20)
> "Here's where the cascade matters. This question is edge-of-knowledge for the 0.5B — it flags low confidence, Candor promotes the query to the 1.5B model, and the answer arrives under a **Tier-2 badge**. Same app, same prompt box — the router decides, transparently."

*On screen: tap LAN/WAN question → Tier-1 silhouette → Tier-2 answer + badge. (If it stays Tier-1 live, the voiceover should say: "...and when it does have confidence, it still tells you exactly which model and confidence score produced the answer.")*

## 7. Demo — platform tools (3:20 – 3:50)
> "Candor doesn't just talk — it acts. Asking for a timer hands the request to the phone's own timer app via Android intents. It can also launch apps, open websites, draft SMS and email, or jump into system settings — all triggered from plain chat."

*On screen: tap "Set a timer for 10 minutes" → stock clock timer opens.*

## 8. Proof screens — models, skills, prompt lab (3:50 – 4:30)
> "Under the hood, the Skills hub shows every deterministic capability — calculator, unit converter, timers, intents. The Models page lists the exact bundled GGUF files with their sizes and live load times. And the Prompt Lab exposes real sampling controls — temperature, top-p, top-k — so you can tune the model's personality or run one-shot asks."

*On screen: Skills hub → Models & Benchmarks → Prompt Lab.*

## 9. Proof screens — debug & settings (4:30 – 5:05)
> "The Debug and Demo panel shows live device state — battery and thermal — and includes a simulated constrained mode that blocks the larger model, exactly as the router would if your phone were low on power.
> Settings cover appearance, your name, installed models, and a Vulkan GPU toggle for faster inference on supported chips."

*On screen: Debug panel, flip "Simulate constrained mode" → Settings showing models and GPU toggle.*

## 10. Closing (5:05 – 5:30)
> "Candor is a Flutter app backed by llama.cpp, with two quantized Qwen models bundled in the APK — about 1.5 GB total, but completely private and fully offline.
> It tells you when it is confident, when it escalates, and when it can't help at all. That is what candor means — an assistant that is honest about its own limits. Thank you."

*On screen: back to main chat.*

---

## Recording the demo video yourself

Phone plugged in via USB with USB debugging on, run from this folder:

```powershell
adb shell screenrecord --bit-rate 10M --time-limit 176 /sdcard/demo_full.mp4
adbadb pull /sdcard/demo_full.mp4 C:\projects\candor\demo\demo.mp4
```

(Max 3 minutes per file. If the demo runs longer, stop it with Ctrl-C, note the timestamp, record a second take, then merge the two MP4s in your editor.)

## Edit + voiceover

1. Cut dead air at the start and between prompts (model runs ~8–60 s per answer; keep the answers, trim the waiting).
2. Record the voiceover in an editor (Canva / CapCut / Clipchamp) over the silent video, reading the sections above against the timecodes.
3. Optionally add the app name + "Hackathon 2026" title card at 0:00 and end card at 5:30.