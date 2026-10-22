#!/usr/bin/env python3
"""Assemble dist/ from a GStack checkout rendered with `gen:skill-docs --host copilot`.

The upstream Copilot host targets a per-user install (~/.copilot/skills).
This script turns its output into a per-project install under .github/skills/:

  .github/skills/gstack/          runtime root (router SKILL.md, bin/, lib/, assets)
  .github/skills/gstack-<skill>/  one directory per selected skill
  .github/hooks/gstack-safety.json  preToolUse hook for /careful and /freeze

Usage: python3 -I scripts/assemble.py --src <gstack checkout> --out dist
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
TEMPLATES = HERE / "templates"

PROJECT_SKILLS = "$(git rev-parse --show-toplevel)/.github/skills/"

# Runtime assets copied into the gstack/ root, relative to the checkout.
# Mirrors setup's create_copilot_runtime_root + _link_runtime_dists, minus the
# browser, design, PDF and CSO binaries this distribution does not ship.
ROOT_DIRS = ["bin", "lib", "careful/bin", "freeze/bin", "review/specialists"]
ROOT_FILES = [
    "VERSION", "ETHOS.md", "LICENSE", "NOTICE.md", "licenses/Apache-2.0.txt",
    "scripts/jargon-list.json", "scripts/question-registry.ts", "scripts/ship-measure.ts",
    "docs/askuserquestion-split.md", "docs/askuserquestion-cjk.md", "docs/test-value-bar.md",
    "review/checklist.md", "review/design-checklist.md", "review/greptile-triage.md",
    "review/TODOS-format.md", "plan-devex-review/dx-hall-of-fame.md",
    "browse/bin/remote-slug", "autoplan/DRIVER.md",
]
# Heavy lib/ subtrees used only by skills this distribution leaves out.
LIB_EXCLUDES = {"diagram-render", "cso"}
# Skills read as reference by other skills ($GSTACK_ROOT/<skill>/SKILL.md).
# Kept hidden from the / menu and from automatic loading.
REFERENCE_SKILLS = ["office-hours", "plan-ceo-review", "plan-design-review",
                    "plan-eng-review", "plan-devex-review", "document-release"]


def die(msg):
    print(f"assemble: {msg}", file=sys.stderr)
    sys.exit(1)


def read_skill_list(path):
    skills = []
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            skills.append(line)
    return skills


def split_frontmatter(text):
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---\n", 4)
    if end < 0:
        return None, text
    return text[4:end], text[end + 5:]


def set_frontmatter_field(fm, key, value):
    pattern = re.compile(rf"^{re.escape(key)}:.*$", re.M)
    if pattern.search(fm):
        return pattern.sub(f"{key}: {value}", fm, count=1)
    return fm.rstrip("\n") + f"\n{key}: {value}"


def frontmatter_description(fm):
    """Return the description text of a frontmatter block (plain or | block)."""
    m = re.search(r"^description:[ \t]*(.*)$", fm, re.M)
    if not m:
        return ""
    first = m.group(1).strip()
    if first not in ("|", ">", "|-", ">-"):
        return first.strip('"')
    lines = []
    for line in fm[m.end():].splitlines()[1:]:
        if line and not line.startswith(" "):
            break
        lines.append(line.strip())
    return " ".join(l for l in lines if l)


def rewrite_paths(text):
    text = text.replace("$HOME/.copilot/skills/", PROJECT_SKILLS)
    text = text.replace("~/.copilot/skills/", PROJECT_SKILLS)
    text = text.replace("$HOME/.claude/skills/gstack/", PROJECT_SKILLS + "gstack/")
    text = text.replace("~/.claude/skills/gstack/", PROJECT_SKILLS + "gstack/")
    text = text.replace(
        "Fix: ./setup --host copilot from your gstack checkout; ./setup --status shows it.",
        "Fix: run gstack-copilot's install.sh from the repository root.")
    return text


def copy_file(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def copy_tree(src, dst, ignore=None):
    shutil.copytree(src, dst, symlinks=False, ignore=ignore, dirs_exist_ok=True)


def script_closure(src, root):
    """Copy the scripts/ modules the shipped TypeScript imports (bun metafile)."""
    entries = []
    for p in sorted((src / "bin").iterdir()):
        if p.is_file() and (p.suffix == ".ts" or p.read_bytes()[:40].find(b"bun") >= 0):
            entries.append(str(p))
    entries += [str(p) for p in sorted((src / "lib").glob("*.ts"))]
    entries += [str(src / f) for f in ROOT_FILES if f.endswith(".ts") and (src / f).is_file()]
    if not entries:
        return []
    meta = root.parent.parent.parent / ".assemble-meta.json"
    outdir = root.parent.parent.parent / ".assemble-out"
    cmd = ["bun", "build", *entries, "--target=bun", "--packages=external",
           f"--outdir={outdir}", f"--metafile={meta}"]
    res = subprocess.run(cmd, cwd=src, capture_output=True, text=True)
    copied = []
    try:
        if res.returncode != 0 or not meta.exists():
            print(res.stderr[-2000:], file=sys.stderr)
            die("bun build (import closure) failed")
        inputs = json.loads(meta.read_text()).get("inputs", {})
        for rel in sorted(inputs):
            path = Path(rel)
            if not path.is_absolute():
                path = (src / path).resolve()
            try:
                rel_src = path.relative_to(src.resolve())
            except ValueError:
                continue
            if rel_src.parts[0] == "node_modules" or (root / rel_src).exists():
                continue
            copy_file(path, root / rel_src)
            copied.append(str(rel_src))
    finally:
        shutil.rmtree(outdir, ignore_errors=True)
        meta.unlink(missing_ok=True)
    return copied


def append_snippet(skill_md, snippet_name, replace_advisory=False):
    text = skill_md.read_text()
    snippet = (TEMPLATES / "snippets" / snippet_name).read_text()
    if replace_advisory:
        # Upstream says the skill is advisory on Copilot: here the repo hook enforces it.
        text = re.sub(r"^> \*\*Safety Advisory[^\n]*\n", "", text, count=1, flags=re.M)
    skill_md.write_text(text.rstrip("\n") + "\n\n" + snippet)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--skills", type=Path, default=HERE / "skills.txt")
    ap.add_argument("--ref", default="")
    args = ap.parse_args()

    src = args.src.resolve()
    gen = src / ".copilot" / "skills"
    if not (gen / "gstack" / "SKILL.md").exists():
        die(f"{gen} is missing: run `bun run gen:skill-docs --host copilot` in {src}")

    out = args.out.resolve()
    skills_dir = out / ".github" / "skills"
    hooks_dir = out / ".github" / "hooks"
    shutil.rmtree(out / ".github", ignore_errors=True)
    skills_dir.mkdir(parents=True)
    hooks_dir.mkdir(parents=True)
    root = skills_dir / "gstack"

    selected = read_skill_list(args.skills)
    missing = [s for s in selected if not (gen / f"gstack-{s}" / "SKILL.md").exists()]
    if missing:
        die("unknown skills in skills.txt: " + ", ".join(missing))

    # 1. Runtime root.
    copy_file(gen / "gstack" / "SKILL.md", root / "SKILL.md")
    for d in ROOT_DIRS:
        ignore = None
        if d == "lib":
            ignore = lambda _dir, names: [n for n in names if n in LIB_EXCLUDES and _dir == str(src / "lib")]
        if (src / d).is_dir():
            copy_tree(src / d, root / d, ignore=ignore)
    for f in ROOT_FILES:
        if (src / f).is_file():
            copy_file(src / f, root / f)
        else:
            print(f"assemble: warning: {f} not found in the checkout", file=sys.stderr)
    for s in REFERENCE_SKILLS:
        sdir = gen / f"gstack-{s}"
        if not sdir.is_dir():
            continue
        copy_tree(sdir, root / s)
        md = root / s / "SKILL.md"
        fm, body = split_frontmatter(md.read_text())
        fm = set_frontmatter_field(fm, "user-invocable", "false")
        fm = set_frontmatter_field(fm, "disable-model-invocation", "true")
        md.write_text(f"---\n{fm}\n---\n{body}")
    extra = script_closure(src, root)

    # 2. Selected skills, named like their directory (VS Code requires it,
    #    and /review is a Copilot built-in, hence the gstack- prefix).
    problems = []
    for s in selected:
        name = f"gstack-{s}"
        copy_tree(gen / name, skills_dir / name)
        md = skills_dir / name / "SKILL.md"
        fm, body = split_frontmatter(md.read_text())
        if fm is None:
            problems.append(f"{name}: no frontmatter")
            continue
        fm = set_frontmatter_field(fm, "name", name)
        desc = frontmatter_description(fm)
        if not desc:
            problems.append(f"{name}: empty description")
        elif len(desc) > 1024:
            problems.append(f"{name}: description is {len(desc)} chars (max 1024)")
        md.write_text(f"---\n{fm}\n---\n{body}")
    if problems:
        die("; ".join(problems))

    # 3. Copilot-specific additions.
    for s, snippet, adv in [("careful", "careful-activate.md", True),
                            ("guard", "careful-activate.md", True),
                            ("freeze", "freeze-copilot.md", True),
                            ("unfreeze", "careful-deactivate.md", False)]:
        md = skills_dir / f"gstack-{s}" / "SKILL.md"
        if md.exists():
            append_snippet(md, snippet, replace_advisory=adv)
    copy_tree(TEMPLATES / "copilot", root / "copilot")
    # Read by the preamble's upgrade flow: explains updates go through gstack-copilot.
    copy_tree(TEMPLATES / "gstack-upgrade", root / "gstack-upgrade")
    copy_file(TEMPLATES / "hooks" / "gstack-safety.json", hooks_dir / "gstack-safety.json")
    router_note = (TEMPLATES / "snippets" / "router-installed.md").read_text()
    installed = "\n".join(f"- `/gstack-{s}`" for s in selected)
    with open(root / "SKILL.md", "a") as fh:
        fh.write("\n\n" + router_note.replace("{{INSTALLED}}", installed))

    # 4. Path rewrites in the instructions. Binaries stay byte-identical to
    #    upstream: they locate the root from their own path.
    for path in skills_dir.rglob("*.md"):
        text = path.read_text()
        new = rewrite_paths(text)
        if new != text:
            path.write_text(new)

    # 5. Executable bits.
    for d in [root / "bin", root / "careful" / "bin", root / "freeze" / "bin",
              root / "browse" / "bin", root / "copilot"]:
        if d.is_dir():
            for p in d.iterdir():
                if p.is_file() and not p.suffix in (".md", ".json"):
                    p.chmod(0o755)

    # 6. Manifest, AGENTS.md section.
    version = (src / "VERSION").read_text().strip() if (src / "VERSION").exists() else "unknown"
    commit = subprocess.run(["git", "-C", str(src), "rev-parse", "--short=9", "HEAD"],
                            capture_output=True, text=True).stdout.strip() or args.ref
    # Commit date rather than build time: rebuilding the same ref gives the same dist/.
    commit_date = subprocess.run(["git", "-C", str(src), "log", "-1", "--format=%cI"],
                                 capture_output=True, text=True).stdout.strip()
    manifest = {
        "gstack_version": version,
        "gstack_commit": commit,
        "skills": [f"gstack-{s}" for s in selected],
        "managed": ["gstack"] + [f"gstack-{s}" for s in selected],
        "hooks": ["gstack-safety.json"],
        "gstack_commit_date": commit_date,
    }
    (root / ".gstack-copilot.json").write_text(json.dumps(manifest, indent=2) + "\n")
    agents = (TEMPLATES / "AGENTS.gstack.md").read_text()
    agents = agents.replace("{{VERSION}}", version).replace("{{COMMIT}}", commit)
    (out / "AGENTS.gstack.md").write_text(agents)

    total = sum(p.stat().st_size for p in out.rglob("*") if p.is_file())
    print(f"assemble: {len(selected)} skills, gstack {version} ({commit}), "
          f"{len(extra)} script modules, {total / 1e6:.1f} MB -> {out}")


if __name__ == "__main__":
    main()
