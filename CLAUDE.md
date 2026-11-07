# Project instructions

- Requirements live in `PROMPT.md`. Read it in full before starting any work and treat it as the source of truth.
- Build in the phases defined there. Commit at the end of each phase.
- The owner's PC (RTX 5090, Ryzen 9 9950X3D, 4K 240 Hz HDR display at 150% DPI) is the reference machine for latency targets. Never hardcode its specs; the program must auto-detect hardware.
- Never commit models, API keys, caches, logs, or hardware reports containing machine identifiers (see `.gitignore`).
- Record design decisions in `docs/ARCHITECTURE.md`.
