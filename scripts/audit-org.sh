#!/usr/bin/env bash
# Audit a .org export. Same allowlist as md (MathJax-compatible). Also
# flags raw #+BEGIN_EXPORT latex blocks containing unsupported macros.
# Usage:  scripts/audit-org.sh <path/to/file.org>
set -uo pipefail
f="${1:?usage: audit-org.sh <file.org>}"
dir="$(dirname "${BASH_SOURCE[0]}")"
allowlist="$dir/allowlist-md.txt"
[ -f "$allowlist" ] || { echo "audit-org: missing $allowlist" >&2; exit 2; }
[ -s "$f" ] || { echo "audit-org: empty or missing $f" >&2; exit 2; }

mapfile -t observed < <(grep -oE '\\[A-Za-z@]+' "$f" | sed 's/^\\//' | sort -u)
mapfile -t allowed < <(grep -vE '^[[:space:]]*(#|$)' "$allowlist" | sort -u)

disallowed=()
for cmd in "${observed[@]}"; do
  hit=false
  for a in "${allowed[@]}"; do
    if [ "$cmd" = "$a" ]; then hit=true; break; fi
  done
  $hit || disallowed+=("$cmd")
done

raw_blocks=$(grep -nE '^#\+BEGIN_EXPORT latex|\\tikz|\\ooalign|\\node\[|\\hidewidth|\\cr( |$)' "$f" || true)

if [ ${#disallowed[@]} -eq 0 ] && [ -z "$raw_blocks" ]; then
  echo "audit-org: clean ($f)"
  exit 0
fi

echo "audit-org: LEAKS in $f"
if [ ${#disallowed[@]} -gt 0 ]; then
  echo "--- commands not in allowlist ---"
  for cmd in "${disallowed[@]}"; do
    count=$(grep -c "\\\\$cmd\\b" "$f" || true)
    printf '  %4d  \\%s\n' "$count" "$cmd"
  done | sort -k1 -rn | head -30
fi
if [ -n "$raw_blocks" ]; then
  echo "--- raw LaTeX export blocks / unsupported tokens ---"
  echo "$raw_blocks" | head -10
fi
exit 1
