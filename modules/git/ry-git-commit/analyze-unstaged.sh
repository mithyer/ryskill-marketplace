#!/usr/bin/env bash
set -euo pipefail

repo_path="${1:-.}"
start_index="${2:-1}"
index="$start_index"

generic_dirs='src app lib test tests spec specs scripts bin cmd internal modules'

to_kebab_case() {
  local value="$1"
  value="${value//_/ }"
  value="$(printf '%s' "$value" | sed -E 's/([[:lower:][:digit:]])([[:upper:]])/\1 \2/g')"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  printf '%s\n' "$value"
}

is_generic_dir() {
  local dir="$1"
  local item
  for item in $generic_dirs; do
    [[ "$dir" == "$item" ]] && return 0
  done
  return 1
}

derive_scope() {
  local file="$1"
  local dir_path="${file%/*}"
  local candidate=""
  local segment

  [[ "$dir_path" == "$file" ]] && return 0

  IFS='/' read -r -a segments <<< "$dir_path"
  for (( idx=${#segments[@]}-1; idx>=0; idx-- )); do
    segment="${segments[$idx]}"
    [[ -z "$segment" ]] && continue
    candidate="$(to_kebab_case "$segment")"
    [[ -z "$candidate" ]] && continue
    if ! is_generic_dir "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  for (( idx=${#segments[@]}-1; idx>=0; idx-- )); do
    segment="${segments[$idx]}"
    [[ -z "$segment" ]] && continue
    candidate="$(to_kebab_case "$segment")"
    [[ -n "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done
}

derive_subject() {
  local file="$1"
  local base stem
  base="${file##*/}"
  stem="${base%.*}"
  [[ "$base" == "$stem" ]] || true
  printf 'update %s\n' "$stem"
}

build_message() {
  local file="$1"
  local scope subject
  scope="$(derive_scope "$file")"
  subject="$(derive_subject "$file")"
  if [[ -n "$scope" ]]; then
    printf 'fix(%s): %s\n' "$scope" "$subject"
  else
    printf 'fix: %s\n' "$subject"
  fi
}

git -C "$repo_path" status --porcelain --untracked-files=all | while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  file="${line:3}"
  [[ -z "$file" ]] && continue
  [[ "${line:1:1}" == " " || "${line:0:2}" == "??" ]] || continue
  message="$(build_message "$file")"
  echo "[unstaged]|$index|$message|$file"
  index=$((index + 1))
done
