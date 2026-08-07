---
name: agent-designer
description: "Create and iterate on VS Code custom agents (.agent.md) for this repo. Use when building a new subagent, refining an existing agent, deciding between agent vs instructions vs skill, adding debug playbooks / constraints / toolings, making an agent portable across projects, or moving repo-specific details into AGENTS.md."
argument-hint: "Describe the agent you want to build or the customization pain point (e.g. agent hallucinating file layout, missing debug steps, tools too broad)..."
---

# Agent Designer

Design effective **custom agents** (`.agent.md`) by iterating with the requester. Focus on *agent behavior*, not on a specific technology. Use this skill whenever the user wants a new subagent, wants to fix hallucination/context-loss in an existing agent, or wants to make an agent reusable in another project.

## Core principles

1. **Single role** — one persona with focused responsibilities per agent.
2. **Minimal tools** — only include what the role needs; excess tools dilute focus.
3. **Clear boundaries** — define what the agent should NOT do.
4. **Generic landscape, concrete in AGENTS.md** — the agent file should explain *what kind of code* lives in each logical area (e.g. `flake.nix`, `modules/`, `lib/`, `secrets/`) without hardcoding project-specific file names or option values. The concrete layout belongs to `AGENTS.md`.
5. **Keywords for discovery** — the `description` field is the discovery surface; include trigger phrases so parent agents know when to delegate.

## Workflow

### 1. Extract intent from the conversation

Look for how the user has been steering the assistant:
- Specialized role/persona (e.g. “Nix maintainer”, “Terragrunt operator”, “PR reviewer”)
- Tool preferences (which to use, which to avoid)
- Domain or job scope (files, systems, or decisions the agent should own)
- Pain points (hallucinating paths, losing track of folder purpose, over-scoping)

Generalize these into a custom agent.

### 2. Choose the right primitive

| Need | Primitive | Why |
|------|-----------|-----|
| Always-on project conventions | `AGENTS.md` / `copilot-instructions.md` | Applies everywhere, no discovery cost |
| File-type scoped guidance | `*.instructions.md` with `applyTo` | Loaded only for matching files |
| Single parameterized task | `*.prompt.md` | Slash command with inputs |
| On-demand workflow with assets | `SKILL.md` | Progressive loading, scripts, references |
| Context isolation / role-based tools | `.agent.md` (custom agent) | Subagent returns one summary, tool restrictions |
| Deterministic enforcement | Hooks | Block/validate via shell commands |

### 3. Determine scope

Ask where the customization should live:
- **Workspace**: `.github/agents/` or `.agents/skills/` (team-shared, version-controlled)
- **User profile**: `{{VSCODE_USER_PROMPTS_FOLDER}}/` (personal, roams with settings)

### 4. Draft the agent file

Template:

```markdown
---
description: "Use when: <trigger phrases with keywords>"
name: "<Agent Name>"
argument-hint: "<short input guidance>"
tools: [read, search, edit, execute, web, todo]   # minimal set
---

You are a <role> specialised in <domain>. Your job is to <clear purpose>.

## Repo landscape — technology per area

> **Note**: For the concrete file layout of this project, consult `AGENTS.md`.
> The section below is generic to any <stack> repo and tells the agent what
> *kind* of code lives in each logical area.

### `flake.nix` — project entry point
- **Inputs**: package sets, system frameworks, utility flakes.
- **Outputs**: `nixosConfigurations`, `darwinConfigurations`, `devShells`, `overlays`, `lib` helpers.
- **Package policy**: pin a primary package set; use overlays only when a specific version is needed.

### `modules/` — system modules
Contains platform-only configuration modules: base OS settings, services, image-format modules, environment-specific modules, and deployment modules that wire runtime secrets.

### `lib/` — flake-local helpers
Pure helper functions or builders (not modules). Imported in `flake.nix` under `lib`.

### `secrets/` — encrypted secrets
Per-scope secret files. Never edit directly; use the secrets tooling. Access values via the secrets integration so plaintext does not enter the build/store.

## Tooling
- List the exact tools the agent has and how to invoke them.
- Mention whether a formatter/formatter output is wired (e.g. `nix fmt` vs `nixfmt`).

## Documentation References (fetch with `web` when unsure)
| Topic | URL |
|-------|-----|
| Official manual | https://... |
| Options search | https://... |
| Package index | https://... |

## Debug playbook
```bash
# Cheapest first: evaluate → build → full check
<eval command>
<build command>
<check command>
```

## Constraints
- DO NOT <dangerous/expensive operation> unless explicitly asked.
- DO NOT <edit secrets directly> / <bypass review>.
- DO follow repo conventions: <format, validation, layering>.
- ALWAYS format edited files and validate when feasible.

## Approach
1. Read the relevant config to understand current state.
2. Reproduce/debug with the cheapest command first.
3. Consult documentation for exact names/formats when in doubt.
4. Apply minimal edits, format, and validate.

## Output Format
Report what was wrong/changed, commands run, and validation status.
```

### 5. Identify weak or ambiguous parts

Ask about:
- Missing tooling behavior (formatter not wired? LSP name? validation command?)
- Areas where the agent might hallucinate (file layout, module roles, secret flow)
- Over-scoped tools or vague constraints
- Whether project-specific names should be moved to `AGENTS.md`

### 6. Iterate

1. Apply the refinement.
2. Re-read the file to ensure no duplicate sections or stale project-specific details.
3. Repeat until the requester is satisfied.

