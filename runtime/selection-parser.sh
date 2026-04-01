#!/usr/bin/env bash
set -euo pipefail

input="${1:-}"
normalized="${input//,/ }"
results=()

for token in $normalized; do
  if [[ "$token" =~ ^[0-9]+-[0-9]+$ ]]; then
    start="${token%-*}"
    end="${token#*-}"

    if (( start > end )); then
      echo "invalid_selection_range=$token" >&2
      exit 1
    fi

    for ((i=start; i<=end; i++)); do
      results+=("$i")
    done
  elif [[ "$token" =~ ^[0-9]+$ ]]; then
    results+=("$token")
  else
    echo "invalid_selection=$token" >&2
    exit 1
  fi
done

printf '%s\n' "${results[@]}" | awk '!seen[$0]++' | sort -n | paste -sd' ' -
