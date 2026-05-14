#!/usr/bin/env bash
# Audit a plain-text export for residual LaTeX leakage. Exits 0 iff the
# file contains zero \cmd, $ (paired), and \begin/\end markers.
# Usage:  scripts/audit-txt.sh <path/to/file.txt>
set -uo pipefail
f="${1:?usage: audit-txt.sh <file.txt>}"
if [ ! -s "$f" ]; then echo "audit-txt: empty or missing $f" >&2; exit 2; fi

leaks=$(grep -nE '\\[A-Za-z@]+|\\\\|\$\$|\\begin\{|\\end\{' "$f" || true)
# $-pair check: a line with two unescaped $ on it indicates inline math markers.
dollar_pairs=$(grep -nE '(^|[^\\])\$[^$].*[^\\]\$' "$f" || true)

if [ -z "$leaks" ] && [ -z "$dollar_pairs" ]; then
  echo "audit-txt: clean ($f)"
  exit 0
fi

echo "audit-txt: LEAKS in $f"
if [ -n "$leaks" ]; then
  echo "--- backslash / begin/end / \$\$ ---"
  echo "$leaks" | head -25
  echo "[$( echo "$leaks" | wc -l) total lines]"
  echo "--- frequency table ---"
  echo "$leaks" | grep -oE '\\[A-Za-z@]+' | sort | uniq -c | sort -rn | head -25
fi
if [ -n "$dollar_pairs" ]; then
  echo "--- inline \$…\$ pairs ---"
  echo "$dollar_pairs" | head -10
fi
exit 1