### 7. Validate and summarize

- Confirm the file is at the right path (`.github/agents/<name>.agent.md` or `.agents/skills/<name>/SKILL.md`).
- Verify YAML frontmatter syntax (`---` markers, quoted `description`, `name` matches folder/filename).
- Summarize what the agent does.
- Suggest 3–5 example prompts to try it.
- Propose related customizations (e.g. instructions for a file type, a hook for formatting, a skill for a workflow).

## Demands checklist (from past iterations)

When the user says any of the following, apply the associated change:

| Demand | What to do |
|--------|------------|
| “Be clearer while defining work in each folder” | Replace vague folder descriptions with per-folder technology/purpose breakdown. Mention what each folder *is for*, not just its path. |
| “Consider nix-lib / shared options / SOPS usage” | Add a `Repo landscape` section explaining helpers (`lib/`), shared option namespaces, and secret scopes (Darwin/home-manager vs NixOS runtime). |
| “Avoid hallucination and losing himself in folders” | Add a note that concrete file layout lives in `AGENTS.md`; the agent file should describe the *kind* of code per area. |
| “Be more generic / portable to another project” | Remove hardcoded output names, option paths, and tool names from the landscape; keep patterns. Move project-specific examples into `AGENTS.md`. |
| “Learn every useful debug command” | Add a `Debug playbook` with cheapest-first commands (eval → build → check), partial evaluation, option lookup, and store analysis. |
| “Mind presence of nil lsp and nixfmt” | Add a `Tooling` section listing exact tools, how to check availability, and whether a formatter output is wired. |
| “Should have access to browser and docs” | Ensure `tools: [..., web, ...]` and add a `Documentation References` table with official manual, options search, and package index URLs. |
| “Not technologies scoped / focus on agent behaviour” | Generalize role, constraints, and playbook so they describe *how* the agent works rather than *what* technology it touches. |

## Example: demands → agent changes

### Demand
> “The agents should have access to browser and should have the list of every relevant documentation for nix flake; darwin, nix tools like shell, dependencies index and nix os docs.”

### Change applied
- Added `web` to `tools`.
- Added a `Documentation References` table with Nix manual, flakes, nix shell, store, nix-darwin manual, NixOS options search, nixpkgs package search, nixpkgs manual, home-manager options, nixos-generators, srvos, sops-nix, nil, nixfmt.

### Demand
> “The agents should know every useful commands to debug nix in the common encountered development situation. goal can be to evalutate derivation, search nix store, analyse nix code, evaluate part of flake independently, check available option...”

### Change applied
- Added a `Debug Playbook` with sections for:
  - Evaluating derivations / flake parts independently (`nix eval`, `nix repl`, `--expr`)
  - Checking available options (`nix eval .#...options.<name>.description`, `jq 'keys'`)
  - Searching / analysing store (`nix flake show`, `nix search`, `path-info`, `why-depends`, `store ls`, `derivation show`)
  - Build / common failure triage (`nix build`, `nix develop`, `nix flake check`, `--show-trace`, cross-compile note)

### Demand
> “Also mind presence of nil lsp and nix-fmt”

### Change applied
- Added a `Tooling: nil LSP + nixfmt` section stating where the tools are installed, how `nil` is registered as an LSP, and that `nix fmt` is not wired because there is no `formatter` output.

### Demand
> “please be clearer while defining your work in each folder. here you might not consider nix-lib used in flake for make system helpers / nixos-options shared option between darwin and nix os built qcow and you're not mentionning sops usage in darwin and other usage in nix os machines.”

### Change applied
- Rewrote the landscape into explicit per-folder breakdowns: `flake.nix`, `nixos/`, `nixos-darwin/`, `nixos-options/`, `nix-lib/`, `nix-flake/`, `secrets/`.
- Added a `SOPS usage patterns` section mapping Darwin/home-manager scope vs NixOS runtime scope, key sources, and consumers.
- Added the rule that decrypted values are never written to the Nix store.

### Demand
> “lets now be more generic on the section repo landscape, it should be the role of AGENTS.md to detail file structure, keep only whats related to tech used per folder. Goal is if i move the agent definition in another project this one using it doesnt get lost.”

### Change applied
- Added a note: “For the concrete file layout of this project, consult `AGENTS.md`. The section below is generic to any Nix/NixOS/nix-darwin repo...”
- Replaced hardcoded file names and option examples with technology-level descriptions (e.g. “package sets”, “system frameworks”, “image-format modules”, “deployment modules that wire runtime secrets”).
- Generalized SOPS usage into patterns rather than concrete `darwin.yaml` / `deploy.nix` references.

## Anti-patterns to avoid

- **Vague `description`** — “A helpful agent” won’t be discovered.
- **Hardcoding project paths** — the agent breaks when moved to another repo; put layout in `AGENTS.md`.
- **Swiss-army tools** — giving every tool to every agent dilutes focus.
- **Monolithic SKILL.md** — keep the skill file under ~500 lines; use reference files for long templates.
- **Missing procedures** — a description without step-by-step guidance is not actionable.
- **Duplicate sections** — after edits, re-read the file to remove stale blocks.

## Related references

- Agent reference: [agents.md](../references/agents.md) (VS Code built-in)
- Skill reference: [skills.md](../references/skills.md) (VS Code built-in)
- Prompt reference: [prompts.md](../references/prompts.md) (VS Code built-in)
- Instructions reference: [instructions.md](../references/instructions.md) (VS Code built-in)
