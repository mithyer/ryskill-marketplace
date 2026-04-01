#!/usr/bin/env bash
set -euo pipefail

ry_git_commit_emit_kv() {
  local key="$1"
  local value="$2"

  printf '%s=%s\n' "$key" "$value" >&2
}

ry_git_commit_emit_error() {
  local error_code="$1"
  local failed_phase="$2"

  ry_git_commit_emit_kv "error" "$error_code"
  ry_git_commit_emit_kv "failed_phase" "$failed_phase"
}

ry_git_commit_plan_is_empty() {
  local plan_file="$1"
  [[ ! -s "$plan_file" ]]
}

ry_git_commit_emit_invalid_plan_row() {
  local line_number="$1"
  local line="$2"

  printf 'error=invalid_plan_row\n'
  printf 'failed_phase=validate\n'
  printf 'line_number=%s\n' "$line_number"
  printf 'line=%s\n' "$line"
}

ry_git_commit_trim_whitespace() {
  local value="$1"

  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

ry_git_commit_validate_no_duplicate_files_in_bucket() {
  local plan_file="$1"
  local seen_entries=""
  local raw_line
  local line
  local line_number=0
  local bucket
  local candidate
  local message
  local files_column
  local normalized_files
  local file_path
  local existing_candidate
  local seen_bucket
  local seen_file
  local seen_candidate
  local extra
  local -a file_paths=()

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line_number=$((line_number + 1))
    line="${raw_line%$'\r'}"
    [[ -n "${line//[[:space:]]/}" ]] || continue

    if [[ "$line" != *"|"*"|"*"|"* ]]; then
      ry_git_commit_emit_invalid_plan_row "$line_number" "$line"
      return 1
    fi

    IFS='|' read -r bucket candidate message files_column extra <<< "$line"
    if [[ -n "${extra-}" ]]; then
      ry_git_commit_emit_invalid_plan_row "$line_number" "$line"
      return 1
    fi

    normalized_files=""
    IFS=',' read -ra file_paths <<< "$files_column"
    for file_path in "${file_paths[@]}"; do
      file_path="$(ry_git_commit_trim_whitespace "$file_path")"
      [[ -n "$file_path" ]] || continue
      normalized_files+="$file_path"$'\n'
    done

    if [[ -z "$normalized_files" ]]; then
      ry_git_commit_emit_invalid_plan_row "$line_number" "$line"
      return 1
    fi

    while IFS= read -r file_path; do
      [[ -n "$file_path" ]] || continue
      existing_candidate=""

      while IFS=$'\t' read -r seen_bucket seen_file seen_candidate; do
        [[ -n "$seen_bucket" ]] || continue
        if [[ "$seen_bucket" == "$bucket" && "$seen_file" == "$file_path" ]]; then
          existing_candidate="$seen_candidate"
          break
        fi
      done <<< "$seen_entries"

      if [[ -n "$existing_candidate" && "$existing_candidate" != "$candidate" ]]; then
        printf 'error=duplicate_file_in_bucket\n'
        printf 'failed_phase=validate\n'
        printf 'bucket=%s\n' "$bucket"
        printf 'file=%s\n' "$file_path"
        printf 'first_candidate=%s\n' "$existing_candidate"
        printf 'second_candidate=%s\n' "$candidate"
        return 1
      fi

      if [[ -z "$existing_candidate" ]]; then
        seen_entries+="$bucket"$'\t'"$file_path"$'\t'"$candidate"$'\n'
      fi
    done <<< "$normalized_files"
  done < "$plan_file"
}

ry_git_commit_append_unique_line() {
  local value="$1"
  local list_name="$2"

  [[ -n "$value" ]] || return 0
  local current_list
  current_list="${!list_name-}"

  if [[ $'\n'"$current_list"$'\n' != *$'\n'"$value"$'\n'* ]]; then
    printf -v "$list_name" '%s%s\n' "$current_list" "$value"
  fi
}

ry_git_commit_join_csv_from_lines() {
  local input="$1"
  local joined=""
  local line

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ -z "$joined" ]]; then
      joined="$line"
    else
      joined+=",$line"
    fi
  done <<< "$input"

  printf '%s' "$joined"
}

