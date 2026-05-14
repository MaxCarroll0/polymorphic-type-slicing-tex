#!/usr/bin/env bash
# Audit a .md export against an allowlist of MathJax-supported commands.
# Any \cmd in the file that is not in scripts/allowlist-md.txt counts as a
# leak. Also flags raw-LaTeX blocks (```{=latex}) and \tikz / \ooalign.
# Usage:  scripts/audit-md.sh <path/to/file.md>
set -uo pipefail
f="${1:?usage: audit-md.sh <file.md>}"
dir="$(dirname "${BASH_SOURCE[0]}")"
allowlist="$dir/allowlist-md.txt"
[ -f "$allowlist" ] || { echo "audit-md: missing $allowlist" >&2; exit 2; }
[ -s "$f" ] || { echo "audit-md: empty or missing $f" >&2; exit 2; }

# Collect distinct \cmd tokens from the file.
mapfile -t observed < <(grep -oE '\\[A-Za-z@]+' "$f" | sed 's/^\\//' | sort -u)

# Build the allowlist set.
mapfile -t allowed < <(grep -vE '^[[:space:]]*(#|$)' "$allowlist" | sort -u)

# Compute set difference: observed minus allowed.
disallowed=()
for cmd in "${observed[@]}"; do
  hit=false
  for a in "${allowed[@]}"; do
    if [ "$cmd" = "$a" ]; then hit=true; break; fi
  done
  $hit || disallowed+=("$cmd")
done

# Raw blocks and known-bad constructs.
raw_blocks=$(grep -nE '^```\{=latex\}|\\tikz|\\ooalign|\\node\[|\\hidewidth|\\cr( |$)' "$f" || true)

if [ ${#disallowed[@]} -eq 0 ] && [ -z "$raw_blocks" ]; then
  echo "audit-md: clean ($f)"
  exit 0
fi

echo "audit-md: LEAKS in $f"
if [ ${#disallowed[@]} -gt 0 ]; then
  echo "--- commands not in MathJax allowlist ---"
  for cmd in "${disallowed[@]}"; do
    count=$(grep -c "\\\\$cmd\\b" "$f" || true)
    printf '  %4d  \\%s\n' "$count" "$cmd"
  done | sort -k1 -rn | head -30
fi
if [ -n "$raw_blocks" ]; then
  echo "--- raw LaTeX blocks ---"
  echo "$raw_blocks" | head -10
fi
exit 1
