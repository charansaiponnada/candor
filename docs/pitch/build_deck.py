# -*- coding: utf-8 -*-
"""Candor pitch deck: 5 slides, OLED-black glass theme."""
from pptx import Presentation
from pptx.util import Inches as I, Pt
from pptx.dml.color import RGBColor as C
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
import os

BLACK = C(0x00, 0x00, 0x00)
WHITE = C(0xFF, 0xFF, 0xFF)
ACCENT = C(0x00, 0xE5, 0xA0)
TIER2 = C(0x7C, 0x4D, 0xFF)
WARN = C(0xFF, 0xD9, 0x3D)
RED = C(0xFF, 0x6B, 0x6B)
DIM = C(0x9A, 0x9A, 0x9A)
LINE = C(0x2A, 0x2A, 0x2A)
GLASS = C(0x12, 0x12, 0x12)
GLASS2 = C(0x1B, 0x1B, 0x1B)

FONT = "Segoe UI"
MONO = "Consolas"

prs = Presentation()
prs.slide_width, prs.slide_height = I(13.333), I(7.5)
BLANK = prs.slide_layouts[6]


def slide():
    s = prs.slides.add_slide(BLANK)
    bg = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, prs.slide_width, prs.slide_height)
    bg.fill.solid()
    bg.fill.fore_color.rgb = BLACK
    bg.line.fill.background()
    bg.shadow.inherit = False
    return s


def text(s, x, y, w, h, runs, size=18, color=WHITE, bold=False, align=PP_ALIGN.LEFT,
         font=FONT, spacing=1.15, anchor=MSO_ANCHOR.TOP):
    tb = s.shapes.add_textbox(I(x), I(y), I(w), I(h))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    if isinstance(runs, str):
        runs = [(runs, {})]
    for i, (t, o) in enumerate(runs):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = o.get("align", align)
        p.line_spacing = o.get("spacing", spacing)
        if o.get("space_before"):
            p.space_before = Pt(o["space_before"])
        r = p.add_run()
        r.text = t
        f = r.font
        f.name = o.get("font", font)
        f.size = Pt(o.get("size", size))
        f.bold = o.get("bold", bold)
        f.color.rgb = o.get("color", color)
    return tb


def card(s, x, y, w, h, fill=GLASS, border=LINE, radius=0.06):
    sh = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, I(x), I(y), I(w), I(h))
    sh.fill.solid()
    sh.fill.fore_color.rgb = fill
    sh.line.color.rgb = border
    sh.line.width = Pt(1)
    sh.shadow.inherit = False
    sh.adjustments[0] = radius
    sh.text_frame.word_wrap = True
    return sh


def chip(s, x, y, w, h, label, color=ACCENT, size=11):
    sh = card(s, x, y, w, h, fill=GLASS2, border=color, radius=0.5)
    tf = sh.text_frame
    tf.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf.margin_left = tf.margin_right = 0
    p = tf.paragraphs[0]
    p.alignment = PP_ALIGN.CENTER
    r = p.add_run()
    r.text = label
    r.font.size = Pt(size)
    r.font.bold = True
    r.font.name = FONT
    r.font.color.rgb = color
    return sh


def eyebrow(s, label, n):
    text(s, 0.9, 0.62, 8, 0.3, label.upper(), size=12, color=ACCENT, bold=True)
    text(s, 11.5, 0.62, 0.95, 0.3, "%d / 5" % n, size=11, color=DIM, align=PP_ALIGN.RIGHT)
    rule = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, I(0.9), I(1.72), I(11.55), Pt(1))
    rule.fill.solid()
    rule.fill.fore_color.rgb = LINE
    rule.line.fill.background()
    rule.shadow.inherit = False


def title(s, t, sub=None):
    text(s, 0.9, 0.95, 11.5, 0.6, t, size=34, bold=True)
    if sub:
        text(s, 0.9, 1.92, 11.5, 0.4, sub, size=15, color=DIM)


def arrow(s, x, y, w, h, color=ACCENT, shape=MSO_SHAPE.RIGHT_ARROW):
    a = s.shapes.add_shape(shape, I(x), I(y), I(w), I(h))
    a.fill.solid()
    a.fill.fore_color.rgb = color
    a.line.fill.background()
    a.shadow.inherit = False
    return a


