# gstack-copilot

[GStack](https://github.com/garrytan/gstack) skills for **GitHub Copilot**,
installed per project: VS Code with the Copilot harness, Copilot CLI and the
GitHub Copilot app all pick them up.

*[Version française](README.fr.md)*

```bash
# from the root of your project
curl -fsSL https://raw.githubusercontent.com/gpoffet/gstack-copilot/main/get.sh | bash
```

Then open the Copilot chat and type `/gstack-office-hours`.

> gstack-copilot is an independent community port. It is not affiliated with
> or endorsed by GStack, Garry Tan, GitHub or Microsoft. GStack is the work of
> Garry Tan and its contributors; this repository only repackages it for
> Copilot.

## What you get

GStack is a set of skills that walk an AI agent through a full development
cycle: product framing, plan reviews, code review, shipping, retrospectives.
Its official installer targets a per-user setup and needs a full GStack clone.
gstack-copilot turns it into a **per-project install**, versioned with your
code, so everyone on the team gets the same skills without installing GStack.

| Step | Skills |
|---|---|
| Think | `/gstack-office-hours`, `/gstack-spec` |
| Review the plan | `/gstack-plan-ceo-review`, `/gstack-plan-eng-review`, `/gstack-plan-design-review`, `/gstack-plan-devex-review`, `/gstack-autoplan` (every review in a row), `/gstack-plan-tune` |
| Build and check | `/gstack-review`, `/gstack-investigate`, `/gstack-health`, `/gstack-test-audit`, `/gstack-qa-only`, `/gstack-deslop-shared-libs` |
| Ship and document | `/gstack-ship`, `/gstack-document-generate`, `/gstack-document-release`, `/gstack-retro`, `/gstack-learn` |
| Resume work | `/gstack-context-save`, `/gstack-context-restore` |
| Safety | `/gstack-careful`, `/gstack-freeze`, `/gstack-guard`, `/gstack-unfreeze` |

`/gstack` routes to the right skill when in doubt. Skills carry the `gstack-`
prefix because `/review` is a Copilot built-in, and because VS Code requires a
skill's name to match its folder.

## Requirements

* Linux, macOS or WSL, with `bash`, `git`, `curl` and `python3`.
* **[Bun](https://bun.sh) 1.4.2 or later.** GStack's tools are written in
  TypeScript and run on Bun. The installer offers to install it for the current
  user, without admin rights.
* VS Code with GitHub Copilot, with **Copilot** selected as the Session Target
  (or Copilot CLI).

Native Windows is not supported: the skills and the safety hook rely on bash.

## Install, update, uninstall

All commands run from the root of the project.

| Action | Command |
|---|---|
| Install or update | `curl -fsSL https://raw.githubusercontent.com/gpoffet/gstack-copilot/main/get.sh \| bash` |
| Pin a release | `curl -fsSL .../get.sh \| GSTACK_COPILOT_VERSION=v1.91.176.0-1 bash` |
| No questions | `curl -fsSL .../get.sh \| bash -s -- --yes` |
| Without the safety hook | `curl -fsSL .../get.sh \| bash -s -- --no-hooks` |
| Uninstall | `curl -fsSL .../get.sh \| bash -s -- --uninstall` |

`get.sh` downloads the latest [release](https://github.com/gpoffet/gstack-copilot/releases),
checks it against its published SHA-256, and runs `install.sh`. Prefer to read
before running? Download it first:

```bash
curl -fsSLO https://raw.githubusercontent.com/gpoffet/gstack-copilot/main/get.sh
less get.sh
bash get.sh
```

You can also clone this repository and run `/path/to/gstack-copilot/install.sh`
from your project.

Your project receives:

| Path | Content |
|---|---|
| `.github/skills/gstack-*/` | the skills, one folder each |
| `.github/skills/gstack/` | the runtime: `/gstack` router, tools, libraries, references, licenses |
| `.github/hooks/gstack-safety.json` | the `preToolUse` hook behind `/gstack-careful` and `/gstack-freeze` |
| `AGENTS.md` | a section between markers with the workflow and routing; the rest of the file is left alone |

Commit them (`git add .github AGENTS.md`) so the whole team gets the skills.
GStack's user state (settings, learnings, logs) stays in `~/.gstack/`, outside
the repository. Reinstalling replaces the previous version cleanly, and
uninstalling restores `AGENTS.md` as it was.

## Copilot harness or Local harness

VS Code can run its agent on two engines. **Copilot** (recommended) shares its
runtime with Copilot CLI: GStack's generator writes for its tool names
(`ask_user`, `task`, `view`), and its hook format is the one installed here.
**Local**, the older engine, also runs the skills: the `AGENTS.md` section maps
its tool names. The hook accepts both event formats.

## Safety: /gstack-careful and /gstack-freeze

Copilot ignores hooks declared inside a skill, so gstack-copilot installs a
repository hook that calls GStack's own safety checks.

* With neither mode active, the hook makes no decision and starts no Python process.
* `/gstack-careful` sets a flag for 12 hours. Destructive commands then need
  confirmation (`git reset --hard`, `git push --force`, `DROP TABLE`...) or are
  denied outright (`rm -rf /`, `rm -rf ~`).
* `/gstack-freeze <folder>` denies file edits outside that folder (edit,
  create and patch tools). Terminal commands are not path-checked.
* `/gstack-unfreeze` lifts the boundary, and also ends careful mode when asked to.
* The hook never blocks by accident: on any internal error it answers "no
  decision", because Copilot denies the tool when a `preToolUse` hook fails.

Hooks run code on your machine, like any agent plugin. Read
`.github/skills/gstack/copilot/` before installing if that matters to you, or
install with `--no-hooks`.

## Which GStack skills are left out

`skills.txt` lists the installed skills and, in comments, the excluded ones:

* skills that need GStack's compiled browser, design engine or PDF renderer
  (`/browse`, `/qa`, `/design-review`, `/canary`...);
* `/cso`: it needs a native launcher and Docker, and its trust model rejects a
  launcher shipped inside the repository being audited;
* outside reviews through other CLIs (`/codex`, `/claude-code`) and GBrain memory;
* `/gstack-upgrade`: updates come from gstack-copilot releases instead.

When GStack announces a newer version during a skill, the agent mentions it
once and never tries to upgrade in place. To turn the check off:
`.github/skills/gstack/bin/gstack-config set update_check false`.

## Migrating from the legacy port

The earlier `install-gstack.sh` script copied the skills into `.agents/skills/`
with absolute paths. The installer detects it, offers to remove the old folders
and their `AGENTS.md` section, then installs the new version. It also points at
`chat.tools.terminal.autoApprove` rules in `.vscode/settings.json` that still
mention `.agents/skills`, to clean up by hand.

## Known limitations

* The hook has been tested with simulated events in the documented format.
  Copilot's edit tool names are not publicly listed, so the hook matches names
  containing `edit`, `write`, `create`, `patch`, `replace` or `insert`. Type
  `/hooks` in the chat to check the hook is loaded.
* Skills are large (roughly 15k to 80k tokens once loaded): one skill per
  conversation works best.
* GStack's preamble loads its `claude` model overlay; with other models these
  instructions stay generic and harmless.

## For maintainers

| File | Role |
|---|---|
| `GSTACK_REF` | pinned GStack commit |
| `skills.txt` | installed skills |
| `build.sh` | renders GStack with `gen:skill-docs --host copilot`, then `scripts/assemble.py` builds `dist/` |
| `install.sh` | copies `dist/` into a project, no rewriting at install time |
| `get.sh` | one-line installer: downloads a release, verifies it, runs `install.sh` |
| `scripts/package.sh` | builds the release archive |
| `templates/` | hook, skill additions, `AGENTS.md` section |
| `tests/` | static checks and an end-to-end install test |
| `dist/` | build output, committed |

`dist/` is reproducible: CI rebuilds it from `GSTACK_REF` and fails on any
difference. `tests/smoke.sh` installs into a throwaway repository and checks the
tools, the skill preambles, the hook, `get.sh` and uninstalling.

**Following GStack.** Every Monday, the *Track GStack* workflow rebuilds from
GStack's latest commit, runs the tests and opens a pull request. Enable
*Allow GitHub Actions to create and approve pull requests* in Settings >
Actions > General for it to work. To do it by hand:

```bash
git -C .build/gstack fetch origin main && git -C .build/gstack rev-parse FETCH_HEAD > GSTACK_REF
./build.sh && tests/smoke.sh
```

**Releasing.** Tag the merged commit with `v<GStack version>-<n>`; the
*Release* workflow tests, packages and publishes it, and `get.sh` picks it up:

```bash
git tag v1.91.176.0-1 && git push origin v1.91.176.0-1
```

## License

MIT, see [LICENSE](LICENSE). `dist/` contains GStack files, Copyright (c) 2026
Garry Tan, under the MIT License, some derived from Apache-2.0 works; their
license texts ship with every install under `.github/skills/gstack/`.
