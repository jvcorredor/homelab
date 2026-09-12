#!/usr/bin/env bash
# Check that every relative markdown link in the live docs resolves.
#
# ARCHITECTURE.md is the entry point to the live system and states
# structure, never values — so its only drift surface is links. This is
# the regression test for that contract, and it runs in CI
# (.github/workflows/docs-lint.yml) as well as from `just check-docs`.
#
# Usage: scripts/check-docs.sh [file ...]
# Defaults to the live docs. Superseded ADRs are history and are not
# checked. http(s), mailto, and anchor-only links are ignored.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  files=(ARCHITECTURE.md CONTEXT.md)
fi

status=0
for file in "${files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing file: $file" >&2
    status=1
    continue
  fi

  dir="$(dirname "$file")"
  while IFS= read -r target; do
    case "$target" in
      http://*|https://*|mailto:*|'#'*) continue ;;
    esac

    path="${target%%#*}"
    [[ -z "$path" ]] && continue

    if [[ ! -e "${dir}/${path}" ]]; then
      echo "broken link in ${file}: ${target}" >&2
      status=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$file" | sed -e 's/^](//' -e 's/)$//')
done

if [[ $status -eq 0 ]]; then
  echo "docs links OK: ${files[*]}"
fi
exit $status
