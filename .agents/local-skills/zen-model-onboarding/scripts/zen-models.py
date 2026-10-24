#!/usr/bin/env python3
"""OpenCode Zen model discovery + capability probe.

Everything here is plain HTTP against the public catalog and the probe
endpoints, so it keeps working when new models appear and never depends on a
hardcoded list. Run it before touching nixos-darwin/litellm.nix.

Usage:
  zen-models.py list                 # catalog ids served by Zen right now
  zen-models.py list --base both     # Go plan vs full catalog, side by side
  zen-models.py probe                # probe every catalog id (slow, ~1 min)
  zen-models.py probe <model>...     # probe only the ids given
  zen-models.py configured           # catalog vs litellm.nix zenModels diff
  zen-models.py gateway              # probe ids served by localhost:4000

Debugging knobs:
  --json            machine-readable output instead of a table
  --jobs N          probe N models concurrently (default 1)
  --timeout SECS    per-request timeout (default 90)
  --max-tokens N    probe budget; raise it for reasoning models (default 256)
  --verbose         print raw upstream bodies for anything that fails

Environment:
  ZEN_API_KEY, KEY_FILE    override where the key comes from
  ZEN_BASE, ZEN_FULL_BASE  override the upstream bases
  ZEN_SESSION              routing hint sent as x-opencode-session
  GATEWAY_URL              default http://127.0.0.1:4000

Auth: the probe reads the OpenCode key from the sops-nix rendered file. It is
never echoed.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import asdict, dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# configuration
# ---------------------------------------------------------------------------

# Two catalogs, and they disagree. The Go plan is what this repo can actually
# use; the full catalog lists ids that are absent from the plan and/or speak
# only /v1/responses.
BASES: dict[str, str] = {
    "go": os.environ.get("ZEN_BASE", "https://opencode.ai/zen/go/v1"),
    "full": os.environ.get("ZEN_FULL_BASE", "https://opencode.ai/zen/v1"),
}

# Zen rejects header-less requests with 400 MissingSessionID. It is a routing
# hint, not auth -- any stable uuid works (same value as litellm.nix).
ZEN_SESSION = os.environ.get(
    "ZEN_SESSION", "5f3e1c2a-7b8d-4e6f-9a0b-1c2d3e4f5a6b"
)

KEY_FILE = Path(
    os.path.expanduser(
        os.environ.get("KEY_FILE", "~/.config/sops-nix/secrets/opencode_api_key")
    )
)
GATEWAY_URL = os.environ.get("GATEWAY_URL", "http://127.0.0.1:4000").rstrip("/")

# Cloudflare fronts opencode.ai and answers urllib's default agent with
# `403 error code 1010`. Any conventional agent gets through.
USER_AGENT = os.environ.get("ZEN_USER_AGENT", "curl/8.7.1")

REPO_ROOT = Path(__file__).resolve().parents[4]
LITELLM_NIX = REPO_ROOT / "nixos-darwin" / "litellm.nix"

# A model that answers chat-completions but never emits tool_calls is useless
# to every agent surface in this repo, so the probe always sends a tool.
CHAT_PROBE_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get the weather for a city",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}},
                "required": ["city"],
            },
        },
    }
]

# Body substrings that mean "this model cannot be added", as opposed to "this
# probe was malformed".
PROTOCOL_UNSUPPORTED = "ModelProtocolUnsupported"
MISSING_SESSION = "MissingSessionID"

COL_MODEL = 34


class ZenError(Exception):
    """A failure worth showing the operator without a traceback."""


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------


def http_request(
    url: str,
    *,
    body: dict | None = None,
    headers: dict[str, str] | None = None,
    timeout: float = 90.0,
) -> tuple[int, str]:
    """Issue one request and return (status, text).

    HTTP error statuses are returned, not raised: the probe endpoints report
    model capability *in the error body* (ModelProtocolUnsupported, Model is
    unavailable), so the body is the payload.
    """
    data = json.dumps(body).encode() if body is not None else None
    # Cloudflare in front of opencode.ai rejects urllib's default agent with
    # 403 error code 1010, so always send a normal one.
    hdrs = {"User-Agent": USER_AGENT}
    if data:
        hdrs["content-type"] = "application/json"
    hdrs.update(headers or {})

    req = urllib.request.Request(
        url, data=data, headers=hdrs, method="POST" if data else "GET"
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")
    except urllib.error.URLError as exc:
        raise ZenError(f"{url}: {exc.reason}") from exc
    except TimeoutError as exc:
        raise ZenError(f"{url}: timed out after {timeout}s") from exc


def zen_headers(key: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {key}",
        "x-opencode-session": ZEN_SESSION,
    }


def parse_json(raw: str, where: str) -> dict:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ZenError(
            f"{where}: upstream returned non-JSON -- {raw[:200]!r}"
        ) from exc
    if not isinstance(parsed, dict):
        raise ZenError(f"{where}: expected a JSON object, got {type(parsed).__name__}")
    return parsed


def api_key() -> str:
    """Read the OpenCode key without ever printing it."""
    from_env = os.environ.get("ZEN_API_KEY")
    if from_env:
        return from_env
    try:
        return KEY_FILE.read_text().strip()
    except OSError as exc:
        raise ZenError(
            f"no OpenCode key: set ZEN_API_KEY or render {KEY_FILE} ({exc.strerror})"
        ) from exc


# ---------------------------------------------------------------------------
# catalog
# ---------------------------------------------------------------------------


def catalog(base_key: str, *, timeout: float = 30.0) -> list[str]:
    """Sorted model ids the given base advertises right now."""
    url = f"{BASES[base_key]}/models"
    status, raw = http_request(url, timeout=timeout)
    if status >= 400:
        raise ZenError(f"GET {url} -> HTTP {status}: {raw[:200]}")

    data = parse_json(raw, url)
    ids = [
        m["id"]
        for m in data.get("data") or []
        if isinstance(m, dict) and isinstance(m.get("id"), str)
    ]
    if not ids:
        raise ZenError(f"{url}: catalog is empty (unexpected)")
    return sorted(ids)


# ---------------------------------------------------------------------------
# capability probe
# ---------------------------------------------------------------------------


@dataclass
class ProbeResult:
    model: str
    base: str = "go"
    chat: str = "?"  # ok | no | parse_error
    tools: str = "?"  # ok | no | ?
    resp: str = "?"  # ok | no | n/a
    finish_reason: str = ""
    completion_tokens: int = 0
    elapsed_s: float = 0.0
    note: str = ""
    raw: str = field(default="", repr=False)

    @property
    def usable(self) -> bool:
        """Every client in this repo needs chat-completions AND tool calls."""
        return self.chat == "ok" and self.tools == "ok"

    @property
    def responses_only(self) -> bool:
        """Chat-completions fails but /v1/responses answers.

        Unusable here: litellm is the only proxy for provider endpoints and it
        only forwards chat-completions, so there is nowhere to wire these.
        """
        return self.chat != "ok" and self.resp == "ok"

    @property
    def dead(self) -> bool:
        """Neither protocol answers, or only Responses does -> unusable."""
        return not self.usable

    def summary(self) -> str:
        return (
            f"chat={self.chat} tools={self.tools} resp={self.resp}"
            + (f" tokens={self.completion_tokens}" if self.completion_tokens else "")
            + (f" finish={self.finish_reason}" if self.finish_reason else "")
            + (f" note={self.note}" if self.note else "")
        )

    def to_dict(self) -> dict:
        """JSON form. The raw body is only interesting when a probe failed."""
        data = {k: v for k, v in asdict(self).items() if k != "raw"}
        if self.raw and not self.usable:
            data["raw"] = self.raw
        return data


def _one_line(text: str, limit: int = 70) -> str:
    return " ".join(text.split())[:limit]


def _error_detail(data: dict) -> tuple[str, str]:
    """Pull (kind, message) out of the several error shapes Zen uses."""
    err = data.get("error", data)
    if not isinstance(err, dict):
        return "error", str(err)
    kind = str(err.get("type") or err.get("code") or "error")
    msg = str(err.get("message") or err.get("detail") or "")
    return kind, msg


def _probe_responses(model: str, key: str, base_key: str, timeout: float) -> str:
    """Second chance for models that refused chat-completions on protocol."""
    url = f"{BASES[base_key]}/responses"
    status, raw = http_request(
        url,
        body={"model": model, "input": "say OK", "max_output_tokens": 32},
        headers=zen_headers(key),
        timeout=timeout,
    )
    if status >= 400:
        return "no"
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return "no"
    if not isinstance(data, dict):
        return "no"
    if data.get("status") == "completed" or data.get("output"):
        return "ok"
    return "no"


def probe_one(
    model: str,
    *,
    base_key: str = "go",
    max_tokens: int = 256,
    timeout: float = 90.0,
) -> ProbeResult:
    """Classify one model's chat / tools / responses capabilities."""
    result = ProbeResult(model=model, base=base_key)
    started = time.monotonic()
    # Fail fast on a missing key instead of reporting every id as chat=no.
    key = api_key()

    # Reasoning models emit reasoning_content first and only then content, so a
    # small budget makes them look broken: finish_reason=length, content empty.
    body = {
        "model": model,
        "messages": [
            {"role": "user", "content": "Use the get_weather tool for Paris."}
        ],
        "max_tokens": max_tokens,
        "tools": CHAT_PROBE_TOOLS,
    }
    status, raw = http_request(
        f"{BASES[base_key]}/chat/completions",
        body=body,
        headers=zen_headers(key),
        timeout=timeout,
    )
    result.raw = raw
    result.elapsed_s = round(time.monotonic() - started, 1)

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        result.chat = "parse_error"
        result.note = _one_line(raw)
        return result

    if not isinstance(data, dict) or "choices" not in data:
        kind, msg = _error_detail(data if isinstance(data, dict) else {})
        result.chat = "no"
        result.note = _one_line(f"{kind}: {msg}")
        # Only a protocol rejection is worth retrying on /v1/responses.
        result.resp = (
            _probe_responses(model, key, base_key, timeout)
            if PROTOCOL_UNSUPPORTED in kind or PROTOCOL_UNSUPPORTED in msg
            else "n/a"
        )
        return result

    try:
        choice = data["choices"][0]
        message = choice["message"]
    except (KeyError, IndexError, TypeError):
        result.chat = "parse_error"
        result.note = _one_line(raw)
        return result

    result.chat = "ok"
    result.tools = "ok" if message.get("tool_calls") else "no"
    result.resp = "n/a"
    result.finish_reason = str(choice.get("finish_reason") or "")
    usage = data.get("usage") or {}
    result.completion_tokens = int(usage.get("completion_tokens") or 0)

    # An empty content is the classic "reasoning ate the budget" signal, and it
    # reads like a broken model unless we say so.
    if not (message.get("content") or "").strip() and not message.get("tool_calls"):
        if result.finish_reason == "length":
            result.note = f"empty content, budget exhausted -- raise --max-tokens"
        else:
            result.note = "empty content"
    return result


