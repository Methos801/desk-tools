# Lane: GitHub Copilot agents, skills, and plugins (VS Code and the Copilot app)

Added when this skill was ported into the `desk-tools` Copilot plugin. Read it for any port to, or change of, a Copilot `.agent.md`, `SKILL.md`, prompt file, or plugin. It supplements `target-lanes.md`; it does not replace any control there.

## What loads, and how

| Artifact | Loaded as | Trust |
|---|---|---|
| `.agent.md` body | Always-on instructions for the whole session once the user picks the agent | Enforced instruction |
| Agent `tools:` list | Hard tool restriction (no list = every tool) | Enforced by the runtime |
| `SKILL.md` name + description | Always visible to the model for triggering | Metadata only |
| `SKILL.md` body | Loaded when invoked (slash command) or when the model decides it is relevant | Enforced instruction once loaded — but loading can be skipped |
| Skill `references/`, `scripts/` | Read on demand | Read as instruction when read; scripts run deterministically |
| `.github/copilot-instructions.md`, `*.instructions.md` | Always-on (or by `applyTo` glob) in that workspace | Enforced instruction, workspace-scoped |
| Plugin hooks (`com.github.copilot/hooks/hooks.json`) | Runtime commands on lifecycle events | Deterministic; outside the model |

**Trust shift to watch:** a control that lives only in a skill body is advisory until the skill is loaded, and a model can fail to load it. Any hard stop that must always hold belongs in the agent body (always on), in the `tools:` list, or in a hook — not only in a skill.

## Frontmatter facts (check every candidate)

- Top-level keys only. Nested `agent:` or `skill:` blocks are not read by any Copilot surface.
- Agent: `description` required. `tools` restricts; omitting it grants all tools. Recognized keys include `name`, `description`, `argument-hint`, `tools`, `agents`, `model`, `user-invocable`, `disable-model-invocation`, `target`, `handoffs`, `hooks` (preview, VS Code only), `mcp-servers` and `metadata` (not used by IDE agents).
- Skill: `name` required, must equal the folder name, lowercase letters/digits/hyphens, at most 64 characters, no namespace prefix. `description` required, at most 1,024 characters. Optional: `argument-hint`, `user-invocable`, `disable-model-invocation`, `context: fork` (experimental), plus the portable `license`, `compatibility`, `metadata`, `allowed-tools`.
- A skill that an agent depends on must stay model-invocable (`disable-model-invocation` false), or the agent cannot load it.
- Agent body cap: 30,000 characters. For agents meant for a 32K local model, keep the body under about 6,000 characters; Copilot's own system prompt and tool definitions take a large share of the window before your instructions load.

## Surface differences

| Feature | VS Code | Copilot app / CLI |
|---|---|---|
| Handoff buttons (`handoffs`) | Yes | Not confirmed; design so the workflow still works without them |
| `argument-hint` | Yes | Not confirmed; harmless if ignored |
| Per-agent `model` | Yes (string or ordered list) | One model provider per session; do not rely on per-agent routing |
| Agent-scoped `hooks` | Preview, Local harness only | No |
| Plugin hooks | Yes | Yes (Copilot hook format: `version: 1`, camelCase events) |
| Skill `context: fork` | Experimental | Not confirmed |

## Placement rules

- Put the two or three rules that must never be broken at both the top and the bottom of an agent body.
- Never save a draft in a folder a surface loads from (`.github/agents/`, `.github/skills/`, `.github/prompts/`, `.github/instructions/`, `.claude/`, `.agents/`, `~/.copilot/`, a plugin's `skills/` or `com.github.copilot/`). A draft there is live. Name agent drafts `<name>.agent.candidate.md` so no surface treats them as agents.
- Deterministic work (counting, validation, reconciliation, format checks) belongs in a bundled script, not in prose the model must follow perfectly.

## Porting a Claude skill to Copilot

Agent Skills is a shared open format, so a Claude skill folder usually ports **unchanged**. The port work is:

1. Confirm the frontmatter keys are valid on Copilot (they usually are) and the description is under 1,024 characters.
2. Find anything that assumes a Claude-only tool or connector (for example M365 search, artifacts, Drive) and decide how it maps to the Copilot session's tools; record each mapping in the no-loss table.
3. Write a thin Copilot agent wrapper that pins the tool list, restates the always-on hard stops at top and bottom, and loads the skill. Keep the skill body verbatim so the no-loss audit covers only the wrapper.
4. If the skill cannot be committed (proprietary or client material), install it at the user level (`~/.copilot/skills/<name>/`) instead of in the plugin, and make the wrapper stop if the skill is missing.
