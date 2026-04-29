# Practices

## Godot Plugin Conventions
- Skein is an `EditorPlugin` with lifecycle hooks (`_enter_tree`, `_exit_tree`).
- Scripts that need editor-time execution use `@tool`.
- The autoload singleton (`Skein`) is registered via `add_autoload_singleton("Skein", ".../SkeinSingleton.tscn")` in `plugin.gd` and removed in `_exit_tree`.
- All UI scenes (`SkeinEditor.tscn`, `PopupDialogBox.tscn`, etc.) are preloaded paths relative to the addon directory.
- Editor-time and runtime logic coexist; be careful with `Engine.is_editor_hint()` where it matters.
- The plugin must not leak nodes or references when disabled — use `remove_autoload_singleton`, free custom nodes, and disconnect editor signals.

## Text-First Authoring
- **The text file is the source of truth.** The visual graph editor is a convenience layer, not a prison.
- Writers can edit `.yarn` files in any text editor and reload inside Godot.
- The Yarn format used by Skein is an **expanded variant**; it is not Yarn Spinner.

## File I/O
- Use `Files.prefix` (`user://` on HTML5, otherwise `res://`) for all read/write paths.
- `Files.save_json` / `Files.load_json` handle `null`/`{}` guards and auto-append extensions.
- `Yarn.save_yarn` / `Yarn.load_yarn` strip runtime-only keys (`size`, `offset`) before serializing.

## Code Execution
- Expressions inside `{ }` are executed silently; `{{ }}` prints the result.
- `Sandbox.get_context()` builds a temporary GDScript node with injected helpers (`jump`, `speed`, `timer`).
- Assignment inside expressions is gated by `Sandbox._assignment_enabled` and detected via regex.

## Dialog Runtime
- `DialogBox` is the default runtime interpreter; games are expected to subclass or replace it for custom UI.
- Inline choices are denoted by `-` or `->` markers. Conditional choices hide the option but still create the button (disabled).
- `<<jump NodeName>>` is a directive parsed during text scan.
- Signals (`line_started`, `node_started`, `done`, etc.) drive editor highlighting and game logic.

## Node Graph
- Each graph node stores `data` dict with `id`, `name`, `type`, `text`, `choices`, `branches`, `connections`, etc.
- `GraphEdit.get_nodes()` serializes the graph back into the dictionary format saved to disk.
- Editor data (zoom, panel sizes, current conversation) is persisted separately in `user://skein/editor_data.json`.
