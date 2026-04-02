---
name: ry:git-commit
description: Split staged and unstaged changes into commit candidates and commit a selected transaction safely.
---

Resolve the installed plugin root at runtime from the command file location so the command works from source, a worktree, or a marketplace install.

```bash
if [ -n "${CLAUDE_COMMAND_FILE:-}" ]; then
  command_dir="$(cd "$(dirname "$CLAUDE_COMMAND_FILE")" && pwd)"
  plugin_root="$({ bash "$command_dir/../runtime/plugin-root.sh"; } | sed -n 's/^plugin_root=//p')"
else
  printf 'ry:git-commit: CLAUDE_COMMAND_FILE is required to resolve the plugin root\n' >&2
  exit 1
fi

if [ -z "$plugin_root" ] || [ ! -d "$plugin_root" ]; then
  printf 'ry:git-commit: failed to resolve plugin root via runtime/plugin-root.sh\n' >&2
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
- Invoke runtime and module helpers through `bash` rather than relying on helper execute bits.
- If only one candidate exists, skip selection and commit that candidate directly.
- If multiple candidates exist, present them first, parse the user's selection, and build a plan from that selection.
- Current limitation: execution commits only the first non-empty plan row from the resulting plan.
- Preserve any unselected changes.

Supported arguments:
- `--project <project>`
- `--branch <branch>`
