# Engine Review — 2026-07-12

Full review of the DialogEngine extraction (engine, all four renderers, test
manifest). Overall verdict: **the architecture is right** — effect stream,
in-band metadata, explicit state machine are all correct calls. Every finding
below is a seam artifact or unfinished migration, not a design flaw. Findings
ranked by severity within each section.

## Bugs

### 1. Unterminated blocks hard-hang the game (top priority)
All four scan helpers (`_scan_single_brace`, `_scan_double_brace`,
`_scan_directive`, `_scan_inline_random`) return `null` **without advancing
the cursor** when the closing delimiter is missing; `next_effect()`'s while
loop does `continue` and spins forever. `Hello {oops` = synchronous freeze.
(The old DialogBox had the same stall but timer-paced; the pull refactor made
it a hard lock.) Rule: **malformed prose must degrade, never hang** — emit the
raw char and advance, or treat the rest of the line as literal.

### 2. `{{jump(...)}}` corrupts the destination line
`_scan_single_brace` has the `line_before` jump guard; `_scan_double_brace`
does not. A jump inside `{{ }}` replaces `_line` with the new node's line, and
the splice at stale coordinates (`_line.substr(0, start) + result_str + ...`)
then corrupts it. Guard was applied asymmetrically.

### 3. Metadata ordering violation on mid-line `{jump(...)}`
The jump queues NODE_STARTED/LINE_STARTED/SPEAKER_CHANGED into
`_pending_effects`, the helper returns null, and the scan loop continues —
emitting the new line's first CHAR **before** the metadata drains (pending
effects are only checked at the top of `next_effect()`). Renderers clear text
on LINE_STARTED → first character of the destination line is eaten. Fix: after
any helper returns null, drain `_pending_effects` before continuing the scan.
`test_metadata_effects_come_before_display` passes because it only exercises
normal line advancement.

### 4. `set_name` / `show_name` / `show_portrait` / `speed` never reach renderers
`_scan_directive` forwards only `show`/`hide` as DIRECTIVE effects —
contradicting DialogEffect.gd's own doc ("show, hide, speed, set_name, etc.").
Both example renderers implement `set_name` handling that can never fire, and
`name_override` isn't in the SPEAKER_CHANGED payload either — `<<set_name>>`
is fully lost in the new path (still works in legacy DialogBox).

### 5. Conditional choices regressed
Legacy DialogBox evaluated each choice's `condition` and disabled buttons. The
new engine emits the raw choices dict; neither renderer evaluates conditions —
everything renders enabled. The engine owns the sandbox, so evaluate at emit
time: attach `enabled` (and `visible`) per choice to the CHOICES payload.
README-advertised feature currently only working in the legacy renderer.
See [choice-system.md](./choice-system.md).

### 6. `<<wait>>` used by real Isotope content, unhandled
Isotope yarn files use `<<wait>>` (see todo.md pattern inventory) but
`_parse_directive` has no `wait` case (neither did the old one — it's been
silently swallowed forever). Trivial now: `<<wait N>>` → PAUSE effect with
arbitrary duration.

### 7. Smaller
- Unmatched `[` is silently swallowed (should emit `CHAR "["`); unmatched `|`
  likewise eats the pipe.
- Re-entrant `_evaluate` clobbers temp locals: dot-notation speaker eval
  triggered during a jump-in-eval clears the outer eval's `caller`/`dialog`
  mid-flight. Sandbox tests cover sequential isolation, not re-entrancy.
- `_enter_node` with unknown node id leaves `current_node` stale → KeyError on
  `nodes[current_node]`. Entry typos, `jump('typo')`, and bad choice targets
  should `push_error` + DONE, not crash.
- `_detect_speaker` evaluates arbitrary prose: any line with a `.` before a
  `:` ("Well... you know: stuff") goes through `_evaluate()`. Gate the
  dot-notation eval on an identifier regex.
- Indented body line before any choice marker → `choices[str(0)]` KeyError in
  `_process_inline_choices`.

## Protocol gaps (old capabilities the new protocol can't express)

