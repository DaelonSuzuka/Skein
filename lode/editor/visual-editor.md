# Visual Editor

Skein provides a custom Godot main-screen panel for visually editing conversations as node graphs. The editor is a `Control` (`SkeinEditor`) that coordinates a file tree, a graph canvas, and a live dialog preview.

## Components

```mermaid
flowchart TB
    SE[SkeinEditor] --> CT[ConversationTree]
    SE --> GE[GraphEdit]
    SE --> DB[DialogBox Preview]
    GE --> BN[BaseNode]
    GE --> DN[DialogNode]
    GE --> CN[CommentNode]
    GE --> EN[EntryNode]
    GE --> JN[JumpNode]
    GE --> BN2[BranchNode]
    GE --> SN[SubgraphNode]
    GE --> XN[ExitNode]
```

### SkeinEditor

- Coordinates the left panel (`ConversationTree`), the center graph (`GraphEdit`), and the right inspector/`DialogBox` preview.
- Handles folder and conversation CRUD, node focus, and preview playback.
- `save_conversation()` serializes the graph via `GraphEdit.get_nodes()` and calls `Skein.save_conversation()`.
- Editor state (zoom, panel sizes, current conversation, minimap, snap settings) is persisted to `user://skein/editor_data.json`.
- `autosave()` is wired to a Timer.
- `really_delete_conversation()` is now fully implemented (previously a `pass` stub).

### GraphEdit

- Extends Godot's `GraphEdit` with custom node creation, deletion, copy/paste, and zoom handling.
- Emits `zoom_changed(zoom)` when the mouse wheel is used, allowing nodes (e.g., `CommentNode`) to react.

| Node Type | Scene | Key Features |
|-----------|-------|--------------|
| `dialog` | `DialogNode.tscn` | TextEdit, up to 4 conditional choices (`show_choices`), right-slot connections |
| `entry` | `EntryNode.tscn` | Starting point; no special UI |
| `exit` | `ExitNode.tscn` | End-of-conversation marker |
| `branch` | `BranchNode.tscn` | Condition field per output slot |
| `comment` | `CommentNode.tscn` | `GraphFrame`-based group node; draggable container for other nodes; color picker; zoom-aware tooltip |
| `jump` | `JumpNode.tscn` | Target node reference for non-linear jumps |
| `subgraph` | `SubgraphNode.tscn` | Embed another conversation as a sub-graph |

### BaseNode

Abstract base class extending `GraphElement` (not `GraphFrame` — `CommentNode` is the only `GraphFrame`). Provides:
- `data` dict with common fields: `id`, `type`, `name`, `text`, `next`, `default`, `position`, `connections`
- `slot_colors` array for connection coloring
- `get_data()` / `set_data()` serialization round-trip with `var_to_str`/`str_to_var` for `Rect2` data
- Title-bar context menu: **Default** toggle, **Play**, **Copy Path/Name/ID**, **Delete**
- `play_request` signal (added in recent commits) allows playing a specific node from its context menu

### DialogNode

- `Choices` menu toggles `show_choices`; when on, right slots 1-4 are enabled for choice connections.
- Choice data lives in `data['choices']` keyed by slot number `1..4`.

### CommentNode

- Extends `GraphFrame`, making it a container node.
- Features:
  - Color picker (`BGColor`) that updates `tint_color`
  - **`zoom_changed(zoom)`** handler: hides/shows a tooltip label when zoom drops below `0.5`
  - **Group drag**: when a `CommentNode` is dragged, any fully enclosed nodes move with it (`drag_children` map computed in `begin_move()`)
  - `resize_request` support with snapping

### LabelEdit

- A reusable `Control` node used inside graph nodes for inline title editing.
- Double-click a `Label` to switch to a `LineEdit`.
- **Escape** rejects changes; **Enter** accepts.
- Proper `@onready` behavior initialized in `_ready()`.

## Serialization Round-Trip

```mermaid
flowchart LR
    A[Disk .yarn/.json] -- load_conversation --> B[Dictionary]
    B -- set_nodes --> C[GraphEdit nodes]
    C -- get_nodes --> D[Dictionary]
    D -- save_conversation --> A
```

- `GraphEdit.get_nodes()` iterates `nodes` dict, validates instances, and calls `node.get_data()`.
- `BaseNode.get_data()` converts `position_offset` and `size` into `Rect2` via `var_to_str` for portability.
- `BaseNode.set_data()` decodes `position` (new) or `position_offset` + `size` (legacy) fields.

## Standalone Capability

The editor is designed to run outside the Godot editor plugin as a standalone application (e.g. for writers who don't use Godot). The `plugin` property on `SkeinEditor` is nullable — the `_ready()` guard skips init only when `Engine.is_editor_hint() and !plugin`. When `plugin` is null, the only loss is the "Set as Preferred Editor" menu item (line 54 is guarded by `if plugin:`).

`SkeinInspectorPlugin` is the one component that *truly* requires the Godot editor — it extends `EditorInspectorPlugin` and calls `plugin.get_editor_interface().get_editor_main_screen()`. But it's a wholly separate registration in `plugin.gd`, not part of the `SkeinEditor.tscn` scene tree.

### Headless Testing (Verified ✅)

Godot 4.6 `--headless` instantiates the full scene tree and allows `Control` nodes to function — it just skips rendering. This was verified with exploratory tests:

- `SkeinEditor.tscn` instantiates and `add_child` works
- `%GraphEdit` and `%Tree` unique-name nodes are accessible
- `load_conversation()` sets `current_conversation` and populates the graph
- `GraphEdit.create_node()` / `get_nodes()` data round-trip works

Confirmed by 13 existing renderer tests that instantiate `.tscn` Control scenes, call `add_child`, and read back `.text` from `RichTextLabel` — all passing in `--headless`.

**Limitation:** visual rendering and input events are absent. Tests can check data flow and state, but not pixel output or mouse interaction.

**Orphan note:** tests leave `DialogTimer` orphans because `queue_free()` on the editor doesn't cleanly free the preview DialogBox's timers. Minor, not a blocker.

### Editor Smoke Tests

`tests/editor_smoke.test.gd` — 9 tests that catch structural regressions:
- Scene tree integrity (3 tests): `%GraphEdit`, `%Tree`, `%DialogBox` nodes exist
- Conversation loading (3 tests): `load_conversation` sets current, populates graph, serialization round-trips with `type`/`name` fields
- Graph create/clear (2 tests): `create_node` + `get_nodes()` round-trip, `clear()` empties graph

These test that the editor *boots and loads content*, not specific UI behavior.

## Related Lodes
- [core-architecture.md](../core/core-architecture.md) — how `SkeinSingleton` loads/saves conversations
- [dialog-runtime.md](../dialog/dialog-runtime.md) — how the graph content is interpreted at runtime
