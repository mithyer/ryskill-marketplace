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

## Repo responsibilities

This repository exists to publish the installable marketplace distribution for `ryskill`.
It contains the plugin manifest, commands, runtime helpers, and marketplace metadata in the layout Claude Code expects for marketplace installation.

The canonical development repository and source of truth live in:

- `https://github.com/mithyer/ryskill`

That source repository is where ongoing development, history, and implementation changes should happen first. This marketplace repository is the distribution/publishing mirror used so marketplace installs work reliably.