# ---------------------------------------------------------------- 1. TITLE
s = slide()
bar = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, I(0.16), prs.slide_height)
bar.fill.solid()
bar.fill.fore_color.rgb = ACCENT
bar.line.fill.background()
bar.shadow.inherit = False

logo = "C:/projects/candor/assets/icon/new_app_icon.png"
if os.path.exists(logo):
    s.shapes.add_picture(logo, I(0.85), I(1.3), height=I(1.6))

text(s, 0.9, 3.15, 11, 1.0, "CANDOR", size=76, bold=True, spacing=0.9)
text(s, 0.9, 4.25, 11, 0.5, "The assistant that tells you when it's holding back.",
     size=24, color=ACCENT)
text(s, 0.9, 4.95, 9.5, 0.9,
     "A two-tier small-language-model cascade that runs entirely on your phone. "
     "No server, no subscription, no network permission.", size=15, color=DIM, spacing=1.3)

for i, (lab, col) in enumerate([("100% on-device", ACCENT), ("0 network calls", ACCENT),
                                ("109/109 tests pass", TIER2), ("Android \u00b7 Flutter", WARN)]):
    chip(s, 0.9 + i * 2.65, 6.1, 2.4, 0.42, lab, col)

text(s, 0.9, 6.95, 11.5, 0.3,
     "Hackathon 2026   \u00b7   github.com/charansaiponnada/candor   \u00b7   release v0.1.0",
     size=11, color=C(0x66, 0x66, 0x66), font=MONO)

# ------------------------------------------------- 2. PROBLEM -> SOLUTION
s = slide()
eyebrow(s, "The gap", 2)
title(s, "Cloud AI disappears exactly when you need it.",
      "Tunnels, flights, rural coverage, outages, dead plans \u2014 the assistant is gone.")

card(s, 0.9, 2.35, 5.55, 4.1, fill=C(0x14, 0x0B, 0x0B), border=C(0x3A, 0x1E, 0x1E))
text(s, 1.25, 2.62, 4.9, 0.3, "TODAY \u2014 RENTED INTELLIGENCE", size=12, bold=True, color=RED)
text(s, 1.25, 3.15, 4.9, 3.1, [
    ("No network, no assistant.", {"bold": True, "size": 15}),
    ("Every answer is a round-trip to someone else's datacentre.", {"size": 13, "color": DIM}),
    ("Your words leave the device.", {"bold": True, "size": 15, "space_before": 12}),
    ("Prompts travel, get logged, get retained.", {"size": 13, "color": DIM}),
    ("Latency you can feel.", {"bold": True, "size": 15, "space_before": 12}),
    ("Seconds of round-trip on every single turn.", {"size": 13, "color": DIM}),
    ("Metered and rate-limited.", {"bold": True, "size": 15, "space_before": 12}),
    ("Stop paying and the intelligence switches off.", {"size": 13, "color": DIM}),
], spacing=1.15)

arrow(s, 6.62, 4.15, 0.55, 0.5, ACCENT)

card(s, 7.0, 2.35, 5.45, 4.1, fill=C(0x04, 0x16, 0x11), border=C(0x0E, 0x4A, 0x37))
text(s, 7.35, 2.62, 4.8, 0.3, "CANDOR \u2014 OWNED INTELLIGENCE", size=12, bold=True, color=ACCENT)
text(s, 7.35, 3.15, 4.8, 3.1, [
    ("Two models ride in the APK.", {"bold": True, "size": 15}),
    ("Qwen2.5 0.5B + 1.5B, Q4_K_M, run by llama.cpp on the phone.", {"size": 13, "color": DIM}),
    ("Incapable of phoning home.", {"bold": True, "size": 15, "space_before": 12}),
    ("The release manifest declares no INTERNET permission.", {"size": 13, "color": DIM}),
    ("Deterministic skills, zero tokens.", {"bold": True, "size": 15, "space_before": 12}),
    ("Math, units and dates answered exactly, not guessed.", {"size": 13, "color": DIM}),
    ("Honest about its own limits.", {"bold": True, "size": 15, "space_before": 12}),
    ("Every reply names the tier, the confidence, the time.", {"size": 13, "color": DIM}),
], spacing=1.15)

text(s, 0.9, 6.75, 11.55, 0.35,
     "Airplane mode is the demo: chat, calculators, converters, memos, timers and drafts all still work.",
     size=13, color=ACCENT, align=PP_ALIGN.CENTER)

