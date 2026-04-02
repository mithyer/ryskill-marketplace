# ryskill Marketplace

Installable marketplace distribution for the `ryskill` Claude Code plugin.

## Installation

### Claude Code (via Plugin Marketplace)

Register the marketplace first:

```bash
claude plugins marketplace add mithyer/ryskill-marketplace
```

Then install the plugin:

```bash
claude plugins install ryskill@ryskill-marketplace
```

## Command

- `/ry:git-commit`

The distributed command resolves its plugin root from the installed command file via `runtime/plugin-root.sh`, so the same command definition works after marketplace installation without depending on the user's current working directory.

## Repo responsibilities

This repository exists to publish the installable marketplace distribution for `ryskill`.
It contains the plugin manifest, commands, runtime helpers, and marketplace metadata in the layout Claude Code expects for marketplace installation.

The canonical development repository and source of truth live in:

- `https://github.com/mithyer/ryskill`

That source repository is where ongoing development, history, and implementation changes should happen first. This marketplace repository is the distribution/publishing mirror used so marketplace installs work reliably.
