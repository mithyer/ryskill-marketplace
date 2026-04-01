#!/usr/bin/env bash
set -euo pipefail

repo_path="${1:-.}"
start_index="${2:-1}"
index="$start_index"

git -C "$repo_path" diff --name-only | while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  echo "[unstaged]|$index|refactor: review unstaged change in $file|$file"
  index=$((index + 1))
done