# ------------------------------------------------------- 3. ARCHITECTURE
s = slide()
eyebrow(s, "How it works", 3)
title(s, "One honest router, two tiers, zero packets.",
      "Every query is answered at the cheapest tier that can hold it \u2014 and labelled with which one did.")


def node(x, y, w, h, head, body, col=WHITE, fill=GLASS, bsize=11):
    sh = card(s, x, y, w, h, fill=fill, border=col)
    text(s, x + 0.12, y + 0.16, w - 0.24, 0.3, head, size=13, bold=True, color=col,
         align=PP_ALIGN.CENTER)
    lines = [(t, {"align": PP_ALIGN.CENTER}) for t in body.split("\n")]
    text(s, x + 0.12, y + 0.5, w - 0.24, h - 0.58, lines, size=bsize, color=DIM,
         align=PP_ALIGN.CENTER, spacing=1.1)
    return sh


node(0.9, 3.5, 1.85, 1.15, "USER QUERY", "typed or spoken\n(on-device STT)", ACCENT)
arrow(s, 2.85, 3.94, 0.35, 0.28)

node(3.3, 3.35, 2.0, 1.45, "INTENT MATCH", "regex classifier\nskill / action / model", WARN)

node(5.85, 2.45, 2.5, 1.0, "SKILLS ENGINE", "calculator \u00b7 units \u00b7 dates \u00b7 memo \u00b7 dice",
     WARN, bsize=10)
node(5.85, 3.60, 2.5, 1.0, "PLATFORM ACTIONS", "timer \u00b7 app \u00b7 SMS \u00b7 email \u00b7 settings",
     WARN, bsize=10)
node(5.85, 4.75, 2.5, 1.1, "TIER-1  \u00b7  0.5B", "Qwen2.5 Q4_K_M\nanswers by default", ACCENT)
arrow(s, 5.45, 2.82, 0.3, 0.26, WARN)
arrow(s, 5.45, 3.97, 0.3, 0.26, WARN)
arrow(s, 5.45, 5.17, 0.3, 0.26, ACCENT)

node(8.9, 4.75, 1.9, 1.1, "ROUTER", "conf < 0.7 ?\nempty / refusal ?", ACCENT)
arrow(s, 8.45, 5.17, 0.35, 0.26, ACCENT)

node(11.3, 3.65, 1.6, 1.0, "TIER-2 \u00b7 1.5B", "escalated\nanswer", TIER2, bsize=10)
node(11.3, 5.1, 1.6, 1.0, "CONSTRAINED", "Tier-1 kept\n+ reason", RED, bsize=10)
arrow(s, 10.9, 4.02, 0.3, 0.26, TIER2)
arrow(s, 10.9, 5.47, 0.3, 0.26, RED)

card(s, 8.6, 6.25, 2.5, 0.68, fill=C(0x10, 0x10, 0x18), border=TIER2)
text(s, 8.68, 6.38, 2.34, 0.5, [
    ("DEVICE GATE", {"size": 10.5, "bold": True, "color": TIER2, "align": PP_ALIGN.CENTER}),
    ("battery \u2265 20%  \u00b7  thermal < MODERATE",
     {"size": 9, "color": DIM, "align": PP_ALIGN.CENTER}),
])
arrow(s, 9.72, 5.9, 0.26, 0.3, TIER2, MSO_SHAPE.UP_ARROW)

card(s, 0.9, 5.45, 4.4, 1.48, fill=GLASS2, border=LINE)
text(s, 1.2, 5.66, 3.8, 0.3, "THE OUTPUT CONTRACT", size=11, bold=True, color=ACCENT)
text(s, 1.2, 6.05, 3.9, 0.35, "\u25cf Tier-1 \u00b7 12.4s \u00b7 conf 0.95", size=15, bold=True,
     color=WHITE, font=MONO)
text(s, 1.2, 6.45, 3.9, 0.4,
     "Every answer names its tier, latency and confidence. Escalations append to a JSONL log.",
     size=10.5, color=DIM, spacing=1.15)

# ------------------------------------------------------------- 4. PROOF
s = slide()
eyebrow(s, "Evidence", 4)
title(s, "Proven, not promised.",
      "Everything below is measurable on a mid-range handset in airplane mode, today.")