def probe_many(
    models: list[str], *, base_key: str, jobs: int, **kwargs
) -> list[ProbeResult]:
    def run(model: str) -> ProbeResult:
        return probe_one(model, base_key=base_key, **kwargs)

    if jobs <= 1:
        return [run(m) for m in models]
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        return list(pool.map(run, models))


# ---------------------------------------------------------------------------
# litellm.nix parsing
# ---------------------------------------------------------------------------


def parse_nix_list(path: Path, binding: str) -> list[str] | None:
    """Extract the string literals of `binding = [ ... ];` from a .nix file.

    Deliberately regex-based: this reads one flat string list, and pulling in a
    Nix parser to do it would cost more than it buys.
    """
    try:
        src = path.read_text()
    except OSError as exc:
        raise ZenError(f"cannot read {path}: {exc.strerror}") from exc

    match = re.search(rf"\b{re.escape(binding)}\s*=\s*\[(.*?)\]\s*;", src, re.S)
    if not match:
        return None
    return re.findall(r'"([^"]+)"', match.group(1))


# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------


def print_table(header: tuple[str, ...], rows: list[tuple[str, ...]]) -> None:
    widths = [
        max(len(h), *(len(r[i]) for r in rows)) if rows else len(h)
        for i, h in enumerate(header)
    ]
    print("  ".join(h.ljust(w) for h, w in zip(header, widths)))
    for row in rows:
        print("  ".join(c.ljust(w) for c, w in zip(row, widths)))