ry_git_commit_parse_plan() {
  local plan_file="$1"
  local raw_line
  local line
  local line_number=0
  local bucket
  local candidate
  local message
  local files_column
  local extra
  local normalized_files
  local file_path
  local -a file_paths=()

  RY_GIT_COMMIT_PLAN_BUCKETS=()
  RY_GIT_COMMIT_PLAN_CANDIDATES=()
  RY_GIT_COMMIT_PLAN_MESSAGES=()
  RY_GIT_COMMIT_PLAN_FILES=()

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line_number=$((line_number + 1))
    line="${raw_line%$'\r'}"
    [[ -n "${line//[[:space:]]/}" ]] || continue

    if [[ "$line" != *"|"*"|"*"|"* ]]; then
      ry_git_commit_emit_invalid_plan_row "$line_number" "$line"
      return 1
    fi

    IFS='|' read -r bucket candidate message files_column extra <<< "$line"
    if [[ -n "${extra-}" ]]; then
      ry_git_commit_emit_invalid_plan_row "$line_number" "$line"
      return 1
    fi

    case "$bucket" in
      "[staged]"|"[unstaged]") ;;
      *)
        ry_git_commit_emit_error "unsupported_bucket" "validate"
        ry_git_commit_emit_kv "bucket" "$bucket"
        ry_git_commit_emit_kv "line_number" "$line_number"
        return 1
        ;;
    esac

    if [[ -z "$message" ]]; then
      ry_git_commit_emit_error "missing_commit_message" "validate"
      ry_git_commit_emit_kv "candidate" "$candidate"
      ry_git_commit_emit_kv "line_number" "$line_number"
      return 1
    fi

    normalized_files=""
    IFS=',' read -ra file_paths <<< "$files_column"
    for file_path in "${file_paths[@]}"; do
      file_path="$(ry_git_commit_trim_whitespace "$file_path")"
      [[ -n "$file_path" ]] || continue
      normalized_files+="$file_path"$'\n'
    done

    if [[ -z "$normalized_files" ]]; then
      ry_git_commit_emit_invalid_plan_row "$line_number" "$line"
      return 1
    fi

    RY_GIT_COMMIT_PLAN_BUCKETS+=("$bucket")
    RY_GIT_COMMIT_PLAN_CANDIDATES+=("$candidate")
    RY_GIT_COMMIT_PLAN_MESSAGES+=("$message")
    RY_GIT_COMMIT_PLAN_FILES+=("$normalized_files")
  done < "$plan_file"
}

ry_git_commit_collect_changed_files() {
  local repo_path="$1"
  local mode="$2"
  local file_list

  if [[ "$mode" == "staged" ]]; then
    file_list="$(git -C "$repo_path" diff --cached --name-only)"
  else
    file_list="$(git -C "$repo_path" diff --name-only)"
  fi

  printf '%s' "$file_list"
}

ry_git_commit_lines_subset() {
  local expected="$1"
  local available="$2"
  local missing_var_name="${3-}"
  local line

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ $'\n'"$available"$'\n' != *$'\n'"$line"$'\n'* ]]; then
      if [[ -n "$missing_var_name" ]]; then
        printf -v "$missing_var_name" '%s' "$line"
      fi
      return 1
    fi
  done <<< "$expected"

  return 0
}

ry_git_commit_lines_to_array() {
  local input="$1"
  local line

  RY_GIT_COMMIT_LINE_ARRAY=()
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    RY_GIT_COMMIT_LINE_ARRAY+=("$line")
  done <<< "$input"
}

ry_git_commit_write_patch_for_files() {
  local repo_path="$1"
  local mode="$2"
  local output_file="$3"
  shift 3
  local -a files=("$@")

  if [[ ${#files[@]} -eq 0 || ( ${#files[@]} -eq 1 && -z "${files[0]}" ) ]]; then
    : > "$output_file"
    return 0
  fi

  if [[ "$mode" == "staged" ]]; then
    git -C "$repo_path" diff --cached --binary -- "${files[@]}" > "$output_file"
  else
    git -C "$repo_path" diff --binary -- "${files[@]}" > "$output_file"
  fi
}

ry_git_commit_apply_patch() {
  local repo_path="$1"
  local mode="$2"
  local patch_file="$3"

  [[ -s "$patch_file" ]] || return 0

  if [[ "$mode" == "staged" ]]; then
    git -C "$repo_path" apply --cached --whitespace=nowarn "$patch_file"
  else
    git -C "$repo_path" apply --whitespace=nowarn "$patch_file"
  fi
}

ry_git_commit_reset_repo_to_head() {
  local repo_path="$1"
  git -C "$repo_path" reset --hard HEAD >/dev/null
}

ry_git_commit_restore_snapshot_best_effort() {
  local repo_path="$1"
  local rescue_dir="$2"
  local restored_any="no"

  if [[ -f "$rescue_dir/original-staged-files.txt" ]]; then
    while IFS= read -r file_path; do
      [[ -n "$file_path" ]] || continue
      git -C "$repo_path" checkout HEAD -- "$file_path" >/dev/null 2>&1 || true
    done < "$rescue_dir/original-staged-files.txt"
  fi

  if [[ -s "$rescue_dir/original-staged.patch" ]]; then
    if git -C "$repo_path" apply --whitespace=nowarn "$rescue_dir/original-staged.patch" >/dev/null 2>&1; then
      :
    fi
    if git -C "$repo_path" apply --cached --whitespace=nowarn "$rescue_dir/original-staged.patch" >/dev/null 2>&1; then
      restored_any="yes"
    fi
  fi

  if [[ -s "$rescue_dir/original-unstaged.patch" ]]; then
    if git -C "$repo_path" apply --whitespace=nowarn "$rescue_dir/original-unstaged.patch" >/dev/null 2>&1; then
      restored_any="yes"
    fi
  fi

  printf '%s' "$restored_any"
}
