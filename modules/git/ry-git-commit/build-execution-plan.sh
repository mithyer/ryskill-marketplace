#!/usr/bin/env bash
set -euo pipefail

selected=" "
if [[ $# -gt 0 ]] && [[ -n "${1:-}" ]]; then
  selected=" ${1} "
fi

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  if [[ "$line" == *'|'* ]]; then
    IFS='|' read -r bucket index message files <<<"$line"
    if [[ "$selected" == " " ]] || [[ "$selected" == *" $index "* ]]; then
      printf '%s\n' "$bucket|$index|$message|$files"
    fi
    continue
  fi

  index="$line"
  if [[ "$selected" == *" $index "* ]]; then
    printf '%s\n' "$line"
  fi
done
