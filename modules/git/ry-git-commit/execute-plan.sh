#!/usr/bin/env bash
# Bash-only entrypoint. Invoke with bash or execute directly; do not run with sh.
set -euo pipefail

if [[ -z "${BASH_VERSION:-}" ]]; then
  printf '%s\n' 'error=unsupported_shell' >&2
  printf '%s\n' 'failed_phase=bootstrap' >&2
  exit 1
fi

if [[ $# -ne 2 ]]; then
  printf '%s\n' 'error=usage' >&2
  printf '%s\n' 'failed_phase=bootstrap' >&2
  printf '%s\n' 'usage=bash execute-plan.sh <repo-path> <plan-file>' >&2
  exit 1
fi

repo_path="$1"
plan_file="$2"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=modules/git/ry-git-commit/execute-plan-lib.sh
source "$script_dir/execute-plan-lib.sh"

declare -a RY_GIT_COMMIT_PLAN_BUCKETS=()
declare -a RY_GIT_COMMIT_PLAN_CANDIDATES=()
declare -a RY_GIT_COMMIT_PLAN_MESSAGES=()
declare -a RY_GIT_COMMIT_PLAN_FILES=()

if ry_git_commit_plan_is_empty "$plan_file"; then
  ry_git_commit_emit_error "empty_execution_plan" "validate"
  exit 1
fi

if ! validation_output="$(ry_git_commit_validate_no_duplicate_files_in_bucket "$plan_file")"; then
  if [[ -n "$validation_output" ]]; then
    printf '%s\n' "$validation_output" >&2
  else
    ry_git_commit_emit_error "unknown_validation_error" "validate"
  fi
  exit 1
fi

if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ry_git_commit_emit_error "invalid_repo" "validate"
  ry_git_commit_emit_kv "repo_path" "$repo_path"
  exit 1
fi

rescue_dir="$(mktemp -d "${TMPDIR:-/tmp}/ry-git-commit-rescue.XXXXXX")"
validation_output_file="$rescue_dir/parse-validation.out"
if ! ry_git_commit_parse_plan "$plan_file" >"$validation_output_file"; then
  if [[ -s "$validation_output_file" ]]; then
    while IFS= read -r parse_line || [[ -n "$parse_line" ]]; do
      printf '%s\n' "$parse_line" >&2
    done < "$validation_output_file"
  else
    ry_git_commit_emit_error "unknown_validation_error" "validate"
  fi
  rm -f "$validation_output_file"
  exit 1
fi
rm -f "$validation_output_file"

staged_files="$(ry_git_commit_collect_changed_files "$repo_path" staged)"
unstaged_files="$(ry_git_commit_collect_changed_files "$repo_path" unstaged)"
selected_staged_files=""
selected_unstaged_files=""
unselected_staged_files=""
unselected_unstaged_files=""
restored_unselected_changes="no"
missing_file=""
committed_candidates=""
restoration_mode="unselected_only"

for i in "${!RY_GIT_COMMIT_PLAN_BUCKETS[@]}"; do
  bucket="${RY_GIT_COMMIT_PLAN_BUCKETS[$i]}"
  files="${RY_GIT_COMMIT_PLAN_FILES[$i]}"

  if [[ "$bucket" == "[staged]" ]]; then
    while IFS= read -r file_path; do
      ry_git_commit_append_unique_line "$file_path" selected_staged_files
    done <<< "$files"
  else
    while IFS= read -r file_path; do
      ry_git_commit_append_unique_line "$file_path" selected_unstaged_files
    done <<< "$files"
  fi
done

if [[ -n "$selected_staged_files" ]] && ! ry_git_commit_lines_subset "$selected_staged_files" "$staged_files" missing_file; then
  ry_git_commit_emit_error "selected_files_not_present_in_bucket" "snapshot"
  ry_git_commit_emit_kv "bucket" "[staged]"
  ry_git_commit_emit_kv "file" "$missing_file"
  ry_git_commit_emit_kv "rescue_dir" "$rescue_dir"
  exit 1
fi

if [[ -n "$selected_unstaged_files" ]] && ! ry_git_commit_lines_subset "$selected_unstaged_files" "$unstaged_files" missing_file; then
  ry_git_commit_emit_error "selected_files_not_present_in_bucket" "snapshot"
  ry_git_commit_emit_kv "bucket" "[unstaged]"
  ry_git_commit_emit_kv "file" "$missing_file"
  ry_git_commit_emit_kv "rescue_dir" "$rescue_dir"
  exit 1
fi

while IFS= read -r file_path; do
  [[ -n "$file_path" ]] || continue
  if [[ $'\n'"$selected_staged_files"$'\n' != *$'\n'"$file_path"$'\n'* ]]; then
    ry_git_commit_append_unique_line "$file_path" unselected_staged_files
  fi
done <<< "$staged_files"

while IFS= read -r file_path; do
  [[ -n "$file_path" ]] || continue
  if [[ $'\n'"$selected_unstaged_files"$'\n' != *$'\n'"$file_path"$'\n'* ]]; then
    ry_git_commit_append_unique_line "$file_path" unselected_unstaged_files
  fi
done <<< "$unstaged_files"

ry_git_commit_lines_to_array "$selected_staged_files"
selected_staged_array=("${RY_GIT_COMMIT_LINE_ARRAY[@]}")
ry_git_commit_lines_to_array "$selected_unstaged_files"
selected_unstaged_array=("${RY_GIT_COMMIT_LINE_ARRAY[@]}")
ry_git_commit_lines_to_array "$unselected_staged_files"
unselected_staged_array=("${RY_GIT_COMMIT_LINE_ARRAY[@]}")
ry_git_commit_lines_to_array "$unselected_unstaged_files"
unselected_unstaged_array=("${RY_GIT_COMMIT_LINE_ARRAY[@]}")

ry_git_commit_write_patch_for_files "$repo_path" staged "$rescue_dir/selected-staged.patch" "${selected_staged_array[@]}"
ry_git_commit_write_patch_for_files "$repo_path" unstaged "$rescue_dir/selected-unstaged.patch" "${selected_unstaged_array[@]}"
ry_git_commit_write_patch_for_files "$repo_path" staged "$rescue_dir/unselected-staged.patch" "${unselected_staged_array[@]}"
ry_git_commit_write_patch_for_files "$repo_path" unstaged "$rescue_dir/unselected-unstaged.patch" "${unselected_unstaged_array[@]}"

git -C "$repo_path" diff --cached --binary > "$rescue_dir/original-staged.patch"
printf '%s\n' "$staged_files" > "$rescue_dir/original-staged-files.txt"
git -C "$repo_path" diff --binary > "$rescue_dir/original-unstaged.patch"

for i in "${!RY_GIT_COMMIT_PLAN_BUCKETS[@]}"; do
  bucket="${RY_GIT_COMMIT_PLAN_BUCKETS[$i]}"
  files="${RY_GIT_COMMIT_PLAN_FILES[$i]}"
  ry_git_commit_lines_to_array "$files"
  candidate_files=("${RY_GIT_COMMIT_LINE_ARRAY[@]}")

  case "$bucket" in
    "[staged]")
      ry_git_commit_write_patch_for_files "$repo_path" staged "$rescue_dir/candidate-$i-staged.patch" "${candidate_files[@]}"
      ;;
    "[unstaged]")
      ry_git_commit_write_patch_for_files "$repo_path" unstaged "$rescue_dir/candidate-$i-unstaged.patch" "${candidate_files[@]}"
      ;;
    *)
      ry_git_commit_emit_error "unsupported_bucket" "snapshot"
      ry_git_commit_emit_kv "bucket" "$bucket"
      ry_git_commit_emit_kv "candidate" "${RY_GIT_COMMIT_PLAN_CANDIDATES[$i]}"
      ry_git_commit_emit_kv "rescue_dir" "$rescue_dir"
      exit 1
      ;;
  esac
