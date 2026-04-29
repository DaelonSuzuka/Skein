# Terminology

- **Conversation** — A dialog script (`.yarn` or `.json`) containing nodes that define speech, choices, branches, and jumps.
- **Node (Graph)** — a visual card in the graph editor representing a chunk of dialog or logic. Types: `dialog`, `branch`, `entry`, `exit`, `comment`, `jump`, `subgraph`.
- **DialogNode** — Graph node that displays text and optional branching choices.
- **EntryNode** — Starting point of a conversation.
- **Branch** — A conditional path within a dialog node; evaluated to determine the `next` node.
- **Yarn format** — Skein-expanded header/body text format (`---`/`===`) for persisting conversation nodes. Not Yarn Spinner.
- **Sandbox** — Runtime `Expression` evaluator that executes code inside `{ }` / `{{ }}` blocks with injected locals.
- **SkeinCanvas** — `CanvasLayer` that hosts the in-game dialog box and popup dialogs.
- **DialogBox** — Default in-game UI control that types out text, handles choices, and emits signals for line/node progression. Intended to be subclassed per-game.
- **Character** — A `.tscn` scene loaded from `res://characters/`; auto-registered by `name` in the singleton. Character management system is incomplete.
- **SkeinEditor** — The `@tool` editor panel integrated into Godot’s main screen for visual conversation editing.
- **GraphEdit** — Custom Godot `GraphEdit` derived component that renders and edits conversation nodes.
- **ConversationTree** — Tree UI showing file/folder hierarchy and node listings.
- **Watcher** — File-system poller that triggers refresh when conversation or character files change.
- **Consulate** — In-game debug console plugin (separate addon).
- **MethodPicker** — WIP inspector `EditorProperty` for picking an object in the scene and then selecting a method from it, replacing the current NodePath + string textbox pattern.
