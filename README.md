# Ligents

local-first macOS menu bar app for people who juggle multiple AI subscriptions and want to know which profile still has room before they hit the wall

## Why

If you keep separate accounts for work, side projects, clients, or experiments, the annoying part is not the login itself. The annoying part is remembering which profile is close to the limit, which one resets soon, and which session belongs to what.

`Ligents` puts that in one small native app:

- isolated per-provider profile storage
- menu bar dashboard with current usage windows
- browser-based connect flow
- local notifications when a limit is low, exhausted, or about to reset

The scope is intentionally narrow: local-first macOS utility, no backend, no cloud sync, and no attempt to become a control plane.

## Quick Start

```bash
swift build
./script/build_and_run.sh
```

When the app opens:

1. Open `Settings`.
2. Add a profile.
3. Connect the Codex profile in the browser.
4. Come back to the menu bar and check the current windows there.

Useful run modes while working on it:

```bash
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --verify
```

## Current State

| Status | Area | What works now | What is next |
| --- | --- | --- | --- |
| In progress | Menu bar app | native SwiftUI `MenuBarExtra`, settings window, usage window, diagnostics surface | tighten the UX and remove more scaffold-only edges |
| In progress | Profiles | isolated local profile directories, editable metadata, local JSON persistence | make profile lifecycle and troubleshooting less rough |
| In progress | Codex path | isolated `CODEX_HOME`, managed OAuth bootstrap, account read, rate-limit read through a local `codex` runtime | harden auth lifecycle and background refresh behavior |
| In progress | Alerts | editable per-profile rules, local notifications, dedup state | tune defaults and reduce noisy alerting |
| Gated | Claude path | isolated `CLAUDE_CONFIG_DIR` groundwork and placeholder profile model | enable only after there is a stable supported usage source |

## Notes

- macOS 14+ target
- no third-party dependencies right now
- the build script creates `dist/Ligents.app` and launches it as a regular macOS app bundle
- Codex support expects an existing local `codex` executable
- provider names and logos are used for identification only; this project is not affiliated with OpenAI, Anthropic, or other providers

## License

Apache-2.0.

Copyright 2026 Ligents contributors.
See `LICENSE` and `NOTICE`.

(openai pls dont sue me)
