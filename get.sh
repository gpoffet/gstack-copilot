#!/usr/bin/env bash
# get.sh: downloads a gstack-copilot release and installs it into the current git repository.
#
#   curl -fsSL https://raw.githubusercontent.com/gpoffet/gstack-copilot/main/get.sh | bash
#
# Run it from the root of your project. Arguments go to install.sh:
#   ... | bash -s -- --uninstall       remove GStack from the project
#   ... | bash -s -- --yes --no-hooks  no questions, no safety hook
# Environment:
#   GSTACK_COPILOT_VERSION  release tag to install (default: latest), e.g. v1.91.176.0-1
#   GSTACK_COPILOT_REPO     GitHub repository to download from (default: gpoffet/gstack-copilot)
#   GSTACK_COPILOT_URL      base URL holding the release assets (mirrors, tests); overrides the two above
#
# The archive is checked against the SHA-256 published with the release before
# anything runs. Everything lives in main() so a truncated download runs nothing.
set -euo pipefail

main() {
  local repo="${GSTACK_COPILOT_REPO:-gpoffet/gstack-copilot}"
  local version="${GSTACK_COPILOT_VERSION:-latest}"
  local asset=gstack-copilot.tar.gz url expected actual

  say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
  die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

  command -v curl >/dev/null || die "curl is required"
  command -v tar >/dev/null || die "tar is required"

  if [[ -n "${GSTACK_COPILOT_URL:-}" ]]; then
    url="$GSTACK_COPILOT_URL"
  elif [[ "$version" == latest ]]; then
    url="https://github.com/$repo/releases/latest/download"
  else
    url="https://github.com/$repo/releases/download/$version"
  fi

  # Global on purpose: the EXIT trap runs after main() returns.
  GSTACK_COPILOT_TMP="$(mktemp -d)"
  trap 'rm -rf "$GSTACK_COPILOT_TMP"' EXIT
  local tmp="$GSTACK_COPILOT_TMP"

  say "Downloading gstack-copilot ($version)"
  curl -fsSL "$url/$asset" -o "$tmp/$asset" || die "download failed: $url/$asset"
  curl -fsSL "$url/$asset.sha256" -o "$tmp/$asset.sha256" || die "download failed: $url/$asset.sha256"

  expected="$(awk '{print $1}' "$tmp/$asset.sha256")"
  if command -v sha256sum >/dev/null; then
    actual="$(sha256sum "$tmp/$asset" | awk '{print $1}')"
  elif command -v shasum >/dev/null; then
    actual="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"
  else
    die "sha256sum or shasum is required to verify the download"
  fi
  [[ -n "$expected" && "$expected" == "$actual" ]] || die "checksum mismatch for $asset: the download is corrupted"

  tar -xzf "$tmp/$asset" -C "$tmp"
  [[ -x "$tmp/gstack-copilot/install.sh" ]] || die "unexpected archive layout"

  # With curl | bash, stdin is the script itself: read answers from the terminal.
  if [[ -t 0 ]] || ! { : < /dev/tty; } 2>/dev/null; then
    "$tmp/gstack-copilot/install.sh" "$@"
  else
    "$tmp/gstack-copilot/install.sh" "$@" < /dev/tty
  fi
}

main "$@"
