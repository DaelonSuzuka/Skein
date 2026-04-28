# Practices

## Godot-specific
- All Skein plugin scripts use `@tool` so they run in the editor.
- The plugin registers an autoload singleton named `Skein` via `SkeinSingleton.tscn`.
- Editor UI is built from preloaded scenes (`SkeinEditor.tscn`, `PopupDialogBox.tscn`, etc.).

## File I/O
- Use `Files.prefix` (`user://` on HTML5, otherwise `res://`) for all read/write paths.
- `Files.save_json` / `Files.load_json` handle `null`/`{}` guards and auto-append extensions.
- `Yarn.save_yarn` / `Yarn.load_yarn` strip runtime-only keys (`size`, `offset`) before serializing.

## Code Execution
- Expressions inside `{ }` are executed silently; `{{ }}` prints the result.
- `Sandbox.get_context()` builds a temporary GDScript node with injected helpers (`jump`, `speed`, `timer`).
- Assignment inside expressions is gated by `Sandbox._assignment_enabled` and detected via regex.

## Dialog Runtime
- `DialogBox` is the authoritative runtime interpreter; it handles typing, choices, directives, and evaluation.
- Inline choices are denoted by `-` or `->` markers. Conditional choices hide the option but still create the button (disabled).
- `<<jump NodeName>>` is a directive parsed during text scan.
- Signals (`line_started`, `node_started`, `done`, etc.) drive editor highlighting and game logic.

## Node Graph
- Each graph node stores `data` dict with `id`, `name`, `type`, `text`, `choices`, `branches`, `connections`, etc.
- `GraphEdit.get_nodes()` serializes the graph back into the dictionary format saved to disk.
- Editor data (zoom, panel sizes, current conversation) is persisted separately in `user://skein/editor_data.json`.
