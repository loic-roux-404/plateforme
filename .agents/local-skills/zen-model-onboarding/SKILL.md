---
name: zen-model-onboarding
description: >
  Onboard a newly released OpenCode Zen model into this repo's local AI stack.
  Discovers the live catalog with curl, probes each id for the capabilities the
  clients actually need (chat-completions, tool calling, Responses API), picks a
  Claude Code tier (frontier / workhorse / subagent), then wires the model into
  litellm.nix, claude-code.nix, crush.nix and vscode-agent.nix.
  Use when a new Zen model appears, when `make gateway`/chat fails with
  "model not found" or "ModelProtocolUnsupported", when a model in
  vscode-agent.nix stops answering, or when re-tiering Claude Code aliases.
metadata:
  version: "1.0.0"
  domain: ai-stack
  triggers: >
    opencode zen, zen model, new model, model catalog, litellm, model_list,
    zenModels, ANTHROPIC_DEFAULT_OPUS_MODEL, ANTHROPIC_DEFAULT_SONNET_MODEL,
    ANTHROPIC_DEFAULT_HAIKU_MODEL, CLAUDE_CODE_SUBAGENT_MODEL, crush provider,
    chatLanguageModels.json, ModelProtocolUnsupported, model tier, opusplan
  role: ai-platform-engineer
  scope: implementation
  output-format: commands
---

# OpenCode Zen Model Onboarding

The stack routes every client through one local LiteLLM gateway
([litellm.nix](../../../../nixos-darwin/litellm.nix)) fronting OpenCode Zen and the
Z.ai GLM coding plan. Adding a model means: **probe it**, **tier it**, **wire it in
four places**.

Never guess a model's capabilities from its name. The catalog and per-model
protocol support change without notice.

## Golden rule: discover with curl, never from a hardcoded list

There are **two** catalogs, and they disagree. Check both before concluding a model
does not exist:

```bash
curl -s https://opencode.ai/zen/go/v1/models   # Go plan — what this repo can use (~37)
curl -s https://opencode.ai/zen/v1/models      # full catalog (~85)
```

A model listed only in the full catalog is usually **not reachable** here: it is absent
from the Go plan and/or speaks only `/v1/responses`. Verified example —
`muse-wonder-1.0` appears in the full catalog but answers `Model is unavailable` on
`/zen/go/v1` and `ModelProtocolUnsupported` on every chat endpoint, on both bases. Do
not add a model just because the full catalog lists it; probe it against `/zen/go/v1`.

The bundled [zen-models.py](scripts/zen-models.py) wraps every probe below. Prefer it
over ad-hoc curl — it reads the key without printing it and normalizes the results.

```bash
S=.agents/local-skills/zen-model-onboarding/scripts/zen-models.py
$S list                 # catalog ids right now
$S list --base both     # Go plan vs full catalog, side by side
$S configured           # catalog vs litellm.nix zenModels: missing + stale
$S probe                # full capability matrix for every catalog id (~15 s parallel)
$S probe kimi-k3 new-model-id
$S gateway              # what the running 127.0.0.1:4000 actually answers
```

Because it is plain Python it is debuggable in place: `--json` for machine-readable
output, `--verbose` to dump the raw upstream body of every failing probe, `--jobs N` to
probe concurrently, and `--max-tokens` (default 256) to give a reasoning model headroom.
`probe` and `gateway` exit non-zero when something is unusable, so they are safe to use
in a check.

## Step 1 — Probe before trusting

Three independent capabilities matter, and a model can have any combination:

| Capability | Endpoint | Needed by |
|---|---|---|
| `chat=ok` | `POST /v1/chat/completions` | litellm, crush, VS Code chat, Claude Code |
| `tools=ok` | tool_calls in the chat response | every agent surface |
| `resp=ok` | `POST /v1/responses` | nothing in this repo — see below |

A `chat=no resp=ok` result means the model is **unusable here**. Only `chat=ok` models
can be added to the gateway.

**A model that only speaks `/v1/responses` cannot be added.** LiteLLM 1.75.5 forwards
`/v1/chat/completions` upstream, so pointing an entry straight at a Responses-only id
returns `ModelProtocolUnsupported` — verified against a scratch proxy, not assumed. All
three direct bridge attempts fail: `openai/<id>` + `/zen/v1`, `openai/responses/<id>`,
and `api_base = …/responses`. The Anthropic `/v1/messages` route is not an escape hatch
either (`ModelProtocolUnsupported` or `AuthError`). As of this writing the Responses-only
ids are `grok-4.6`, `grok-4.7`, `gpt-5.6-luna`, `gpt-6-luna`, `claude-haiku-5-5`,
`muse-spark-*`, `muse-wonder-*`, `gemini-4-argon-contributor`. Re-check; the list moves.

