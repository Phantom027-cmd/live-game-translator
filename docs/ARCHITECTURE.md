# Architecture

Design decisions for Live Game Translator. `PROMPT.md` remains the source of truth for requirements; this file records how those requirements are being met and why.

> Status: pre-Phase-1. Sections marked *TBD* are filled in as each phase lands.

## Decisions agreed with the owner (2026-11-07)

These answers resolve the clarifying questions asked before coding began.

| Topic | Decision |
|---|---|
| Build and test loop | Development runs from a Claude Code session on the owner's PC (RTX 5090 / Ryzen 9 9950X3D), so every phase is built, run, and benchmarked on the reference machine directly. |
| Repository access | Each phase is committed and pushed to `Phantom027-cmd/live-game-translator`. |
| Target games | Any game, regardless of font or art style, with **retro / pixel-art games as the primary case**. OCR evaluation must therefore include bitmap fonts, low-resolution text that has been integer-upscaled, and limited color palettes, not just modern anti-aliased UI text. |
| Sample images | None supplied up front. The on-PC session captures samples directly from the owner's games during Phase 1 and stores them under `bench/samples/` (SDR and HDR). |
| Displays | Two identical ASUS PG32UCDM monitors (3840x2160 @ 240 Hz, HDR-capable), one at 150% DPI scaling and one at 100%. The game may run on either. The program must work at **any resolution, refresh rate, and DPI scale**, and must handle the target window moving between monitors with different scale factors. |
| Ultra-tier translator | Offer **both** options, selectable in config: (a) *quality* — the largest instruct LLM that fits the VRAM budget; (b) *light* — a smaller model that leaves more headroom for the game. The self-benchmark reports latency for each so the owner can choose. |
| VRAM budget | Default reserves **12 GB of free VRAM** for the game. Models are loaded only if free VRAM minus their footprint stays above this reserve. Configurable. |

## Language and runtime choice

*TBD in Phase 1.* Working assumption: Rust for the core (capture, change detection, pipeline, overlay, hardware detection), with Python used only for offline model conversion tooling. The justification, with alternatives considered, is written here once Phase 1 code exists.

## Component diagram and data flow

*TBD in Phase 1.*

## Threading model

*TBD in Phase 1.*

## Platform abstraction layer

*TBD in Phase 1.* Windows 10/11 x64 is the only implemented platform through Phase 4; capture, overlay, hotkeys, and hardware detection sit behind traits so Linux and macOS can be added in Phase 5.

## Hardware detection and tiering

*TBD in Phase 1 (detection) and Phase 2 (tiering and self-benchmark).*

## HDR handling

*TBD in Phase 1 (capture and tone-mapping) and Phase 3 (overlay).*

## Trade-offs and open questions

- Retro games: test whether running OCR at the game's native (pre-upscale) resolution, when it can be inferred, beats OCR on the full 4K frame for both speed and accuracy on bitmap fonts.
- Mixed-DPI monitors: confirm that Windows Graphics Capture returns frames in physical pixels regardless of the per-monitor scale, and that overlay coordinates are converted per monitor.
