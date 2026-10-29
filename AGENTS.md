# Agent instructions

This repository holds runnable examples for runkora and a quickstart that installs kora on a local k3d cluster.

- **Quickstart:** When asked to set up, install or demo runkora, follow `.agents/skills/runkora-quickstart/SKILL.md`. Claude Code reads it through `.claude/skills`, a link to `.agents/skills`.
- **Source of truth:** `quickstart/README.md` and each example's README hold the detail. Where the skill and a README disagree, follow the README.
- **Manifests:** Run `make validate` after changing a manifest. CI runs the same check on every pull request.
