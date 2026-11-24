# Notes for agents working in this repo

## Layout

- `.claude-plugin/marketplace.json` — the catalog ZCode reads from a GitHub or directory source. One entry per plugin directory under `plugins/`.
- `plugins/<name>/` — a ZCode plugin: `.zcode-plugin/plugin.json` plus only the components it declares.
- `README.md` and `README.zh.md` — English and Chinese versions of the same content; keep them in sync.

## Rules

- The directory name must match the manifest `name`, and each catalog entry's `name`/`version` must match its `plugin.json`.
- Bump the plugin `version` on behavior changes, and update both READMEs in the same commit.
- The Windows badge patch is version-specific. `scripts/taskbar-dot.ps1` must keep failing closed: unique anchor, exactly one candidate, code-shape check, post-write verification, and no write when any check fails.
- Never commit a modified `app.asar`, a backup copy of one, or machine-specific absolute paths.