### YIELD died in the refactor
`State.YIELDING` is unreachable — nothing sets it. Old `_yield(object, sig)`
is gone; `timer()` is still exposed in the eval context but nothing can wait
on it. This was a flagship capability (cutscene coordination from prose).
Needed: `YIELD` effect type (payload: object + signal) + `engine.resume()`;
`is_blocking()` already anticipates blocking types.

### `continue_line` is set and never consumed
Trailing-backslash line continuation (merge lines, no clear) is lost —
renderers clear unconditionally on LINE_STARTED. The tests pin the wrong
thing: they verify the flag gets *set*, not that it *does* anything.

### `push` / `return` / `emit` parsed, unimplemented (known, pinned by tests)
Worth finishing rather than removing: `push`/`return` is a **conversation call
stack** — `Common:GotItem` becomes a subroutine any conversation can call and
return from, instead of a jump of no return. `emit` (fire a game signal from
prose) is the outbound channel pairing with YIELD's inbound one. Also the
substrate for hub-and-spoke choices (see [choice-system.md](./choice-system.md)).

### Housekeeping
- `popup`/`popup_timeout` on the engine are vestigial — PopupRenderer
  correctly owns auto-advance now. Delete the vars or put a payload on
  LINE_END.
- `is_blocking()` is dead API — no renderer uses it. Either build the shared
  consume loop around it (below) or drop it.

## Renderer issues

- **The consume loop is copy-pasted 4× and recursive** — a long chain of
  INSTANT/DIRECTIVE effects risks stack depth. One shared *iterative*
  `drain_until_blocking(engine)` helper (built on `is_blocking()`) fixes
  duplication + recursion + fast-forward in one move, without violating
  bring-your-own-scene (it's a function, not a base class).
- **Fast-forward implemented twice, differently.** PhoneRenderer's drain-while
  loop is correct and instant. SkeinDialogBox's `_fast_forward` flag just
  zeroes the typing timer → drains one effect per frame → a 200-char line
  "fast-forwards" in 3+ seconds, frame-rate-dependent.
- SkeinDialogBox `_input` has no focus check and no `accept_event()` — two
  active renderers both respond to `ui_accept` (PhoneRenderer gates on
  `has_focus()`).

## Testing gaps

- **Malformed input, entire class**: unterminated `{`/`{{`/`<<`/`[[`,
  unmatched `[`/`|`, body-before-marker, jump/entry to nonexistent nodes,
  empty files. One fuzz test — random bytes must reach DONE without hanging —
  covers bug #1's whole class forever.
- **Golden transcripts** (highest leverage): the refactor made dialog
  execution *data* — record the full effect sequence for a fixture
  conversation, assert against a stored transcript. Catches every reordering,
  lost effect, and regression in one assertion; per-feature unit tests
  structurally cannot catch ordering bugs like #3.
- **Renderer parity**: same conversation through all four renderers, assert
  final text equivalence (renderers.test currently smoke-tests DialogBox only).
- End-to-end directive *delivery* (engine tests verify `name_override` is set,
  never that a renderer receives it — would have caught bug #4), conditional
  choices end-to-end, continuation rendering, re-entrant eval, mid-line-jump
  metadata ordering, `{{jump}}`.

## Cheap additions the architecture unlocked

- `<<wait N>>` → PAUSE with arbitrary duration (~5 lines; also fixes bug #6)
- `engine.get_state()` / `set_state()` → save/resume mid-conversation
  (serialize current_node / current_line / _line_count; the Isotope pattern;
  a feature Dialogic users beg for)
- Backlog/history: the engine already accumulates each line — expose it (VN
  staple)
- Seedable RNG hook for `[[random]]` / `%random` / `_get_id()` — determinism
  the moment Skein rejoins Isotope's replay world

## Related

- [runtime-engine.md](../dialog/runtime-engine.md) — the architecture under review
- [choice-system.md](./choice-system.md) — choice overhaul design
- [test-coverage-improvement.md](./test-coverage-improvement.md)
