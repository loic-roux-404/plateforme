---
name: prompt-search
description: >
  Find, retrieve, and improve AI prompt templates using GitHub MCP search
  patterns and web fallbacks — no registry MCP server required. Use when the
  user asks about prompt templates, wants to search prompts, or improve a
  prompt.
---

# Prompt Search

Locate prompt templates and prompt libraries using GitHub search and the web.

## Workflow

1. **GitHub MCP** (primary — there is no dedicated CLI for prompts):
   - `github_text_search` with `path:prompts extension:md <keyword>`, scoped to repos with prompt dirs (`github/awesome-copilot`, `f/prompts.chat`, or relevant orgs).
   - Browse curated prompt collections directly and pull raw files.
2. **Web/browser fallback**: fetch prompts.chat or awesome lists; present title, description, author, category, and link.

## How to Retrieve / Improve

- Fetch the raw file (GitHub MCP or `web`) and check for variables (`${variable}` / `${variable:default}`) — ask the user for values when present.
- Improve a prompt by rewriting while preserving intent; explain what was enhanced.
- Install by saving as `.prompt.md` in the workspace prompts dir (team-shared) or the user prompts folder (personal); keep it parameterized and generic.

## Guidelines

- Always search before writing a prompt from scratch.
- Show readable results with links and categories.
- When improving, explain what was enhanced.
- Suggest relevant categories/tags when saving.
