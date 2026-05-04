# Test Coverage Improvement Plan

## Context

Skein has 112 passing tests but coverage is heavily concentrated: the DialogEngine effect stream (79 tests) and sandbox (14 tests) are well-covered, while most other components have zero or minimal tests. Several real bugs were already found and fixed while writing the extended engine tests (cursor off-by-one, jump side-effect corruption, exec=false design error, missing Tree.gd reference). More bugs likely exist in untested code.

## Priority Tiers

### P0 — Real bugs that exist right now

**Old DialogBox `preprocess_random_lines` off-by-one**
`randi() % choices.size() - 1` excludes the last random option. The new engine's `_preprocess_random_lines` uses `randi() % choices.size()` which is correct, but the old DialogBox still has the bug. Even though DialogBox is the extraction target, it's still the active runtime for the editor preview.

**Sandbox assignment is broken**
`Sandbox._assignment_enabled` and `_do_assignment()` exist but have zero working tests. The only test (`sandbox.test.gd` lines 62–79) is commented out because assignment was broken. The regex `[^=][=][^=]` misses `a= b` (space before `=`) and `= b` at string start. The `<<assignment>>` directive was confirmed working in engine tests, but the sandbox side that actually executes the assignment is untested and likely broken.

**Yarn parser has 1 surface test** ✅ (now 19 tests)
`yarn.test.gd` loads a file and checks node count — nothing about round-trip fidelity, edge cases, or data mutation. `convert_nodes_to_yarn()` mutates its input dict (erases `name`, `text`, `size`, `offset`), which will corrupt any in-memory data passed to it. Header parsing with `split(':', true, 1)` silently skips malformed lines. `str_to_var` on corrupt serialized dicts crashes or returns null. The CRLF fix was defensive but untested specifically.
**Found and fixed**: empty body crashed `Yarn.gd:143` (`body[0]` on empty array) — real bug present in production data (Isotope's `Common.yarn` has empty `Item_NPC` node).
**Added**: `yarn_multi_node.yarn` test fixture with 6 nodes modeled on Isotope patterns (connections, choices, multi-line bodies, `->` choice syntax). 19 tests now cover multi-node parsing, round-trip fidelity, `speech→dialog` legacy, CRLF, empty bodies, header with colons, and `convert_nodes_to_yarn` input mutation.

**SkeinSingleton path resolution is untested**
`load_conversation()` strips prefixes, splits on `:`, looks up short names in `_conversations` — the core routing logic that makes `start("my_convo:NodeName")` work has zero test coverage. A bug here silently fails to find conversations.

### P1 — Missing coverage on core contracts

**DialogEffect `is_blocking()` contract**
Zero tests. This single method determines whether a renderer blocks or loops. Wrong return values freeze or skip UI. Every `Type` enum member should be verified.

**SkeinConversation `make_path()`**
Zero tests. This builds the `file:node:line` path string stored in inspector properties. Broken formatting silently corrupts conversation references.

**Renderer depth**
13 smoke tests cover 4 renderers but only test `start()` and basic text consumption. Untested: choice display + selection flow, directive effect rendering (`show_name`, `set_name`), speaker label updates, fast-forward draining, popup auto-advance timeout, phone dismiss, DONE cleanup.

**Files save/load round-trip**
Only `load_json` is tested. `save_json` then `load_json` round-trip is never verified. `_ensure_suffix`, `ensure_prefix`, `validate_paths` directory creation, depth limits in `get_all_files` are all untested.

### P2 — Larger gaps

**Watcher file-change detection**
Zero tests. The watcher drives editor refresh — a bug here means the editor shows stale data. Testable by creating temp directories and manually ticking `_process()`.

**SkeinCanvas popup management**
Zero tests. `_popup_over` may leak popups if the `done` signal doesn't pass `self`. `_process` position tracking could crash on freed objects.

**Utils**
`reparent_node`, `connect_all`, `get_all_children` — zero tests. `get_all_children` accumulates duplicates if called twice without clearing.

**Yarn save → load round-trip integration**
Parse then save then parse again should yield equivalent data. `var_to_str` / `str_to_var` for nested dicts may not round-trip. `convert_nodes_to_yarn` mutates input data.

## Plan

### Phase 1: Fix known bugs & core round-trips (P0)

1. **Yarn parser tests** ✅ (19 tests done, 1 bug fixed)
   - `parse_yarn` with multi-node files, empty bodies, missing header fields
   - `convert_nodes_to_yarn` round-trip: parse → save → parse again, compare
   - `convert_nodes_to_yarn` mutates input — documented in test
   - CRLF handling (global `\r` strip affects body too)
   - `speech` → `dialog` legacy rename
   - Header with colons in value preserved by `split(':', true, 1)`
   - **Bug fixed**: empty body crashed `body[0]` on empty array

2. **SkeinSingleton path tests** (~10 tests)
   - `load_conversation` with short names, full paths, `:NodeName` syntax
   - `get_full_path` resolution
   - `path_to_name` extraction
   - Missing file returns empty dict / null
   - `.json` vs `.yarn` dispatch

3. **Fix & test sandbox assignment** (~8 tests)
   - Fix the regex or replace with proper `=` vs `==` detection
   - Simple assignment `{x = 1}`
   - Assignment with `==` should NOT trigger
   - `_do_assignment()` method generation
   - `<<assignment true>>` + `{x = 1}` integration via engine

4. **Fix old DialogBox random off-by-one** (1-line fix + 1 test)

### Phase 2: Core contracts (P1)

5. **DialogEffect `is_blocking()` contract** (~6 tests)
   - Every Type enum member verified

6. **SkeinConversation `make_path()`** (~5 tests)
   - All field combinations, `.yarn` suffix handling

7. **Files save/load round-trips** (~8 tests)
   - `save_json` → `load_json` round-trip
   - `_ensure_suffix` edge cases
   - `ensure_prefix` logic
   - `get_all_files` max_depth boundary
   - Nonexistent directory returns empty

8. **Renderer depth tests** (~15 tests)
   - Choice display + `choose()` → new node flow
   - Directive effects (`<<show_name>>`, `<<set_name>>`, `<<show>>`/`<<hide>>`)
   - Speaker label updates from SPEAKER_CHANGED
   - Fast-forward in DialogBox
   - Phone `dismiss()`
   - Popup auto-advance after timeout
   - DONE hides / cleanup

### Phase 3: Integration & utilities (P2)

9. **Yarn save-load round-trip** (~5 tests)
   - Nodes with choices, branches, connections
   - Verify data equivalence after parse → save → parse

10. **Watcher tests** (~6 tests)
    - Detect new file, modified file, deleted file
    - First-scan suppression
    - Manual `_process` tick driving

11. **Utils tests** (~4 tests)
    - `reparent_node` valid/invalid
    - `connect_all` signal-to-method
    - `get_all_children` depth + duplicate accumulation

12. **SkeinCanvas popup tests** (~4 tests)
    - `start_dialog` creates engine + dialog
    - `popup_dialog` + position tracking
    - `_popup_over` cleanup
    - Multiple concurrent popups

## Estimated totals

| Phase | New tests | Fixes |
|-------|-----------|-------|
| 0 (editor smoke) | 9 ✅ | 0 |
| 1 | ~34 | 2 bugs + 1 broken feature |
| 2 | ~34 | 0 |
| 3 | ~19 | 0 |
| **Total** | **~96** | **3** |

## What we're NOT testing

- `plugin.gd`, `SkeinInspectorPlugin.gd` — hard-depend on Godot editor APIs (`EditorPlugin`, `EditorInterface`, `EditorInspectorPlugin`); no way to run outside the editor
- Visual rendering / pixel output — `--headless` runs the scene tree but doesn't render; can't verify layout, colors, animation
- Mouse/keyboard input events — no input system in headless; can't test drag-and-drop, connection wiring, node selection via click
- Old `DialogBox.gd` beyond the random off-by-one fix — it's the extraction target, not the future
- `Character.gd` — needs AnimatedSprite2D scene setup; mood/talk/idle could be tested with a minimal `.tscn` but low priority until characters graduate from prototype

## What IS testable headlessly (verified)

Godot 4.6 `--headless` instantiates the full scene tree including `Control` nodes — it just skips rendering. This was confirmed experimentally: editor `.tscn` scenes instantiate, `add_child` works, unique-name nodes are accessible, `load_conversation` populates the graph, and the 13 existing renderer tests all pass in `--headless`.

- `SkeinEditor.tscn` — instantiation, `load_conversation()`, `current_conversation`, graph population
- `GraphEdit` — `create_node()`, `get_nodes()`, `set_nodes()`, `get_data()`, `set_data()` data round-trip
- `ConversationTree` — item building, folder state (pending: need to verify `Tree` widget behavior in headless)
- All renderers — start, effect consumption, text accumulation, state transitions (already tested)
- `SkeinSingleton` — `load_conversation()`, `get_full_path()`, `path_to_name()`, `save_conversation()`
- Path routing in `SkeinEditor` — `trim_prefix`/`split(':')` parsing