stats = [("109/109", "automated tests pass\nrouter \u00b7 skills \u00b7 stores \u00b7 settings", ACCENT),
         ("0", "INTERNET permissions\nin the release manifest", ACCENT),
         ("2", "quantized models shipped\n0.5B + 1.5B, Q4_K_M", TIER2),
         ("100%", "offline capability\nno feature needs a network", WARN)]
for i, (big, cap, col) in enumerate(stats):
    x = 0.9 + i * 2.95
    card(s, x, 2.35, 2.7, 1.75)
    text(s, x + 0.22, 2.55, 2.3, 0.7, big, size=38, bold=True, color=col)
    text(s, x + 0.22, 3.35, 2.3, 0.7, cap, size=11, color=DIM, spacing=1.2)

text(s, 0.9, 4.5, 5.6, 0.3, "IN THE BOX", size=12, bold=True, color=ACCENT)
text(s, 0.9, 4.95, 5.6, 2.2, [
    ("Models & Benchmarks \u2014 live load time, tokens/sec and size per bundled model, "
     "measured on this phone.", {}),
    ("Prompt Lab \u2014 per-tier temperature, top-k/top-p and penalty sliders with a live sandbox.",
     {"space_before": 9}),
    ("Skills hub \u2014 every deterministic capability, plus a debug panel that simulates a "
     "constrained device.", {"space_before": 9}),
    ("Chat history, per-tier model pickers, Vulkan GPU toggle, OLED-black glass UI.",
     {"space_before": 9}),
], size=12.5, color=C(0xCC, 0xCC, 0xCC), spacing=1.2)

text(s, 7.0, 4.5, 5.45, 0.3, "THE STACK", size=12, bold=True, color=ACCENT)
rows = [("Flutter / Dart", "single codebase, custom glass widget set"),
        ("llama.cpp via FFI", "llama_flutter_android, no ML framework"),
        ("Qwen2.5 Q4_K_M", "0.5B Tier-1 + 1.5B Tier-2, in the APK"),
        ("MethodChannel", "battery, thermal, model-file prep"),
        ("Vulkan offload", "optional GPU acceleration")]
for i, (k, v) in enumerate(rows):
    y = 4.95 + i * 0.44
    text(s, 7.0, y, 2.4, 0.3, k, size=12, bold=True, color=WHITE)
    text(s, 9.5, y, 2.95, 0.3, v, size=11.5, color=DIM)

# ---------------------------------------------------------- 5. ROADMAP
s = slide()
eyebrow(s, "What's next", 5)
title(s, "Same privacy guarantee, more capability.",
      "The hard part \u2014 offline inference behind an honest router \u2014 already ships.")

items = [("On-device RAG", "Index notes and documents locally. Grounded answers, zero uploads.", ACCENT),
         ("Bigger tiers", "3B and 7B quantized models as phones catch up. Same cascade, smarter answers.", TIER2),
         ("More skills", "Calendar, files and smart-home intents. Deterministic, offline, unhallucinatable.", WARN),
         ("Voice-first", "Faster captioning, wake word and a richer speech UI for hands-free use.", ACCENT),
         ("Play Store", "Ship the release pipeline that already builds the APK today.", TIER2)]
for i, (h, b, col) in enumerate(items):
    x = 0.9 + (i % 3) * 3.93
    y = 2.4 + (i // 3) * 1.55
    card(s, x, y, 3.6, 1.35)
    text(s, x + 0.28, y + 0.22, 3.1, 0.3, h, size=15, bold=True, color=col)
    text(s, x + 0.28, y + 0.62, 3.1, 0.65, b, size=11.5, color=DIM, spacing=1.15)

card(s, 0.9, 5.65, 11.55, 1.3, fill=C(0x04, 0x16, 0x11), border=C(0x0E, 0x4A, 0x37))
text(s, 1.3, 5.95, 10.8, 0.8, [
    ("\u201cAn assistant that knows when to hold back \u2014 and tells you.\u201d",
     {"size": 21, "bold": True, "color": WHITE, "align": PP_ALIGN.CENTER}),
    ("Install the release APK  \u00b7  switch on airplane mode  \u00b7  open a chat  \u00b7  "
     "github.com/charansaiponnada/candor",
     {"size": 12, "color": ACCENT, "align": PP_ALIGN.CENTER, "space_before": 9, "font": MONO}),
])

out = r"C:\projects\candor\docs\pitch\Candor_Pitch.pptx"
prs.save(out)
print("saved", out, os.path.getsize(out))
