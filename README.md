# candor
An Android app that runs a two-tier quantized language model cascade fully offline. A small model (Tier-1) answers by default; a larger model (Tier-2) is used only when the query seems to need it AND the device has resource headroom. The app explicitly tells the user which tier answered and why, rather than silently switching.
