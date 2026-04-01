# ryskill Marketplace

Marketplace index repository for discovering and installing `ryskill` in Claude Code.

## Installation

### Claude Code (via Plugin Marketplace)

Register the marketplace first:

```bash
/plugin marketplace add mithyer/ryskill-marketplace
```

Then install the plugin:

```bash
/plugin install ryskill@ryskill-marketplace
```

## What lives here

This repository is the marketplace index/listing for `ryskill`.
It exists to publish marketplace metadata and point Claude Code at the canonical plugin source repository.

## Canonical plugin source

The actual plugin manifest, commands, runtime helpers, and development history live in:

- `https://github.com/mithyer/ryskill`

## Status

This repository is intentionally lightweight and does not duplicate the plugin implementation.
Marketplace behavior for pointer-based plugin sources is being validated experimentally.
