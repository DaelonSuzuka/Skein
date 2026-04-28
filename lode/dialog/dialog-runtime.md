# DialogBox Runtime Assessment

`DialogBox.gd` is the in-game dialog interpreter — it types text, handles choices, evaluates code, and manages node flow. After a full audit, here is the frank assessment.

## Overall Verdict

**It works for happy-path content but is held together by duct tape.** The 815-line file violates single-responsibility (typing, evaluation, choice parsing, node navigation, character management, and directive parsing all in one class). There are genuine bugs in block replacement, off-by-one skips, signal double-fires, and brittle regex. The runtime is also tightly coupled to `Sandbox.gd`, which rebuilds a GDScript `Node` for every single expression evaluation.

## Architecture Problems

### 1. Monolithic God Class

`DialogBox` does too much:
- Text typing engine (`next_char`, `text_timer`)
- Choice UI (`display_choices`, `add_option`, `option_selected`)
- Node graph interpreter (`set_node`, `jump_to`, `next_line`, `check_next_line`)
- Expression evaluator client (`evaluate`)
- Directive parser (`parse_directive`, `apply_directive`)
- Character portrait manager (`character_talk`, `character_idle`, speaker reparenting)
- Input handler (`_input`, `handle_input`)

### 2. State Machine is Ad-Hoc

State is scattered across boolean flags (`active`, `yielding`, `waiting_for_choice`, `line_active`, `popup`, `exec`) with no unified state machine. `next_line()` can be called from `_input`, `dismiss_timer`, and internal recursion, creating re-entrancy risks.

## Definite Bugs

### 3. `{{ }}` Double-Fire on `line_finished`

When `next_char()` handles a `{{expr}}` block during timed typing, it:
1. Evaluates the expression and inserts the result into `line`.
2. Recursively calls `next_char()` to type the result and remaining text.
3. When the recursive call reaches end-of-line, it emits `line_finished`, stops the timer, and returns.
4. The *outer* call then restarts `text_timer`.
5. On the next tick, `cursor` is at end-of-line, so `line_finished` fires **a second time**.

**Impact:** Any signal listener (`line_finished`, `character_idle`, `check_next_line`) fires twice. This can double-trigger game logic tied to dialog completion.

### 4. `{{ }}` Does Not Erase the Original Block

`get_block('{{', '}}', ['erase'])` receives the `'erase'` option, but the erasure code is **commented out** inside `get_block`:

```gdscript
# if 'erase' in options:
#     line.erase(cursor, end - cursor + len(end_string))
```

In `next_line()`, the block scan modifies a local copy (`line`) but then `set_line(new_line)` is called with the **original unmodified text**, so the `{{ }}` scan there is completely wasted.

In `next_char()`, `line.insert(cursor, str(result))` inserts the result **after** the original block (because `cursor` was already advanced past it by `get_block`). The original block remains in the string. But because `cursor` is past the block, the recursive `next_char()` types the result and then the remaining characters, never returning to the block's original position. So the block itself is silently skipped during typing.

**Impact:** For `a{{1+1}}b`, the text box shows `a2b` (correct visual), but `line.length()` includes the original block, causing the double-fire bug above. If the block was at the very end (`{{1+1}}`), the extra length causes the outer call to restart the timer and double-fire.

### 5. Single `{ }` Skips the Character After It

In `next_char()`:

```gdscript
else:
    var block = get_block('{', '}')
    if block:
        if exec:
            var result = evaluate(block)
        cursor += 1        # BUG: cursor already advanced past } by get_block
        next_char()
```

`get_block` sets `cursor = end + len(end_string)` (past the closing `}`). The extra `cursor += 1` skips one more character.

**Impact:** `a{b}c` results in `ac` being typed; `c` is silently dropped.

### 6. `apply_directive` Field Typos

```gdscript
if 'show_name' in dir:
    show_name = dir.name          # BUG: should be dir.show_name

if 'show_portrait' in dir:
    show_portrait = dir.portrait  # BUG: should be dir.show_portrait
```

**Impact:** `<<show_name false>>` and `<<show_portrait false>>` directives either do nothing or read from the wrong key.

### 7. `preprocess_random_lines` Minus-One is Non-Obvious but Correct

```gdscript
line = choices[randi() % choices.size() - 1].lstrip('% ')
```

Operator precedence makes this `(randi() % N) - 1`. Due to Godot's negative array indexing (`array[-1]` → last element), the mapping is a bijection and probabilities are uniform. However, if someone "fixes" this to `(randi() % choices.size())`, it would break randomness.

**Impact:** Not a functional bug, but an accidental-correctness trap. It should be rewritten clearly as `choices[randi() % choices.size()]`.

### 8. Inline Choice Bodies Accumulate Forever

`process_inline_choices()` scans from `current_line` to the end of the node's lines array. It does not stop at a blank line or unindented non-choice line. If a node has dialog followed by choices, the choice parsing swallows everything below it.

**Impact:** A node cannot contain choices followed by more dialog. All choices must be at the end of a node.

### 9. `next_char()` and `next_line()` Duplicate Inline Choice Parsing Logic

Both `next_line()` and `check_next_line()` contain nearly identical code for detecting `-` / `->` choice markers. The author clarifies that the **duplicate choice syntax** (both `-` and `->` being valid markers) is intentional — two syntaxes for the same thing.

However, the *code duplication* across functions is still a maintenance hazard. Any fix to choice parsing must be applied in both `next_line()` and `check_next_line()`. Extracting into a single `process_inline_choices(lines, start_index, marker)` helper would unify logic without removing either call-site.

Both `next_line()` and `check_next_line()` contain nearly identical code for scanning inline choice markers (`-` and `->`). The author notes that the **duplicate choice syntax** (both `-` and `->` being valid markers) is intentional. However, the *code duplication* across both functions is still a maintenance hazard — any fix to how choices are parsed must be applied in two places.

