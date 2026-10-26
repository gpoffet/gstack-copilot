<!-- gstack-copilot:start (managed by gstack-copilot's install.sh, do not edit between these markers) -->
## GStack (gstack-copilot, GStack 1.91.245.0 @ 6154b6ea1)

GStack skills live in `.github/skills/gstack-*/`, their runtime in
`.github/skills/gstack/`, and user state in `~/.gstack/`. Invoke them with the
`gstack-` prefix (`/review` is a Copilot built-in). `/gstack` routes to the
right skill when in doubt.

Reference loop: `/gstack-office-hours` or `/gstack-spec` to frame the work,
`/gstack-plan-eng-review` to lock the architecture (or `/gstack-autoplan` to run
every plan review in a row), implement once approved, `/gstack-review` on the
diff, `/gstack-ship` to ship, `/gstack-retro` at the end of the cycle.

Routing:
* product idea: `/gstack-office-hours`
* strategy and scope: `/gstack-plan-ceo-review`
* architecture: `/gstack-plan-eng-review`
* bug: `/gstack-investigate`
* code review: `/gstack-review`
* shipping: `/gstack-ship`
* documentation: `/gstack-document-generate`, then `/gstack-document-release` after shipping
* overall code health: `/gstack-health`
* resuming work: `/gstack-context-save` and `/gstack-context-restore`
* risky operations: `/gstack-careful`, `/gstack-freeze`, `/gstack-guard`

Tool names: the skills mention `AskUserQuestion` (ask the user a question), the
`Agent` tool (run a subagent) and `Read`. In the Copilot harness these are
`ask_user`, `task` and `view`. In VS Code's Local harness they are
`#vscode/askQuestions`, `#agent/runSubagent` and `#read/readFile`.

The skills' bash blocks run from the repository root and need Bun (https://bun.sh).
<!-- gstack-copilot:end -->
