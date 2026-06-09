English | **[한국어](README.md)**

# claude-code-template

A starting point for Claude Code projects. Pick a profile, copy it into a new project, and start
building — the sub-agent setup works on day one.

## The core idea

Keep the **master session on a single model** and let it do orchestration only — interpreting intent,
routing work, and synthesizing results. Delegate the actual work to **sub-agents** whose model and
role fit the task. This keeps the master's context (and prompt cache) stable while letting each piece
of work run on the right-sized model:

- **Irreversible / hard reasoning** (architecture, tricky concurrency bugs, security-critical review)
  → an Opus sub-agent.
- **Everyday execution** (feature work to a clear spec, refactors, tests, docs) → a Sonnet sub-agent.
- **High-volume / simple** (codebase exploration, search, extraction) → a Haiku sub-agent.

Sub-agents run in isolated context windows and return only summaries, so a long grep dump or build log
never bloats the master. Model diversity is expressed through each sub-agent's `model` field — never by
switching `/model` inside the master (which would split and invalidate the prompt cache).

## What's inside

- **`profiles/lite/`** — a 3-agent lightweight setup (explorer, implementer, test-writer) for small or
  short-lived projects. Copy-ready.
- **`profiles/standard/`** — the full 8-agent setup plus routing skills, for projects that live longer
  or carry domain/security/concurrency risk. Copy-ready.
- **`HANDBOOK.md`** — the single source of truth: why the master/sub-agent split works, a
  cost-efficiency matrix by task type, the 8-agent blueprint, daily workflows, cost levers, and
  pitfalls.
- **`docs/`** — profile-selection criteria, bootstrap prompts, and a maintenance guide.

## Quick start

```bash
cd ~/development/new-project
cp -r ~/development/claude-code-template/profiles/standard/. .
# or the lite setup:
# cp -r ~/development/claude-code-template/profiles/lite/. .
```

The `profiles/` directories are pre-baked bootstrap output — copy them and `.claude/` works
immediately, with no Opus bootstrap call needed. (To customize or regenerate from scratch, paste a
prompt from `docs/bootstrap-prompts/` into a fresh Claude Code session instead.)

## Choosing a profile

Start **lite** for single-cycle, small (≲1,000 LOC or ≤5 core files), UI/integration-heavy, or
solo work. Choose **standard** when the project will live 6+ months, has thick domain logic, touches
security/concurrency/data-integrity, serves external users, or has 2+ collaborators. When unsure, two
questions decide it: *"Does this need to keep running 6 months from now?"* and *"Does a bug here cost
someone else?"* — a Yes to either points to standard.

Full criteria, edge cases, and the lite → standard promotion recipe are in
[`docs/profile-selection.md`](docs/profile-selection.md).

## A note on language

The reference docs (`HANDBOOK.md`, `docs/`) are written in **Korean** and are pinned to the current
Claude model tiers and pricing. The agent and skill **routing `description` fields are already in
English**, so the profiles route correctly regardless of the language you prompt in. Everything here is
easy to adapt — paste the Korean docs into Claude to translate them or tailor them to your stack.

For the current template version and the latest model/pricing details, see the
[Korean README](README.md) and [`CHANGELOG.md`](CHANGELOG.md).

## License

This template was written for personal use. Fork and modify freely.
