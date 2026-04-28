# File & Data Formats

Skein persists conversations in either JSON (legacy) or a custom Yarn text format. Characters are standard Godot `.tscn` scenes.

## Yarn Format

A file contains one or more nodes separated by `---` (header/body delimiter) and `===` (node terminator).

```text
title: Start
type: dialog
id: 42
---
Character: Hello world!
-> Choice 1 => NodeA
-> Choice 2 => NodeB
===

title: NodeA
---
More text here.
===
```

Header fields become keys in the node dictionary. `title` is renamed back to `name` at load time.  
Runtime-only keys (`size`, `offset`) are stripped before saving.

## JSON Format

Same node dictionary structure stored via `JSON.stringify(data, '\t', true)`.

## Node Dictionary Schema

```gdscript
{
    id = int,
    type = String,       # "dialog" | "branch" | "entry" | ...
    name = String,
    text = String,       # raw multiline dialog text
    next = String,       # "none" | "choice" | node_id
    choices = {          # optional, only when show_choices == true
        "1": { choice="", condition="", next="" },
        ...
    },
    branches = {        # optional, for branch-type nodes
        "1": { condition="", next="" },
        ...
    },
    connections = {},    # runtime GraphEdit connection map
    size = Vector2,      # editor only (stripped on save)
    offset = Vector2,    # editor only (stripped on save)
}
```

## Conversion Utilities

`Yarn.gd` provides:
- `save_yarn(path, data)` — writes dictionary to disk in Yarn format
- `load_yarn(path)` — reads Yarn file back into node dictionary
- `convert_nodes_to_yarn(data)` — serializes; uses `var_to_str` for nested dicts (`choices`, `branches`, `connections`)

`Files.gd` provides:
- `save_json(path, data)` / `load_json(path, default)` — JSON I/O

## Path Conventions

- Conversations live under `res://conversations/` (or `user://conversations/` on HTML5).
- Characters live under `res://characters/` as `.tscn` files.
- `SkeinConversation` resource stores `file:node:line` references for Inspectors.

## Related Lodes
- [core-architecture.md](../core/core-architecture.md) — how files are scanned and loaded
- [visual-editor.md](../editor/visual-editor.md) — how the graph editor serializes nodes
