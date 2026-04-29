# Dialog Engine

`DialogEngine` (`addons/skein/engine/DialogEngine.gd`) is the stateful conversation interpreter. It produces a pull-based stream of `DialogEffect` objects via `next_effect()`. Anything that consumes this stream is a renderer — no base class required, just convention.

## Architecture

```mermaid
flowchart LR
    DE[DialogEngine] -->|next_effect| R1[DialogBox]
    DE -->|next_effect| R2[PopupRenderer]
    DE -->|next_effect| R3[SignRenderer]
    DE -->|next_effect| R4[PhoneRenderer]
    R1 -->|advance / choose| DE
    R2 -->|advance / choose| DE
    DE -->|evaluate| SB[Sandbox]
    DE -->|load nodes| SK[SkeinSingleton]
```

## State Machine

| State | Meaning |
|-------|---------|
| `IDLE` | Not started |
| `LINE_ACTIVE` | Scanning `_line` for effects |
| `WAITING_INPUT` | Line fully typed, waiting for user input |
| `CHOOSING` | Choices available, waiting for selection |
| `YIELDING` | Paused for external signal (future) |
| `DONE` | Conversation complete |

## Effect Stream

Renderer calls `next_effect()` repeatedly. The engine has no signals — all communication flows through effects.

### Display Effects (may block renderer loop)

| Type | Value | Renderer Action |
|------|-------|-----------------|
| `CHAR` | Single character | Type one char, start timer, return |
| `PAUSE` | Duration (float) | Start pause timer, return |
| `INSTANT` | Text (BBCode, pipe chunk) | Append immediately, loop |
| `LINE_END` | Null | Show next indicator, return |

### Choice Effects (block renderer loop)

| Type | Value | Renderer Action |
|------|-------|-----------------|
| `CHOICES` | Dict of choices | Build buttons, return |

### Directive Effects

| Type | Value | Renderer Action |
|------|-------|-----------------|
| `DIRECTIVE` | Dict (show, hide, speed, set_name, etc.) | Apply UI effect, loop |

### Metadata Effects (non-blocking, renderer loop continues)

| Type | Value | Purpose |
|------|-------|---------|
| `SPEAKER_CHANGED` | `{new_name, prev_name}` | Character speaking changed |
| `NODE_STARTED` | node_id | New conversation node entered |
| `LINE_STARTED` | `{node_id, line_number}` | New line began (for highlighting) |
| `ACTOR_JOINED` | actor Node | Character portrait appeared (first time) |

### Terminal

| Type | Value | Renderer Action |
|------|-------|-----------------|
| `DONE` | Null | Hide dialog, cleanup |

### Effect Ordering

Metadata effects are queued in `_pending_effects` and drained before line-scanning effects. A typical sequence for one line:

```
NODE_STARTED → LINE_STARTED → SPEAKER_CHANGED → CHAR* → LINE_END
```

The renderer loop uses `continue` on metadata effects — they never block.

### Fast-Forward

Renderer cancels timers and calls `next_effect()` in a loop. Only `CHAR` and `PAUSE` cause the loop to return; all other effects are consumed immediately or loop.

## No Signals

The engine has **zero signals**. All communication is through the effect stream. This was a deliberate design decision: the engine's only API surface is `next_effect()`. Renderers are defined by convention — anything that holds an engine reference and consumes effects.

## Example Renderer Loop (pseudocode)

```gdscript
func _process_effects():
    while true:
        var effect = engine.next_effect()
        match effect.type:
            CHAR:
                text_box.text += effect.value
                _start_typing_timer()
                return
            PAUSE:
                _start_typing_timer(effect.duration)
                return
            INSTANT:
                text_box.text += effect.value
                continue
            DIRECTIVE:
                _apply_directive(effect.value)
                continue
            SPEAKER_CHANGED:
                _update_speaker(effect.value)
                continue
            NODE_STARTED, LINE_STARTED, ACTOR_JOINED:
                continue  # ignore or handle
            CHOICES:
                _display_choices(effect.value)
                return
            LINE_END:
                next_indicator.visible = true
                return
            DONE:
                hide()
                return
```

## Inline Syntax Handling

Block delimiters erase the original text from `_line` and replace it inline:

- `{{expr}}` → replace block with result string
- `{expr}` → erase block, continue scanning
- `<<directive>>` → parse and apply; visual directives produce DIRECTIVE effect
- `[[opt1|opt2]]` → pick random, replace block
- `[bbcode]` → INSTANT effect with the full tag
- `|chunk|` → INSTANT effect
- `_` → PAUSE(0.25)
- `\x` → CHAR with escaped character

## Public API

```gdscript
engine.start(conversation_string, options)
engine.advance()           # Next line after LINE_END
engine.choose(key)          # Select choice
engine.jump_to(node_id)     # Jump to node
engine.stop()               # End conversation
engine.next_effect()        # Pull next DialogEffect
engine.set_speed(value)     # Called from Sandbox
```

## Expression Evaluation (Sandbox)

`_evaluate()` injects three temp locals into `Skein.Sandbox`:

| Local | Value | Purpose |
|-------|-------|---------|
| `caller` | `options.caller` (Node) | The NPC/prop that triggered the dialog |
| `dialog` | `self` (engine) | Allows `jump()` and `speed()` calls from expressions |
| `scene` | `caller.owner` or null | The level/scene owning the caller |

It also defines convenience methods in the EvalContext: `speed(val)` (calls `dialog.set_speed`), `jump(node)` (calls `dialog.jump_to_from_eval`), and `timer(duration)` (creates a SceneTreeTimer).

`caller.owner` must be explicitly set — Godot does not auto-assign `owner` when adding children via code. Test fixtures use custom classes (`TestCaller`, `TestScene`) with custom properties (`npc_name`, `scene_label`) instead of `name`, since `name` conflicts with Node's built-in.

## Files

- `addons/skein/engine/DialogEngine.gd` — the engine class
- `addons/skein/engine/DialogEffect.gd` — effect type enum and value
- `tests/engine.test.gd` — 40 unit tests (GUT, all passing)
- `tests/sandbox.test.gd` — 12 sandbox tests (GUT, all passing)
- `tests/conversations/engine_*.yarn` — test conversation fixtures

## Test Execution

```bash
/home/daelon/godot/godot4 --headless -s addons/gut/gut_cmdln.gd \
  -gconfig=.gut_editor_config.json -gexit
```

## Related Lodes

- [dialog-runtime.md](dialog-runtime.md) — old monolith assessment
- [core-architecture.md](../core/core-architecture.md) — SkeinSingleton, file loading
- [plans/dialog-engine-extraction.md](../plans/dialog-engine-extraction.md) — the extraction plan