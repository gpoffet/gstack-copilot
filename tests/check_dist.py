#!/usr/bin/env python3
"""Vérifications statiques d'une arborescence .github/skills de gstack-copilot.

Usage : python3 -I tests/check_dist.py <dossier contenant .github/>

Contrôle :
  * frontmatter de chaque skill : name égal au dossier, description de 1 à 1024 caractères ;
  * plus aucun chemin d'installation utilisateur (~/.copilot/skills) dans les .md ;
  * chaque binaire ou fichier référencé sous la racine gstack/ existe ;
  * syntaxe des scripts bash du runtime (bash -n).
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
# Ressources volontairement non livrées (navigateur, design, PDF, CSO).
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
        errors.append(f"{d.name}: SKILL.md manquant")
        continue
    fm = frontmatter(md.read_text())
    if fm is None:
        errors.append(f"{d.name}: frontmatter absent")
        continue
    name = re.search(r"^name:\s*(\S+)", fm, re.M)
    name = name.group(1) if name else ""
    if name != d.name or not NAME_RE.match(name):
        errors.append(f"{d.name}: name '{name}' différent du dossier ou invalide")
    desc = description(fm)
    if not 0 < len(desc) <= 1024:
        errors.append(f"{d.name}: description de {len(desc)} caractères")

missing = set()
for md in skills.rglob("*.md"):
    text = md.read_text()
    if "~/.copilot/skills" in text or "$HOME/.copilot/skills" in text:
        errors.append(f"{md.relative_to(base)}: chemin ~/.copilot/skills restant")
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
    errors.append(f"référence introuvable sous gstack/ : {rel}")

for script in sorted((root / "bin").iterdir()):
    head = script.read_bytes()[:64]
    if script.is_file() and head.startswith(b"#!") and b"bash" in head.split(b"\n")[0]:
        res = subprocess.run(["bash", "-n", str(script)], capture_output=True, text=True)
        if res.returncode:
            errors.append(f"bash -n {script.name}: {res.stderr.strip()[:200]}")

if errors:
    print("\n".join(f"ECHEC {e}" for e in errors))
    sys.exit(1)
print(f"check_dist: OK ({sum(1 for _ in skills.iterdir())} dossiers sous .github/skills)")
