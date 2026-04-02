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
  echo "Staged changes:"
  for item in "${staged[@]}"; do
    IFS='|' read -r bucket index message files <<<"$item"
    echo "$index. $message"
    echo "Files: $files"
  done
else
  echo "Staged changes: none"
fi

if [[ ${#unstaged[@]} -gt 0 ]]; then
  echo "Unstaged changes:"
  for item in "${unstaged[@]}"; do
    IFS='|' read -r bucket index message files <<<"$item"
    echo "$index. $message"
    echo "Files: $files"
  done
else
  echo "Unstaged changes: none"
fi
