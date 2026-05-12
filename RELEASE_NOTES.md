# Release Notes

## 2026-05-12.8

- Mac installer only.
- Downloads the full install package from GitHub Releases.
- Keeps the visible terminal install flow and writes logs under `~/Downloads/Agent-Obsidian-install-logs`.
- Uses `~/Desktop/CodePilot/Bridge` and `~/Desktop/CodePilot/Obsidian` as the default local workspace layout.
- Fixes Claude Code CLI PATH by using user-level npm prefix `~/.local` and verifying `claude` after installation.
- Refreshes the managed `CLAUDE.md` default knowledge-base block on rerun.

