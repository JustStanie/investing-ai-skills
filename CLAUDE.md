# Claude Code — Finance AI Skills

@AGENTS.md

Follow the shared repository instructions above. For relevant finance/investing requests, apply the default coordinator at `.agents/skills/finance-skill-router/SKILL.md` and read the relevant specialist Skills.

Project Skills are made available to Claude Code via `.claude/skills/` when the Windows junction is configured, pointing to the canonical `.agents/skills/` directory. If native discovery through a junction does not work in your version, read the canonical files directly; do not claim `/skill-name` is registered until verified.

Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-skills.ps1` in the repository root after extracting or cloning to configure the local junction. Do not install Skills globally. Default to consultation, without editing files unless requested.

To explicitly invoke the coordinator, enter `/finance-skill-router` if it is registered in Claude Code. Otherwise ask a normal finance question: the shared repository instructions still direct you to read the coordinator file.
