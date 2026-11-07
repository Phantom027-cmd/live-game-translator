# Live Game Translator

A real-time screen translation overlay for games and other applications. It captures a chosen window, reads on-screen text with OCR, translates it, and draws the translation in a transparent overlay on top of the game.

> **Status:** planning. No code yet. The full build specification is in [`PROMPT.md`](PROMPT.md).

## Planned features
- **Offline-first**: local OCR and translation models, with optional online APIs (DeepL, Google, Azure, LLM APIs).
- **Low latency**: change detection, caching, and GPU inference to keep translation delay as small as possible.
- **Hardware-aware**: detects CPU, GPU, VRAM, runtimes, and displays at startup, benchmarks itself, and picks the fastest configuration.
- **Anti-cheat friendly**: uses only OS screen-capture APIs. No injection, hooking, or memory reading.
- **SDR and HDR**: correct capture and overlay rendering on HDR desktops.
- **Glossary and history**: consistent names and terms, plus a searchable log of past translations.

## Getting started with the build
1. Open [`PROMPT.md`](PROMPT.md).
2. Give it to Fable (paste it, or point Fable at this repository).
3. Fable works in phases and commits each phase here.

## Planned layout
| Path | Purpose |
|---|---|
| `PROMPT.md` | Requirements and build specification (source of truth) |
| `docs/ARCHITECTURE.md` | Design decisions, created in Phase 1 |
| `src/` | Application source |
| `bench/` | Benchmark harness and sample screenshots |
| `models/` | Downloaded models (not committed) |

## Notes
- Run games in **borderless windowed** mode; window capture often can't see exclusive fullscreen.
- Never commit API keys, models, caches, or raw `DxDiag.txt` reports (they contain machine identifiers).
