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
- Every line of dialog should be writable with zero mouse clicks in the graph editor. The visual programming block approach (e.g., Dialogic) is explicitly rejected — it makes rapid authoring agonizing.

## Bring-Your-Own-X and Sane On-Disk Formats
- DialogBox is a template, not a prison. Game devs own the UI.
- Characters are `.tscn` files in a directory — no proprietary registry format, no walled-garden editor UI.
- Skein provides the runtime engine and effect stream; the renderer is the game's responsibility.
- All on-disk data must be human-readable, diffable, and editable in a plain text editor. No binary blobs, no proprietary JSON schemas that only the editor can parse.
- If a user wants to create or modify data outside the Godot editor (VSCode, Vim, scripts, CI), that must work perfectly. The editor is optional.
- **Never reinvent what Godot already does well.** The game developer already has a purpose-built best-in-class editor for laying out Control nodes — it's the Godot editor. Don't build a dialog box style editor. Don't build a node layout inspector. If it's a `.tscn` scene, the user edits it in Godot's scene editor. Period.

## Namespace Hygiene
- All `class_name` declarations in Skein must be prefixed with `Skein` (e.g., `SkeinCharacter`, `SkeinEngine`). Godot has one global class namespace — squatting common names like `Config`, `Character`, or `Engine` is hostile to users and other plugins.

## File I/O
- Use `Files.prefix` (`user://` on HTML5, otherwise `res://`) for all read/write paths.
- `Files.save_json` / `Files.load_json` handle `null`/`{}` guards and auto-append extensions.
- `Yarn.save_yarn` / `Yarn.load_yarn` strip runtime-only keys (`size`, `offset`) before serializing.
- `.gitattributes` enforces LF line endings for all text formats. The Yarn parser strips `\r` defensively (`text.replace('\r', '').split('\n')`) so CRLF files from external sources won't break parsing.
- `res://` paths always use `/` separators in Godot, so `split('/')` is safe for `res://` paths. OS-native paths from `globalize_path` may use `\` on Windows — use `path_join()` or Godot path utilities instead of string splitting.
- Extension checks use `to_lower()` comparison to handle case variation across platforms (`.JSON` on Windows, `.json` on Linux).

## Code Execution
- Expressions inside `{ }` are executed silently; `{{ }}` prints the result.
- `Sandbox.get_context()` builds a temporary GDScript node with injected helpers (`jump`, `speed`, `timer`).
- Assignment inside expressions is gated by `Sandbox._assignment_enabled` and detected via regex.

## Dialog Runtime
- `DialogEngine` is the stateful conversation interpreter; renderers consume the effect stream.
- Inline choices are denoted by `-` or `->` markers. Conditional choices hide the option but still create the button (disabled).
- Choice bodies (indented lines after `->`) create dynamic nodes at runtime.
- Branch nodes (`type: branch`) evaluate conditions and route to the first matching branch.
- `<<jump NodeName>>` is a directive parsed during text scan; emits DIRECTIVE effect.
- `jump()` can be called from expressions but should use `{ }` (silent), not `{{ }}` — returns null which would print in display text.
- `exec=false` suppresses expression evaluation: `{ }` and `{{ }}` blocks are left as literal text (emitted as INSTANT effects), not erased — critical for graph editor preview where `caller`/`scene` aren't available.

## Node Graph
- Each graph node stores `data` dict with `id`, `name`, `type`, `text`, `choices`, `branches`, `connections`, etc.
- `GraphEdit.get_nodes()` serializes the graph back into the dictionary format saved to disk.
- Editor data (zoom, panel sizes, current conversation) is persisted separately in `user://skein/editor_data.json`.
- Use `path_join()` not deprecated `plus_file()` for path concatenation.