Extracting into a single `process_inline_choices(lines, start_index, marker)` helper would unify logic without removing either call-site.

## Design Flaws

### 10. Expression Evaluation is Expensive

` evaluate()` in `DialogBox` calls `Skein.Sandbox.get_context()` for EVERY `{ }` or `{{ }}` block. `get_context()` builds a brand-new GDScript `Node` with dynamically generated source code, adds it as a child, and then uses `Expression.parse()` / `Expression.execute()` against it.

**Impact:** For dialog with many code blocks, this creates garbage nodes and GDScript compilation overhead every single character-tick. With long conversations this will cause frame drops.

### 11. Assignment Detection is a Known Dirty Hack

`Sandbox.gd` uses:

```gdscript
re.compile('[^=][=][^=]')
```

This is an admitted late-addition dirty hack. It matches `>= ` (greater-than-or-equal with trailing space), which means `{Player.gold >= 5}` can incorrectly trigger assignment mode. The regex is intentionally simple — a proper parse was deferred because the eval mechanism has esoteric behavioral requirements that aren't obvious.

**Impact:** `{Player.gold >= 5}` could trigger assignment mode and fail or mutate state unexpectedly. Fixing this is blocked on understanding the full evaluation requirements.

### 12. Portraits are Destroyed and Reparented Every Line

If a character speaks multiple lines in a row, `reparent_node` is called every line because the portrait container checks `!portrait_container.is_ancestor_of(speaker)`.

Wait — actually `reparent_node` first checks `old_parent`. If already parented to `portrait_container`, it removes and re-adds. The code does:

```gdscript
if !portrait_container.is_ancestor_of(speaker):
    Skein.Utils.reparent_node(speaker, portrait_container)
```

This check prevents unnecessary reparenting. Good.

But when speakers change:

```gdscript
for child in portrait_container.get_children():
    child.hide()
if next_speaker:
    next_speaker.show()
```

This hides ALL children and shows the new one. If multiple characters are supposed to appear simultaneously (the code has a commented-out `if '/' in name` for multiple characters), this can't support it.

**Impact:** Single-speaker limitation is baked in.

### 13. `get_id()` Uses Recursive Random Collision Resolution

```gdscript
func get_id() -> int:
    var id = randi()
    if str(id) in nodes:
        id = get_id()
    return id
```

With many nodes, collision probability increases. For runtime-generated anonymous choice-body nodes, this could loop many times or, in pathological cases, stack-overflow.

### 14. No Null Guards for Mandatory UI Nodes

```gdscript
@onready var name_box = find_child('Name')
@onready var text_box = find_child('TextBox')
```

If a custom `DialogBox.tscn` is missing these children, the script crashes on first use with no descriptive error.

### 15. `handle_input` Secondary Action is Unimplemented

```gdscript
if event.is_action(secondary_action) and event.pressed:
    accept_event()
    # do secondary input things
```

**Impact:** Secondary action (e.g., skip dialog, cancel) does nothing.

## Minor Issues

- `_yield(object=null, sig="nothing")` will crash if called without valid args because `null.connect()` is invalid.
- `actor_left` signal is declared but never emitted.
- `directive_data` signal is self-documented as having a "bad name lmao".
- Commented-out dead code for `=><` (jump/return) and other future directives litters `next_char()`.
- `change_outline_color` silently does nothing if nodes are missing.
- `check_next_line()` returning early on `length` limit without stopping leaves the dialog in an inconsistent parked state.

## Recently Fixed

### `{{ }}` Double-Fire on `line_finished` ✅
Added `return` after recursive `next_char()` in double-brace handling. The outer `match ...: '{':` branch no longer falls through to restart `text_timer`.

### Single `{ }` Skipped the Next Character ✅
Removed erroneous `cursor += 1` after `get_block('{', '}')`. `get_block` already sets `cursor = end + len(end_string)`, placing it past the closing brace.

### `apply_directive` Field Typos ✅
Fixed `dir.name` → `dir.show_name` and `dir.portrait` → `dir.show_portrait`.

## Recommendations

1. **Split the interpreter into three classes:**
   - `DialogTyper` — handles `text_timer`, `next_char`, printing, BBCode, pipes, pauses
   - `DialogRunner` — handles `next_line`, `set_node`, `jump_to`, choice parsing, node navigation
   - `DialogBox` — thin UI shell that owns the above and handles input/portraits

2. **Rewrite `{{ }}` / `{ }` block handling:**
   - Replace `line.insert()` with `line.erase()` + `line.insert()` at the *start* of the block, or use `String.replace()` before typing begins.
   - Parse ALL code blocks once in `set_line()` before typing starts, not during `next_char()`.

3. **Fix `cursor += 1` after single `{ }`**
   - Remove the extra increment. `get_block` already advances `cursor` past the delimiter.

4. **Fix `apply_directive` typos**
   - `dir.show_name` and `dir.show_portrait`

5. **Cache evaluation context**
   - Build the `EvalContext` node once per line, not once per block.

6. **Add null checks and descriptive error messages**
   - If `name_box`, `text_box`, `options_container`, or `portrait_container` are missing, `push_error` with the node path.

7. **Unify choice parsing**
   - Extract inline-choice detection into a single helper used by both `next_line()` and `check_next_line()`.

8. **Fix `preprocess_random_lines` to be idiomatic**
   - `choices[randi() % choices.size()]`

## Related Lodes
- [core-architecture.md](../core/core-architecture.md) — how nodes get loaded
- [sandbox-evaluation.md](sandbox-evaluation.md) — detailed analysis of expression evaluation bugs
- [file-formats.md](../formats/file-formats.md) — node data that the runtime interprets