**Do not add a local translator in front of them.** One was built (a chat→Responses
adapter on port 4020, wired as an extra litellm upstream) and then removed: it worked,
but it broke the invariant that **litellm is the only thing proxying a provider
endpoint**. When a model needs a second translation layer, skip the model — pick a
chat-completions id instead.

**Slow reasoners need headroom.** `kimi-k3.1-pro` is the strongest reasoner measured
but can spend 60-240 s and 68k reasoning chars, returning empty `content` at
`max_tokens: 16000`. Give frontier-class models a large `maxOutputTokens` (32k) and keep
them off the hot path — plan mode only.

Zen also needs the `x-opencode-session` header (any stable uuid) or it answers
`400 MissingSessionID`. It is a routing hint, not auth.

### Reasoning models need a real token budget

Reasoning models emit `reasoning_content` first and only then `content`. With a modest
`max_tokens` the reasoning eats the budget, `finish_reason` comes back `length`, and
`content` is **empty**. Observed: `glm-5.3` burned 50565 chars of reasoning and returned
nothing at `max_tokens: 12000`.

Always read `finish_reason` and `usage.completion_tokens` from a probe — an empty
`content` usually means "budget too small", not "bad model".

Reasoning-effort controls are **not** portable. `reasoning_effort: "low"` measurably cut
reasoning on `minimax-m3.1-flash`, did nothing on `deepseek-v4.1-flash`, and the nested
`reasoning: { effort: low }` form sometimes *increased* it. Do not expose an effort knob
to a client without measuring it per model.

## Step 2 — Pick a tier

Claude Code exposes three aliases. Map them by measured behaviour, not vendor naming.

| Tier | Env var | Wants | Current pick |
|---|---|---|---|
| Frontier | `ANTHROPIC_DEFAULT_OPUS_MODEL` | complex planning, long reasoning — reached via `opusplan` so it stays off the hot path | `kimi-k3.1-pro` |
| Workhorse | `ANTHROPIC_DEFAULT_SONNET_MODEL` | most challenging implementation work, daily driver | `deepseek-v4.1-flash` |
| Subagent / quick | `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL` | short commands, raw output, little reflection | `deepseek-v4.1-flash` |

Measured on this repo's workload (short agentic prompts, 120-token answers):

- **Strongest reasoning:** `kimi-k3.1-pro`. Correct and thorough, but 60–240 s and prone
  to spending the whole budget on reasoning. Frontier/plan only.
- **Strong and fast:** `deepseek-v4.1-flash` (~3 s), `kimi-k2.7-code`, `deepseek-v4-pro`
  (~2.4 s). Good workhorse material, and the current subagent pick too.
- **Fast with little reflection (subagent tier):** `omen-alpha`, `glm-5.3-flash`,
  `mimo-v2.6-flash` — **probe the `reason=` column before promoting one**; a
  chat-completions model that answers directly is worth more here than a stronger
  Responses-only one that cannot be served at all.
- **Avoid interactively:** `qwen3.8-max` — correct but ~35 s / 1295 tokens where others
  used 2–4 s / 120. `minimax-m3` leaks its scratchpad into `content`.

**Zero `reasoning_content` is the subagent ideal.** Subagents re-read their whole
context per task, so a model that reasons 1300 chars before printing a command is pure
overhead — `glm-5.3-flash` did exactly that. Prefer models whose `reason=` probe column
is 0 for that tier.

Note `glm-5.3-flash` exists on **both** providers. Zen's copy and the Z.ai alias share a
name, so only one may appear in `model_list` — the repo keeps the Z.ai alias. Give any
second provider's model a distinct name.

For subagents, **low reflection beats raw capability**: a subagent re-reads its whole
context per task, so a model that thinks for 10k tokens before answering is both slower
and more expensive than a weaker model that just replies.

## Step 3 — Add to the gateway

Edit [litellm.nix](../../../../nixos-darwin/litellm.nix).

1. Add the id to `zenModels` (Zen) or `glmModels` (Z.ai, exact case):

