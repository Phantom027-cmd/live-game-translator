# Build Prompt: Real-Time Screen Translation Overlay ("Live Game Translator")

> Paste this entire file into Fable (or point Fable at this repository) to start the build.

## Role
Act as a senior systems engineer with experience in low-latency graphics, on-device ML inference (OCR and neural machine translation) across varied hardware, and desktop overlay apps. Design, build, and document a production-quality program from scratch.

## Repository
- All work lives in this GitHub repository: `Phantom027-cmd/live-game-translator`.
- Keep this `PROMPT.md` as the source of truth for requirements. Record design decisions in `docs/ARCHITECTURE.md` and update `README.md` as features land.
- Commit at the end of each phase with a clear message. Never commit models, API keys, caches, logs, or hardware reports that contain machine identifiers.

## Goal
Build a desktop program that:
1. Captures a chosen application window (e.g., a Chinese-language game) continuously.
2. Detects and reads on-screen text (OCR).
3. Translates that text into the user's target language.
4. Displays translations in a transparent, click-through overlay on top of the game, with as little delay as possible.
5. Runs well on a wide range of hardware by detecting the machine it's on and configuring itself automatically.

## User Preferences (defaults, editable in config)
- Source language(s): Simplified Chinese (also support Traditional Chinese, Japanese, Korean)
- Target language: English
- Typical use: game dialogue, menus, UI text, chat

## Primary Development & Test Machine
This is the owner's PC. Use it as the reference machine for the High/Ultra tier, for all latency targets, and as the first row of the hardware test matrix. The program must still auto-detect and support other hardware (see next section); never hardcode these values.

| Component | Detected value |
|---|---|
| OS | Windows 11 Pro 64-bit, build 26200 |
| CPU | AMD Ryzen 9 9950X3D, 16 cores / 32 threads (Zen 5, AVX-512 capable) |
| RAM | 64 GB |
| Discrete GPU | NVIDIA GeForce RTX 5090, 32 GB VRAM, Blackwell (GB202), driver 32.0.16.2101, WDDM 3.2, hardware-accelerated GPU scheduling **on** |
| Integrated GPU | AMD Radeon Graphics (Ryzen iGPU, ~2 GB dedicated), not driving a display, HW scheduling off |
| Hybrid graphics | Supported; game and desktop render on the RTX 5090 |
| Primary display | ASUS PG32UCDM, 3840×2160 @ 240 Hz, DisplayPort, **HDR enabled** (BT.2020 / PQ) |
| Display topology | Extended desktop (DxDiag lists the 5090 output twice; verify whether a second display is attached) |
| DPI scaling | System 150% (144 DPI) |
| Storage | Multiple NVMe SSDs, >1 TB free |

### What this machine means for the design
- **HDR capture is mandatory**: with HDR on, captured frames may be FP16/scRGB or PQ-encoded. Convert to SDR (tone-map) on the GPU before OCR, or OCR accuracy and contrast will suffer. Verify with real HDR game captures, not just SDR test images.
- **HDR-correct overlay**: overlay text and backgrounds must look correct (not washed out or over-bright) on an HDR desktop. Respect the Windows "SDR content brightness" setting.
- **240 Hz refresh**: never run change detection at the full refresh rate. Cap the capture/diff rate (default ~30 Hz, configurable) and stay event-driven.
- **4K at 150% DPI**: be per-monitor DPI aware (v2). Text is large in raw pixels, so test whether downscaling before text detection improves speed without hurting recognition.
- **Blackwell GPU**: confirm every chosen GPU runtime (CUDA, cuDNN, TensorRT, ONNX Runtime build, CTranslate2, llama.cpp) supports Blackwell (sm_120) before committing to it. Older builds may fail or silently fall back to CPU.
- **Hybrid GPUs**: explicitly select the inference adapter (by vendor/VRAM/LUID). Never let DirectML or another runtime default to the wrong GPU. Also benchmark running light OCR on the idle iGPU so the RTX 5090 is left entirely to the game; use it if it meets the latency target.
- **32 GB VRAM**: large enough for a local LLM translator alongside a game, but enforce a configurable VRAM budget (default leaves ample headroom for the game) and check free VRAM before loading models.
- **Strong CPU**: the 16-core X3D CPU makes the CPU fallback path fast; use AVX-512 builds where available and size thread pools from detected cores.

## Hardware Compatibility & Auto-Detection (core requirement)

### Platform scope
- Primary: Windows 10 and 11 (x64).
- Put capture, overlay, hotkeys, and hardware detection behind a platform abstraction layer so Linux (PipeWire/X11/Wayland) and macOS (ScreenCaptureKit) can be added later without touching the pipeline. Linux/macOS implementations are a later phase; confirm scope with me first.

