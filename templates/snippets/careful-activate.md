## Enforcement on GitHub Copilot (gstack-copilot)

Copilot ignores hooks declared in a skill. gstack-copilot installs a repository
hook instead (`.github/hooks/gstack-safety.json`) that runs the same destructive
command checks before every tool call, but only while the careful flag is set.
Set it now:

```bash
_S=$("$(git rev-parse --show-toplevel)/.github/skills/gstack/bin/gstack-paths" --get GSTACK_STATE_ROOT) && mkdir -p "$_S" && date +%s > "$_S/careful-active" && echo "CAREFUL_ACTIVE: $_S/careful-active"
```

Then tell the user that careful mode is enforced for 12 hours, or until they run
`/gstack-unfreeze` and ask to leave careful mode. If the block fails, or if the
session runs outside the Copilot harness (hooks not loaded), keep the advisory
behavior: pause and confirm with the user before any destructive command.