def cmd_list(args: argparse.Namespace) -> int:
    bases = ["go", "full"] if args.base == "both" else [args.base]
    if len(bases) == 1:
        ids = catalog(bases[0], timeout=args.timeout)
        if args.json:
            print(json.dumps(ids, indent=2))
        else:
            print("\n".join(ids))
        return 0

    # Side by side: an id present only in `full` is usually not reachable here.
    only_go, only_full, both = {}, {}, []
    catalogs = {b: set(catalog(b, timeout=args.timeout)) for b in bases}
    go, full = catalogs["go"], catalogs["full"]
    only_go = sorted(go - full)
    only_full = sorted(full - go)
    both = sorted(go & full)

    if args.json:
        print(
            json.dumps(
                {"go_only": only_go, "full_only": only_full, "both": both}, indent=2
            )
        )
        return 0

    print(f"== both ({len(both)}) ==")
    print("\n".join(both) or "(none)")
    print(f"\n== go plan only ({len(only_go)}) ==")
    print("\n".join(only_go) or "(none)")
    print(f"\n== full catalog only ({len(only_full)}) -- probe before trusting ==")
    print("\n".join(only_full) or "(none)")
    return 0


def cmd_probe(args: argparse.Namespace) -> int:
    models = args.models or catalog(args.base, timeout=args.timeout)
    results = probe_many(
        models,
        base_key=args.base,
        jobs=args.jobs,
        max_tokens=args.max_tokens,
        timeout=args.timeout,
    )

    if args.json:
        print(json.dumps([r.to_dict() for r in results], indent=2))
    elif args.verbose:
        for r in results:
            print(f"--- {r.model} [{r.base}] {r.elapsed_s}s")
            print(f"    {r.summary()}")
            if r.raw and r.chat != "ok":
                print(f"    raw: {_one_line(r.raw, 400)}")
    else:
        print_table(
            ("MODEL", "CAPABILITIES"), [(r.model, r.summary()) for r in results]
        )

    responses_only = [r for r in results if r.responses_only]
    dead = [r for r in results if r.dead and not r.responses_only]

    if not args.quiet and (responses_only or dead):
        # stderr is unbuffered and stdout is not, so without this the summary
        # prints above the table when piped.
        sys.stdout.flush()
        if responses_only:
            print(
                f"\n{len(responses_only)}/{len(results)} model(s) speak Responses "
                f"only -> cannot be served (litellm forwards chat-completions):",
                file=sys.stderr,
            )
            for r in responses_only:
                print(f"  {r.model:<{COL_MODEL}} {r.summary()}", file=sys.stderr)
        if dead:
            print(
                f"\n{len(dead)}/{len(results)} model(s) unusable on this base "
                f"(no chat, no responses):",
                file=sys.stderr,
            )
            for r in dead:
                print(f"  {r.model:<{COL_MODEL}} {r.summary()}", file=sys.stderr)
    return 0