### Startup hardware scan
On first launch, and whenever hardware or drivers change, detect and log:
- OS version and build
- CPU: model, physical/logical cores, instruction sets (AVX2, AVX-512, etc.)
- System RAM: total and available
- Every GPU: vendor (NVIDIA / AMD / Intel / other), model, architecture, VRAM, driver version, integrated vs. discrete, which GPU drives each display
- Available inference runtimes and whether each actually works: TensorRT, CUDA, DirectML, ROCm, OpenVINO, CoreML/Metal, CPU
- Displays: count, resolution, DPI scaling, refresh rate, HDR on/off and color space, which monitor the target window is on

### Hardware tiers
Classify the machine and pick models and settings accordingly. Propose exact thresholds and model choices after benchmarking; these are starting points:

| Tier | Typical hardware | OCR | Translation default | Target latency (new text) |
|---|---|---|---|---|
| Ultra | Discrete GPU, ≥16 GB VRAM (e.g., the dev machine) | Full-size models, FP16, GPU (or iGPU offload) | Local LLM translator with context and glossary, on GPU | ≤250 ms |
| High | Discrete GPU, 8–16 GB VRAM | Full-size models, FP16, GPU | Large NMT model or small LLM on GPU | ≤300 ms |
| Mid | Discrete GPU 4–8 GB, or strong iGPU | Mobile/lite models, FP16 or INT8, GPU | Mid-size NMT model on GPU | ≤600 ms |
| Low | CPU only, or weak iGPU | Lite models, INT8, CPU | Small quantized NMT on CPU, or online API if configured | ≤1.5 s |

- Cache hits must be ≤16 ms on every tier.
- The program must never noticeably reduce game FPS on any tier.

### Execution provider fallback chain
- Try providers in order of expected speed for the detected hardware (e.g., TensorRT → CUDA → DirectML → OpenVINO → CPU).
- Validate each with a warm-up inference before committing. On any init failure, driver error, unsupported GPU architecture, or out-of-memory condition, fall back to the next provider automatically and log why.
- Cache TensorRT engines (or equivalent compiled artifacts) on disk, keyed by GPU, driver, and model version, so start-up stays fast.
- Never crash because a GPU runtime is missing. Degrade gracefully.

### Startup self-benchmark
- On first run, run a short benchmark (a few seconds) on bundled sample images to measure real OCR and translation latency for the candidate configurations (including iGPU-offload options on hybrid systems), then pick the fastest one that meets the accuracy floor.
- Cache results keyed by a hardware fingerprint (GPU model, driver version, CPU, RAM). Re-benchmark only when the fingerprint changes or the user requests it.

### Runtime adaptation
- Monitor per-stage latency, GPU/CPU load, and free VRAM while running.
- If the latency budget is repeatedly exceeded or the system is under heavy load (e.g., the game is GPU-bound), automatically lower the OCR frequency, shrink the capture region, move OCR to another device, or switch to a lighter model. Scale back up when headroom returns.
- Expose the active tier and settings in the debug view.

### User visibility and overrides
- `--hw-report` command and a settings panel that show detected hardware, chosen tier, active execution provider and adapter, selected models, and benchmark results. Reports must not include machine names or hardware IDs unless the user opts in.
- Every automatic choice can be overridden in config (force tier, force provider, force adapter, force model, force CPU-only, VRAM budget).

### Models and packaging
- Ship only the runtime libraries needed. Users must not have to install the CUDA toolkit or developer tools manually.
- The first-run model downloader fetches only the model variants for the detected tier (with checksums), and can fetch other tiers on demand.
- Provide FP32, FP16, and INT8 variants where they help, and document the accuracy cost of each.

## Hard Requirements
- **Performance first**: pick the language and architecture that minimizes latency and overhead across all tiers. Justify the choice (I expect Rust or C++ for the core, but defend whatever you pick). Python is acceptable only for offline tooling such as model conversion, not the runtime hot path.
- **Offline-first**: the default pipeline must run fully offline with local models on every tier. Online translation APIs are optional, pluggable backends, and may be offered as the recommended option on Low-tier machines.
- **Low latency without sacrificing accuracy**: meet the per-tier targets above and report measured numbers, starting with the dev machine.
- **No game process tampering**: no DLL injection, memory reading, or hooking the game. Use only OS-level capture APIs so it works alongside anti-cheat software. Document known limits (exclusive fullscreen, protected content) and the borderless-windowed workaround.
- **Low footprint**: GPU-side capture where available, avoid unnecessary CPU copies, and idle when nothing changes.
- **SDR and HDR**: correct capture, OCR, and overlay rendering on both SDR and HDR desktops.

## Pipeline to Design (research and confirm current best options)
Verify the latest versions and licenses of every library and model before choosing. Do not rely on outdated recommendations.

1. **Window capture**
   - Evaluate Windows Graphics Capture API vs. DXGI Desktop Duplication, with a fallback if the preferred API is unavailable on older builds or certain GPUs.
   - Support selecting a window by title or process, and an optional sub-region (e.g., the dialogue box).
   - Handle resizing, minimizing, DPI scaling, multiple monitors, high refresh rates, HDR pixel formats, and hybrid-GPU systems.

