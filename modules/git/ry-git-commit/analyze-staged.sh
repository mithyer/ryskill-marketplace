#!/usr/bin/env bash
set -euo pipefail

repo_path="${1:-.}"
index=1

git -C "$repo_path" diff --cached --name-only | while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  echo "[staged]|$index|refactor: review staged change in $file|$file"
  index=$((index + 1))
done