def cmd_configured(args: argparse.Namespace) -> int:
    configured = parse_nix_list(LITELLM_NIX, args.binding)
    if configured is None:
        raise ZenError(f"no `{args.binding} = [ ... ];` binding in {LITELLM_NIX}")

    live = set(catalog(args.base, timeout=args.timeout))
    served = set(configured)
    missing = sorted(live - served)
    stale = sorted(served - live)

    if args.json:
        print(
            json.dumps(
                {"binding": args.binding, "missing": missing, "stale": stale}, indent=2
            )
        )
        return 0

    print(f"== in catalog, not served by {args.binding} ({len(missing)}) ==")
    print("\n".join(missing) or "(none)")
    print(f"\n== served by {args.binding}, gone from catalog ({len(stale)}) ==")
    print("\n".join(stale) or "(none)")
    return 0


def gateway_probe(model: str, timeout: float) -> tuple[str, str, str]:
    """(model, status, detail) for one id the running gateway advertises."""
    try:
        status, raw = http_request(
            f"{GATEWAY_URL}/v1/chat/completions",
            body={
                "model": model,
                "messages": [{"role": "user", "content": "say OK"}],
                "max_tokens": 16,
            },
            headers={"Authorization": "Bearer litellm-local"},
            timeout=timeout,
        )
    except ZenError as exc:
        return model, "error", _one_line(str(exc), 80)

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return model, "parse_error", _one_line(raw, 80)

    if isinstance(data, dict) and "choices" in data:
        return model, "ok", ""

    err = data.get("error", {}) if isinstance(data, dict) else {}
    msg = err.get("message", err) if isinstance(err, dict) else err
    return model, "fail", _one_line(str(msg), 80)


