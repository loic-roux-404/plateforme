---
name: skill-search
description: >
  Search, retrieve, and install Agent Skills using the `skills` CLI (npx),
  GitHub MCP search patterns, and web fallbacks — no registry MCP server
  required. Use when the user asks to find skills, browse skill catalogs,
  install a skill for an agent, or extend capabilities with reusable skills.
---

# Skill Search

Locate and install reusable Agent Skills without depending on a registry MCP server.

## Workflow

1. **Search with the `skills` CLI** (primary):
   - `npx skills find <query>` — interactive search across GitHub-hosted skills; add `--owner <org>` to scope. In non-interactive runs, prefer `add -l` or GitHub search below.
   - `npx skills add <owner/repo> -l` — list skills inside a known package without installing.
2. **Backup: GitHub MCP** — `github_text_search` with `filename:SKILL.md <keyword>`, optionally scoped (`path:.agents/skills`, `path:.claude/skills`, `path:skills`); or browse curated repos (`vercel-labs/agent-skills`, `anthropics/skills`, `github/awesome-copilot`).
3. **Fallback: web/browser** — fetch awesome lists and registries; verify license and compatibility with the project's conventions.

Present results with: skill name, source repo, description, file list, category.

## How to Install

Use the CLI so `skills-lock.json` stays authoritative:

```bash
npx skills add <owner/repo> -s <skill> -a '*' -y   # install one skill for all agents
npx skills add <owner/repo> -a '*' -y              # install a whole package
npx skills list                                    # verify installation
```

- `-a <agent>` targets one agent; `'*'` installs for all.
- After install, read back `SKILL.md` and confirm the frontmatter is intact.
- If the user prefers a hand-written skill, create `.agents/skills/<name>/SKILL.md` and keep it generic/portable — concrete project layout belongs in `AGENTS.md`, not in the skill.

## Guidelines

- Always search before suggesting writing a skill from scratch.
- Respect `skills-lock.json` — install through the CLI, never by manual copy.
- Confirm what the skill does and when it activates.
- Check the license before adopting community skills.
