#!/usr/bin/env bash
set -euo pipefail

repo_path="$1"
git_dir="$(git -C "$repo_path" rev-parse --absolute-git-dir)"

if git -C "$repo_path" rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
  echo "unsafe_state=merge_in_progress"
  exit 1
fi

if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
  echo "unsafe_state=rebase_in_progress"
  exit 1
fi

if [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
  echo "unsafe_state=cherry_pick_in_progress"
  exit 1
fi

if git -C "$repo_path" status --porcelain | grep -Eq '^(DD|AU|UD|UA|DU|AA|UU) '; then
  echo "unsafe_state=unresolved_conflicts"
  exit 1
fi

echo "unsafe_state=clean_for_analysis"
