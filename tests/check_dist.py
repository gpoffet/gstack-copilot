#!/usr/bin/env python3
"""Static checks on a gstack-copilot .github/skills tree.

Usage: python3 -I tests/check_dist.py <folder containing .github/>

Checks:
  * each skill's frontmatter: name equals its folder, description of 1 to 1024 characters;
  * no per-user install path (~/.copilot/skills) left in the .md files;
  * every binary or file referenced under the gstack/ root exists;
  * syntax of the runtime's bash scripts (bash -n).
"""
import re
import subprocess
import sys
from pathlib import Path

base = Path(sys.argv[1] if len(sys.argv) > 1 else "dist").resolve()
skills = base / ".github" / "skills"
root = skills / "gstack"
errors = []

NAME_RE = re.compile(r"^[a-z0-9-]{1,64}$")
REF_RE = re.compile(
    r"(?:\$GSTACK_ROOT|\$\{GSTACK_ROOT\}|\$\(git rev-parse --show-toplevel\)/\.github/skills/gstack)"
    r"/([A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*)")
BIN_RE = re.compile(r"(?:\$GSTACK_BIN|\$\{GSTACK_BIN\}|\$_BIN)/([A-Za-z0-9_.-]+)")
# Assets left out on purpose (browser, design, PDF, CSO).
NOT_SHIPPED = ("browse/dist", "design/dist", "make-pdf/dist", "design-html/", "extension",
               "bin/gstack-cso", "bin/gstack-global-discover", "lib/diagram-render")


def frontmatter(text):
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    return text[4:end] if end > 0 else None


def description(fm):
    m = re.search(r"^description:[ \t]*(.*)$", fm, re.M)
    if not m:
        return ""
    first = m.group(1).strip()
    if first not in ("|", ">", "|-", ">-"):
        return first.strip('"')
    out = []
    for line in fm[m.end():].splitlines()[1:]:
        if line and not line.startswith(" "):
            break
        out.append(line.strip())
    return " ".join(l for l in out if l)


for d in sorted(p for p in skills.iterdir() if p.is_dir()):
    md = d / "SKILL.md"
    if not md.exists():
        errors.append(f"{d.name}: SKILL.md is missing")
        continue
    fm = frontmatter(md.read_text())
    if fm is None:
        errors.append(f"{d.name}: no frontmatter")
        continue
    name = re.search(r"^name:\s*(\S+)", fm, re.M)
    name = name.group(1) if name else ""
    if name != d.name or not NAME_RE.match(name):
        errors.append(f"{d.name}: name '{name}' differs from the folder or is invalid")
    desc = description(fm)
    if not 0 < len(desc) <= 1024:
        errors.append(f"{d.name}: description is {len(desc)} characters")

missing = set()
for md in skills.rglob("*.md"):
    text = md.read_text()
    if "~/.copilot/skills" in text or "$HOME/.copilot/skills" in text:
        errors.append(f"{md.relative_to(base)}: leftover ~/.copilot/skills path")
    for rel in REF_RE.findall(text):
        rel = rel.rstrip(".")
        if rel.startswith(NOT_SHIPPED) or "*" in rel or "<" in rel:
            continue
        if not (root / rel).exists() and not (skills / rel).exists():
            missing.add(rel)
    for name in BIN_RE.findall(text):
        name = name.rstrip(".")
        if not (root / "bin" / name).exists() and not f"bin/{name}".startswith(NOT_SHIPPED):
            missing.add(f"bin/{name}")
for rel in sorted(missing):
    errors.append(f"missing reference under gstack/: {rel}")

for script in sorted((root / "bin").iterdir()):
    head = script.read_bytes()[:64]
    if script.is_file() and head.startswith(b"#!") and b"bash" in head.split(b"\n")[0]:
        res = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
        if res.returncode:
            errors.append(f"bash -n {script.name}: {res.stderr.strip()[:200]}")

if errors:
    print("\n".join(f"FAIL {e}" for e in errors))
    sys.exit(1)
print(f"check_dist: OK ({sum(1 for _ in skills.iterdir())} folders under .github/skills)")
