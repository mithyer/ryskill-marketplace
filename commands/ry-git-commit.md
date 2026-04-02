---
name: ry:git-commit
description: Split staged and unstaged changes into commit candidates and commit a selected transaction safely.
---

Resolve the installed plugin root at runtime from the command file location so the command works from source, a worktree, or a marketplace install. The command remains explicit slash invocation via `/ry:git-commit`.

First, directly tell the user which changes are currently staged and which are currently unstaged. Then continue into the existing commit flow.

```bash
plugin_root_line=""
plugin_root_helper=""
plugin_cache_root="$HOME/.claude/plugins/cache/ryskill-marketplace/ryskill"
installed_plugin_root=""

if [ -n "${CLAUDE_COMMAND_FILE:-}" ]; then
  command_dir="$(cd "$(dirname "$CLAUDE_COMMAND_FILE")" && pwd)"
  candidate_helper="$command_dir/../runtime/plugin-root.sh"
  if [ -f "$candidate_helper" ]; then
    plugin_root_helper="$candidate_helper"
  fi
elif [ -f "$PWD/plugin.json" ]; then
  for candidate_helper in "$PWD/runtime/plugin-root.sh" "$PWD/../runtime/plugin-root.sh"; do
    if [ -f "$candidate_helper" ]; then
      plugin_root_helper="$candidate_helper"
      break
    fi
  done
fi

if [ -z "$plugin_root_helper" ] && [ -d "$plugin_cache_root" ]; then
  installed_plugin_root="$(python3 - "$plugin_cache_root" <<'PY'
import sys
from pathlib import Path
from packaging.version import Version

root = Path(sys.argv[1])
versions = []
for path in root.iterdir():
    if not path.is_dir():
        continue
    try:
        version = Version(path.name)
    except Exception:
        continue
    if (path / 'plugin.json').is_file() and (path / 'runtime' / 'plugin-root.sh').is_file():
        versions.append((version, path))

if versions:
    versions.sort()
    print(versions[-1][1])
PY
)"
  if [ -n "$installed_plugin_root" ]; then
    candidate_helper="$installed_plugin_root/runtime/plugin-root.sh"
    if [ -f "$candidate_helper" ]; then
      plugin_root_helper="$candidate_helper"
    fi
  fi
fi

if [ -z "$plugin_root_helper" ]; then
  printf 'ry:git-commit: unable to resolve plugin root; CLAUDE_COMMAND_FILE is unset, PWD=%s is not a local plugin checkout, and no installed ryskill plugin was found under $HOME/.claude/plugins/cache/ryskill-marketplace/ryskill\n' "$PWD" >&2
  exit 1
fi

plugin_root_line="$(bash "$plugin_root_helper")"
case "$plugin_root_line" in
  plugin_root=*) plugin_root="${plugin_root_line#plugin_root=}" ;;
  *)
    printf 'ry:git-commit: failed to parse plugin root from %s\n' "$plugin_root_helper" >&2
    exit 1
    ;;
esac

if [ ! -d "$plugin_root" ]; then
  printf 'ry:git-commit: resolved plugin root is not a directory: %s\n' "$plugin_root" >&2
  exit 1
fi
```

Use the helpers in this order after root resolution:
1. `bash "$plugin_root/runtime/project-context.sh" --cwd "$PWD" [--project <project>] [--branch <branch>]` to resolve `project_path` and `branch`
2. `bash "$plugin_root/runtime/git-state.sh" "$project_path"`
3. `bash "$plugin_root/modules/git/ry-git-commit/analyze-staged.sh" "$project_path"`
4. `bash "$plugin_root/modules/git/ry-git-commit/analyze-unstaged.sh" "$project_path"`
5. `bash "$plugin_root/modules/git/ry-git-commit/present-candidates.sh"`
6. `bash "$plugin_root/runtime/selection-parser.sh"` when multiple candidates exist
7. `bash "$plugin_root/modules/git/ry-git-commit/build-execution-plan.sh"`
8. `bash "$plugin_root/modules/git/ry-git-commit/execute-plan.sh" "$project_path" "$plan_file"`

Behavior requirements:
- Analyze staged and unstaged changes separately after resolving `project_path` and validating repository safety.
- First, directly report staged changes and unstaged changes to the user before asking them to choose anything.
- Format that summary as `Staged changes: ...` and `Unstaged changes: ...`.
- When changes exist in a bucket, show numbered candidate lines using the candidate message, then show `Files: ...` on its own line without a leading bullet.
- After presenting the summaries and candidate lines, prompt with exactly: `Select commit numbers, or 0 to over`.
- Invoke runtime and module helpers through `bash` rather than relying on helper execute bits.
- Use the selected candidate message verbatim as the final git commit message.
- If multiple candidates exist, parse the user's selection, and build a plan from that selection.
- Execute the resulting non-empty plan rows in order.
- Preserve any unselected changes.

Supported arguments:
- `--project <project>`
- `--branch <branch>`
