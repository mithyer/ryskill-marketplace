---
name: ry-git-commit
description: Split staged and unstaged changes into commit candidates and commit a selected transaction safely.
---
> Experimental notice: this initial marketplace release validates installation packaging. The command implementation still depends on an early local verification flow and may require follow-up changes before it works on every machine.

Current phase-1 local verification contract: when this plugin is loaded via `--plugin-dir` from `/Users/ray/Documents/projects/ryskill/.worktrees/ry-git-commit`, use the fixed local helper root below because the interactive slash-command Bash body does not currently receive `CLAUDE_COMMAND_FILE` or any other reliable plugin-root runtime variable for this flow.

```bash
plugin_root="/Users/ray/Documents/projects/ryskill/.worktrees/ry-git-commit"
if [ ! -d "$plugin_root" ]; then
  printf 'ry-git-commit: expected local verification plugin root is missing (%s)\n' "$plugin_root" >&2
  exit 1
fi
```

Use the helpers in this order for the current local verification path:
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
