#!/usr/bin/env python3
"""Pont entre les hooks preToolUse de Copilot et les scripts de garde de GStack.

Lit l'événement sur stdin, au format Copilot ({toolName, toolArgs}) ou au format
compatible snake_case ({tool_name, tool_input}, harness Local et alias
PreToolUse), le transmet aux scripts amont careful/bin/check-careful.sh et
freeze/bin/check-freeze.sh au format Claude Code, puis renvoie la décision au
format Copilot (permissionDecision au premier niveau) en gardant aussi
l'enveloppe hookSpecificOutput lue par le harness Local.

Toute erreur vaut "pas de décision" ({}) : le wrapper bash ne doit jamais échouer.
"""
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAREFUL_TTL = 12 * 3600
WRITE_HINTS = ("edit", "write", "create", "patch", "replace", "insert")
PATH_KEYS = ("path", "file_path", "filePath", "filepath", "notebook_path", "file")
PATCH_FILE = re.compile(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$", re.M)
RANK = {"ask": 1, "deny": 2}


def state_root():
    env = os.environ.get("GSTACK_COPILOT_STATE", "")
    if env:
        return Path(env)
    res = subprocess.run(
        ["bash", "-c", '. "$1" && gstack_state_root', "_", str(ROOT / "bin" / "gstack-state-root.sh")],
        capture_output=True, text=True, timeout=5)
    return Path(res.stdout) if res.returncode == 0 and res.stdout else None


def run_check(script, tool_name, tool_input, cwd):
    payload = json.dumps({"hook_event_name": "PreToolUse", "tool_name": tool_name,
                          "tool_input": tool_input, "cwd": cwd})
    res = subprocess.run(["bash", str(script)], input=payload, capture_output=True,
                         text=True, timeout=10, cwd=cwd if os.path.isdir(cwd) else None)
    for line in reversed(res.stdout.strip().splitlines()):
        try:
            data = json.loads(line)
        except ValueError:
            continue
        out = data.get("hookSpecificOutput", data) if isinstance(data, dict) else {}
        decision = out.get("permissionDecision")
        if decision in RANK:
            return decision, out.get("permissionDecisionReason", "")
        return None
    return None


def target_paths(args):
    paths = [args[k] for k in PATH_KEYS if isinstance(args.get(k), str) and args[k]]
    for value in args.values():
        if isinstance(value, str) and "*** " in value:
            paths += [m.strip() for m in PATCH_FILE.findall(value)]
    return paths


def careful_active(state):
    flag = state / "careful-active"
    if not flag.is_file():
        return False
    try:
        stamp = int(flag.read_text().strip() or "0")
    except ValueError:
        stamp = 0
    if time.time() - stamp < CAREFUL_TTL:
        return True
    flag.unlink(missing_ok=True)
    return False


def decide(event):
    name = str(event.get("toolName") or event.get("tool_name") or "")
    args = event.get("toolArgs", event.get("tool_input", {}))
    if isinstance(args, str):
        try:
            args = json.loads(args)
        except ValueError:
            args = {}
    if not isinstance(args, dict):
        return None
    cwd = str(event.get("cwd") or os.getcwd())
    state = state_root()
    if state is None:
        return None

    decisions = []
    command = args.get("command")
    if isinstance(command, str) and command.strip() and careful_active(state):
        shell = "PowerShell" if re.search(r"powershell|pwsh", name, re.I) else "Bash"
        decisions.append(run_check(ROOT / "careful" / "bin" / "check-careful.sh", shell,
                                   {"command": command}, cwd))
    if (state / "freeze-dir.txt").is_file() and any(h in name.lower() for h in WRITE_HINTS):
        for path in target_paths(args):
            full = path if os.path.isabs(path) else os.path.join(cwd, path)
            decisions.append(run_check(ROOT / "freeze" / "bin" / "check-freeze.sh", "Edit",
                                       {"file_path": full}, cwd))
    decisions = [d for d in decisions if d]
    if not decisions:
        return None
    return max(decisions, key=lambda d: RANK[d[0]])


def main():
    try:
        event = json.loads(sys.stdin.read() or "{}")
        result = decide(event) if isinstance(event, dict) else None
    except Exception:
        result = None
    if not result:
        print("{}")
        return
    decision, reason = result
    print(json.dumps({
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
        "hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": decision,
                               "permissionDecisionReason": reason},
    }))


if __name__ == "__main__":
    main()