done

ry_git_commit_reset_repo_to_head "$repo_path"

for i in "${!RY_GIT_COMMIT_PLAN_BUCKETS[@]}"; do
  bucket="${RY_GIT_COMMIT_PLAN_BUCKETS[$i]}"
  candidate="${RY_GIT_COMMIT_PLAN_CANDIDATES[$i]}"
  message="${RY_GIT_COMMIT_PLAN_MESSAGES[$i]}"
  files="${RY_GIT_COMMIT_PLAN_FILES[$i]}"
  ry_git_commit_lines_to_array "$files"
  candidate_files=("${RY_GIT_COMMIT_LINE_ARRAY[@]}")

  case "$bucket" in
    "[staged]")
      candidate_patch="$rescue_dir/candidate-$i-staged.patch"
      ry_git_commit_apply_patch "$repo_path" staged "$candidate_patch"
      ;;
    "[unstaged]")
      candidate_patch="$rescue_dir/candidate-$i-unstaged.patch"
      ry_git_commit_apply_patch "$repo_path" unstaged "$candidate_patch"
      git -C "$repo_path" add -- "${candidate_files[@]}"
      ;;
    *)
      restoration_mode="full_snapshot"
      restored_unselected_changes="$(ry_git_commit_restore_snapshot_best_effort "$repo_path" "$rescue_dir")"
      ry_git_commit_emit_error "unsupported_bucket" "commit"
      ry_git_commit_emit_kv "bucket" "$bucket"
      ry_git_commit_emit_kv "candidate" "$candidate"
      ry_git_commit_emit_kv "restoration_mode" "$restoration_mode"
      ry_git_commit_emit_kv "restored_unselected_changes" "$restored_unselected_changes"
      ry_git_commit_emit_kv "rescue_dir" "$rescue_dir"
      exit 1
      ;;
  esac

  if git -C "$repo_path" diff --cached --quiet; then
    restoration_mode="full_snapshot"
    restored_unselected_changes="$(ry_git_commit_restore_snapshot_best_effort "$repo_path" "$rescue_dir")"
    ry_git_commit_emit_error "candidate_produced_no_index_changes" "commit"
    ry_git_commit_emit_kv "candidate" "$candidate"
    ry_git_commit_emit_kv "bucket" "$bucket"
    ry_git_commit_emit_kv "restoration_mode" "$restoration_mode"
    ry_git_commit_emit_kv "restored_unselected_changes" "$restored_unselected_changes"
    ry_git_commit_emit_kv "rescue_dir" "$rescue_dir"
    exit 1
  fi

  commit_output_file="$rescue_dir/candidate-$i.commit.out"
  if ! git -C "$repo_path" commit -m "$message" >"$commit_output_file" 2>&1; then
    restoration_mode="full_snapshot"
    restored_unselected_changes="$(ry_git_commit_restore_snapshot_best_effort "$repo_path" "$rescue_dir")"
    ry_git_commit_emit_error "git_commit_failed" "commit"
    ry_git_commit_emit_kv "candidate" "$candidate"
    ry_git_commit_emit_kv "bucket" "$bucket"
    ry_git_commit_emit_kv "git_commit_output_file" "$commit_output_file"
    ry_git_commit_emit_kv "restoration_mode" "$restoration_mode"
    ry_git_commit_emit_kv "restored_unselected_changes" "$restored_unselected_changes"
    ry_git_commit_emit_kv "rescue_dir" "$rescue_dir"
    exit 1
  fi

  ry_git_commit_append_unique_line "$candidate" committed_candidates
done

if [[ -s "$rescue_dir/unselected-staged.patch" ]]; then
  while IFS= read -r file_path; do
    [[ -n "$file_path" ]] || continue
    git -C "$repo_path" checkout HEAD -- "$file_path"
  done <<< "$unselected_staged_files"
  ry_git_commit_apply_patch "$repo_path" unstaged "$rescue_dir/unselected-staged.patch"
  ry_git_commit_apply_patch "$repo_path" staged "$rescue_dir/unselected-staged.patch"
  restored_unselected_changes="yes"
fi

if [[ -s "$rescue_dir/unselected-unstaged.patch" ]]; then
  ry_git_commit_apply_patch "$repo_path" unstaged "$rescue_dir/unselected-unstaged.patch"
  restored_unselected_changes="yes"
fi

ry_git_commit_emit_kv "result" "ok"
ry_git_commit_emit_kv "committed_candidates" "$(ry_git_commit_join_csv_from_lines "$committed_candidates")"
ry_git_commit_emit_kv "restored_unselected_changes" "$restored_unselected_changes"
ry_git_commit_emit_kv "rescue_dir" "$rescue_dir"
exit 0
