## Enforcement on GitHub Copilot (gstack-copilot)

The repository hook `.github/hooks/gstack-safety.json` enforces the boundary
recorded above on file-editing tools (edit, create, patch). It reads the same
state file, so `/gstack-unfreeze` lifts it. Shell commands are not path-checked:
a terminal command can still write outside the boundary, so keep honoring it
yourself. Outside the Copilot harness (hooks not loaded) the boundary is advisory.