2. **Change detection**
   - Only run OCR when pixels change: frame differencing, tile hashing, or perceptual hashing on regions, computed on the GPU where practical.
   - Detect typewriter-effect text and wait for it to stabilize, with a configurable debounce.
   - Skip OCR entirely when the frame is unchanged.

3. **Text detection + recognition (OCR)**
   - Evaluate PaddleOCR (PP-OCR models exported to ONNX), RapidOCR, Windows.Media.Ocr, and newer CJK-capable models, with variants per tier.
   - Run via ONNX Runtime (or equivalent) using the execution provider chain above.
   - Handle stylized fonts, outlined or shadowed text, low contrast, semi-transparent boxes, vertical text, small UI text, Simplified vs. Traditional.
   - Add preprocessing (HDR tone-mapping, upscaling small text, contrast normalization) only where it measurably helps, and benchmark its cost per tier.
   - Output text boxes with confidence scores, and filter low-confidence results.

4. **Text grouping**
   - Merge OCR lines into logical blocks (dialogue box, menu item, speaker name) before translating, preserving reading order.

5. **Translation (pluggable backend interface)**
   - **Offline**: evaluate Opus-MT/Marian via CTranslate2, NLLB variants, and local LLMs via llama.cpp. Recommend a default per tier plus a "high quality" option where hardware allows.
   - **Online (optional)**: DeepL, Google Cloud Translation, Azure Translator, and an LLM API. API keys in config or the OS credential store, never hardcoded or committed. Timeouts, retries, and automatic fallback to offline.
   - **Caching**: in-memory LRU plus a persistent on-disk cache keyed by normalized source text.
   - **Glossary**: user-editable mappings for names, places, and items, applied consistently.
   - **Context**: pass the previous few dialogue lines to backends that support it.

6. **Overlay rendering**
   - Transparent, always-on-top, click-through window that never steals focus.
   - Display modes: replace (draw over original), tooltip beside text, or a separate movable subtitle panel.
   - Auto-fit font size, readable outline/shadow, configurable font, opacity, and colors.
   - Remove stale translations as soon as the source text disappears.
   - Correct on different DPI scales, refresh rates, and SDR/HDR desktops.

7. **Concurrency model**
   - Separate threads or async stages for capture → change detection → OCR → translate → render, connected by bounded queues.
   - Drop stale frames; newest text always wins.
   - Never block the overlay thread on OCR or translation.
   - Size thread pools from the detected core count.

## Features
- Global hotkeys: toggle overlay, pause/resume, switch display mode, select region, one-shot "translate now", copy last source/translation.
- Modes: continuous auto-translate, region-only, manual snapshot.
- System tray icon with quick settings.
- Config file (TOML or JSON) with hot reload, including hardware overrides.
- Searchable translation history log.
- Diagnostics mode: OCR boxes, confidence, per-stage timing, active tier, provider, and adapter.

## Deliverables
1. **Architecture document** (`docs/ARCHITECTURE.md`): language choice and why, component diagram, data flow, threading model, platform abstraction layer, hardware detection and tiering logic, HDR handling, trade-offs.
2. **Technology comparison table**: OCR and translation options with latency per tier, accuracy, VRAM/RAM use, Blackwell/GPU-runtime support, and license.
3. **Complete, buildable source code** with clean structure and no placeholder stubs in the core pipeline.
4. **Build, install, and run instructions**, including the first-run hardware scan and model download.
5. **Benchmark harness**: per-stage and end-to-end latency on sample game screenshots (SDR and HDR), runnable with any forced tier/provider/adapter.
6. **Hardware test matrix**: the dev machine first, then results (or a documented plan where hardware isn't available) for other NVIDIA, AMD, Intel iGPU, and CPU-only setups, plus a way to simulate each by forcing providers.
7. **Tests**: unit tests for grouping, caching, glossary, backend fallback, tier selection, adapter selection, and provider fallback; integration tests on sample images.
8. **Known limitations and future improvements**.

## Working Process
1. Before coding, list assumptions and ask up to 5 clarifying questions if anything critical is ambiguous.
2. Deliver in phases, each one runnable and committed to this repository:
   - Phase 1: hardware detection + `--hw-report` + capture (SDR and HDR) + change detection + OCR to console, with timings.
   - Phase 2: provider and adapter fallback chain, self-benchmark, tier selection, offline translation, caching, glossary.
   - Phase 3: overlay (HDR-correct), hotkeys, config, runtime adaptation.
   - Phase 4: online backends, history, tray UI, settings panel, packaging, full benchmarks and test matrix.
   - Phase 5 (optional): Linux and macOS support.
3. After each phase, report measured latency on the dev machine and any accuracy issues, and propose fixes before moving on.
4. Prefer correctness and measurable performance over cleverness. If a design choice is a guess, say so and show how to benchmark it.