def cmd_gateway(args: argparse.Namespace) -> int:
    url = f"{GATEWAY_URL}/v1/models"
    try:
        status, raw = http_request(url, timeout=20.0)
    except ZenError as exc:
        raise ZenError(f"litellm gateway not reachable at {GATEWAY_URL}: {exc}") from exc
    if status >= 400:
        raise ZenError(f"GET {url} -> HTTP {status}: {raw[:200]}")

    data = parse_json(raw, url)
    models = sorted(
        m["id"]
        for m in data.get("data") or []
        if isinstance(m, dict) and isinstance(m.get("id"), str)
    )
    if not models:
        raise ZenError(f"{url}: gateway serves no models")

    if args.jobs <= 1:
        results = [gateway_probe(m, args.timeout) for m in models]
    else:
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            results = list(pool.map(lambda m: gateway_probe(m, args.timeout), models))

    if args.json:
        print(
            json.dumps(
                [{"model": m, "status": s, "detail": d} for m, s, d in results],
                indent=2,
            )
        )
    else:
        print_table(("GATEWAY_MODEL", "STATUS", "DETAIL"), results)

    # A served-but-dead id is exactly the failure this command exists to catch.
    dead = [(m, s, d) for m, s, d in results if s != "ok"]
    if dead:
        sys.stdout.flush()
        print(
            f"\n{len(dead)}/{len(results)} served id(s) do not answer:",
            file=sys.stderr,
        )
        for m, s, d in dead:
            print(f"  {m:<{COL_MODEL}} {s} {d}", file=sys.stderr)
        return 1
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def _add_global_flags(
    parser: argparse.ArgumentParser, *, default: object
) -> None:
    """Global flags, added to the root parser and to every subparser.

    The subparser copies use default=SUPPRESS so that `--json list` and
    `list --json` both work: a subparser only overrides what was actually
    passed to it.
    """
    parser.add_argument(
        "--json",
        action="store_true",
        default=default,
        help="machine-readable output",
    )
    parser.add_argument(
        "--jobs", type=int, default=default, metavar="N", help="parallelism (default 1)"
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=default,
        metavar="SECS",
        help="per-request timeout (default 90)",
    )
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=default,
        metavar="N",
        help="probe budget; raise it for reasoning models (default 256)",
    )
    parser.add_argument(
        "--verbose", action="store_true", default=default, help="per-probe details"
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        default=default,
        help="suppress the unusable-models summary",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="zen-models.py",
        description="OpenCode Zen model discovery + capability probe.",
    )
    _add_global_flags(
        parser, default=argparse.SUPPRESS
    )  # real defaults are set in subparsers
    parser.set_defaults(json=False, jobs=1, timeout=90.0, max_tokens=256)
    parser.set_defaults(verbose=False, quiet=False)

    subs = parser.add_subparsers(dest="command", required=True)

    def sub(name: str, help_text: str) -> argparse.ArgumentParser:
        p = subs.add_parser(name, help=help_text)
        _add_global_flags(p, default=argparse.SUPPRESS)
        return p

    p_list = sub("list", "catalog ids right now")
    p_list.add_argument(
        "--base",
        choices=["go", "full", "both"],
        default="go",
        help="which catalog to list (default: go, the plan this repo uses)",
    )
    p_list.set_defaults(func=cmd_list)

    p_probe = sub("probe", "capability matrix (chat / tools / responses)")
    p_probe.add_argument(
        "models", nargs="*", help="ids to probe (default: whole catalog)"
    )
    p_probe.add_argument("--base", choices=["go", "full"], default="go")
    p_probe.set_defaults(func=cmd_probe)

    p_conf = sub("configured", "catalog vs litellm.nix diff")
    p_conf.add_argument(
        "--binding",
        default="zenModels",
        help="nix list to compare against (default: zenModels)",
    )
    p_conf.add_argument("--base", choices=["go", "full"], default="go")
    p_conf.set_defaults(func=cmd_configured)

    sub("gateway", "probe ids served by the local litellm gateway").set_defaults(
        func=cmd_gateway
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except ZenError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
