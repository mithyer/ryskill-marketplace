#!/usr/bin/env bash
set -euo pipefail

staged=()
unstaged=()

while IFS='|' read -r bucket index message files; do
  [[ -z "$bucket" ]] && continue
  line="$bucket|$index|$message|${files//,/, }"
  if [[ "$bucket" == "[staged]" ]]; then
    staged+=("$line")
  else
    unstaged+=("$line")
  fi
done

if [[ ${#staged[@]} -gt 0 ]]; then
  echo "Staged candidates"
  for item in "${staged[@]}"; do
    IFS='|' read -r bucket index message files <<<"$item"
    echo "$bucket $index. $message"
    echo "Files: $files"
  done
fi

if [[ ${#unstaged[@]} -gt 0 ]]; then
  echo "Unstaged candidates"
  for item in "${unstaged[@]}"; do
    IFS='|' read -r bucket index message files <<<"$item"
    echo "$bucket $index. $message"
    echo "Files: $files"
  done
fi