```nix
zenModels = [
  "deepseek-v4-pro"      # frontier
  "deepseek-v4.1-flash"  # workhorse
  "glm-5.3-flash"        # subagent
];
```

2. If the model is Responses-only (`resp=ok`, `chat=no`), **stop** — it cannot go in
   `model_list` and there is no adapter to route around that (see Step 1). Do not add a
   second proxy; pick a chat-completions id.

3. Add an `[1m]` alias only if a client needs the 1M-context suffix — it is client-side
   accounting that Zen does not parse:

```nix
deepseek1m = (mkEntry opencodeZenBase "OPENCODE_API_KEY" "deepseek-v4.1-flash")
  // { model_name = "deepseek-v4.1-flash[1m]"; };
```

For Z.ai use `mkAlias upstream alias`. Note the `(mkEntry …) // { … }` form belongs in
the dedicated alias bindings, not inside the `zenModels` list.

4. **Watch for cross-provider name clashes.** Zen serves lowercase `glm-5.3-flash`, Z.ai
   serves `GLM-5.3-FLASH`, and `glm-5.3-flash` is *also* an existing Z.ai alias. LiteLLM
   routes duplicate `model_name` entries ambiguously — keep each name bound to exactly
   one upstream.

## Step 4 — Wire all four clients

**Claude Code** — [claude-code.nix](../../../../nixos-darwin/claude-code.nix):

```nix
frontier  = "deepseek-v4-pro";
workhorse = "deepseek-v4.1-flash[1m]";
subagent  = "glm-5.3-flash";
# settings.env:
#   ANTHROPIC_DEFAULT_OPUS_MODEL   = frontier;
#   ANTHROPIC_DEFAULT_SONNET_MODEL = workhorse;
#   ANTHROPIC_DEFAULT_HAIKU_MODEL  = subagent;
#   CLAUDE_CODE_SUBAGENT_MODEL     = subagent;
```

Keep `model = "opusplan"` so plan mode gets the frontier model while execution runs on
the workhorse. Update `fallbackModel` to something that is actually served.

**Crush** — [crush.nix](../../../../nixos-darwin/crush.nix): add `{ id, name }` entries to
`lowCostModels`.

**VS Code** — [vscode-agent.nix](../../../../nixos-darwin/vscode-agent.nix): add a full
object (id, name, reasoning flags, token limits, `url`, `requestHeaders`). Set
`vision = false` unless the model was actually probed with an image.

Do not copy `maxInputTokens` from a sibling entry — measure it. Send a large filler
prompt and bisect until upstream complains; `omen-alpha` accepted ~4 MB (~1M tokens)
despite being a small fast model, so a guessed 262k would have silently truncated
long sessions.

**VS Code workspace settings** — [.vscode/settings.json](../../../../.vscode/settings.json)
references models by bare id (`chat.utilityModel`, `chat.utilitySmallModel`,
`inlineChat.defaultModel`). A removed id there fails silently.

## Step 5 — Apply and verify

```bash
make bootstrap                                  # rebuild darwin config
launchctl kickstart -k gui/$(id -u)/org.nix-community.home.litellm
$S gateway                                      # every served id answers
$S configured                                   # no missing / stale ids
```

Then confirm in a client: `/model` in Claude Code, the model picker in VS Code, and
`crush` startup. Check `~/Library/Logs/Litellm/stderr` for routing errors.

## Removing or retiring a model

`$S configured` prints ids that are served but **gone from the catalog** (stale). For
each one: drop it from `zenModels`, `lowCostModels`, the VS Code model array, and
`.vscode/settings.json` — then re-run `$S gateway`. A stale model answers
`Model is unavailable` from upstream, which reads like a gateway outage but is not.

## Failure map

| Symptom | Meaning | Fix |
|---|---|---|
| `ModelProtocolUnsupported` | model is Responses-only | cannot be served; pick another id |
| `400 MissingSessionID` | missing `x-opencode-session` | keep the header in `mkEntry` |
| `Model is unavailable` | id retired upstream | remove it from all four places |
| empty `content`, `finish_reason=length` | reasoning ate the budget | raise `max_tokens`, or pick a lower-reflection model |
| `litellm.BadRequestError … Received Model Group=X` | id not in `model_list` | add to `zenModels`, rebuild |
| routing flakiness / wrong upstream | duplicate `model_name` | give each provider a distinct name |
