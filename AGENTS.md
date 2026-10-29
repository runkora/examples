# Agent instructions

This repository holds runnable examples for runkora and a quickstart that installs kora on a local k3d cluster.

*   **Quickstart:** When a person asks you to set up, install or demo runkora, follow `.claude/skills/runkora-quickstart/SKILL.md` from step 1. The file is a Claude Code skill, and any coding agent can follow it.
*   **Source of truth:** `quickstart/README.md` and each example's README hold the detail. If the skill and a README disagree, follow the README.
*   **Manifest changes:** After you change a manifest, run `make validate`. CI runs the same check on every pull request.
