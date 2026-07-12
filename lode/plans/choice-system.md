# Choice System Design

Goal: **support every choice style that has ever appeared in a game**, backed
by the full conversation graph (forks, conditions, subroutines). Choices are
currently the least developed part of the runtime — a flat dict of
`{choice, condition, next}` rendered as a button list, with conditions not
even evaluated in the new engine path (see
[engine-review-2026-07-12.md](./engine-review-2026-07-12.md) bug #5).

The pull-based engine makes this tractable: a choice style is (a) payload
schema the engine resolves, plus (b) a renderer treatment. The engine owns
truth (what can be picked, what happens); renderers own presentation (how it
looks, how time pressure feels). One schema, many renderers — same
architecture as the effect stream itself.

## The taxonomy

Every style reduces to combinations of a small feature set:

| Style | Seen in | Requires |
|---|---|---|
| Full-text list | BG, classic RPGs | baseline (exists) |
| Numbered/hotkey list | Fallout, cRPGs | renderer only |
| Paraphrase + tone wheel | Mass Effect | `paraphrase` + `tone` fields per choice |
| Timed choice, default on expiry | Telltale | `timeout` + `default` in payload; renderer ticks (renderer owns time) |
| Silence as a deliberate option | Oxenfree, KOTOR2 | timed + an empty-text choice as default |
| Interrupt choices (window opens mid-line, closes, dialog never stops) | Oxenfree | **non-blocking choice protocol** (see below) |
| Gated-visible (shown but locked, requirement displayed) | Disco Elysium | `enabled_when` + `gate_display` per choice |
| Gated-hidden | everywhere | `visible_when` per choice |
| Skill-check choice (roll on pick, success/fail fork) | Disco, Fallout | `check` expr + two-edge routing (`next_success`/`next_fail`) |
| Costed choice (pay to pick) | Fallout NV, deckbuilders | `cost` expr + display; engine validates + deducts on choose |
| Exhausted/sticky (asked-about options gray out) | every hub NPC ever | **choice memory** per node |
| Hub-and-spoke (leaf returns to question hub) | every RPG shopkeeper | `<<push>>`/`<<return>>` call stack |
| Free-text input | name entry, riddles | INPUT effect + `engine.submit_text()` → sandbox var |
| Hold-to-confirm / weighted pick | Life is Strange | renderer only |
| Consequence toast ("X will remember that") | Telltale | `consequence` tag in payload; renderer shows post-pick |
| Long scrolling lists | shops | renderer only |

Notable: roughly half the styles are **renderer-only** once the payload schema
is rich enough. That's the effect-stream dividend.

## Payload schema (engine-resolved)

The CHOICES effect payload becomes, per choice:

```gdscript
{
    "text": "",             # full text
    "paraphrase": "",       # short form (wheel/compact renderers); falls back to text
    "tone": "",             # free tag: 'paragon', 'aggressive', 'sarcastic' — renderer maps to slot/color
    "visible": true,        # engine-evaluated from visible_when at emit time
    "enabled": true,        # engine-evaluated from enabled_when at emit time
    "gate_display": "",     # '[Logic 8]', '[Speech 45%]' — shown even when locked
    "check": "",            # expr rolled on choose(); routes next_success/next_fail
    "cost": "",             # expr; engine validates on choose, deducts if affordable
    "chosen": false,        # choice memory: picked before in this conversation/session
    "consequence": "",      # tag for post-pick feedback toast
    "next": "",             # target node (or next_success/next_fail for checks)
    "timeout": 0.0,         # >0: window duration (renderer ticks, engine trusts choose())
    "default": "",          # choice key auto-picked on expiry ('' = window lapses silently)
}
```

**The engine evaluates everything evaluable at emit time** (visible/enabled/
gate/cost affordability) because it owns the sandbox — renderers receive
resolved booleans, never expressions. Checks and costs re-validate at
`choose()` time (engine-side, never trust the renderer).

**Choice memory**: engine tracks chosen keys per node id
(`_chosen[node_id] = [keys]`). Per-conversation by default; persistent when
the game wires it to its own save data via a sandbox hook. This is what
exhausted/sticky styles and "seen" markers ride on.

## Protocol extension: non-blocking choice windows (Oxenfree style)

Current CHOICES is terminal — the stream blocks until `choose()`. Interrupt
choices need the opposite: the window opens, **text keeps streaming**, the
window closes on timeout or node end, and picking mid-stream jumps.

New effects:
- `CHOICES_OFFERED` (non-blocking; payload = schema above + window duration)
- `CHOICES_CLOSED` (non-blocking; emitted when the window lapses)

`choose()` during an open window interrupts: engine abandons the current line
(emitting LINE_END for cleanliness) and routes. This is the single biggest
protocol addition and it unlocks the most distinctive style on the list.

## Graph backing

- Choice nodes need per-choice fields for the schema (conditions, gates,
  costs, tones) — editor UI work; `Branch` nodes already carry per-edge
  conditions for forks.
- Skill checks need two-edge choice connections (`next_success`/`next_fail`).
- Hub-and-spoke is `<<push>>`/`<<return>>` (parsed, unimplemented — see
  review): a leaf conversation returns to the hub node, which re-emits its
  choices with memory applied.

## The content problem, solved sideways

This system was never built out because no game content arrived to demand it.
The answer is the same one the renderers already demonstrated: **the content
is a zoo, not a game.** Build the Choice Gallery:

- One fixture `.yarn` per style in `tests/conversations/choices/` — each tiny,
  each self-contained
- A gallery demo scene: grid of buttons, each launching one style with the
  appropriate renderer treatment
- Each fixture doubles as a **golden-transcript test** (the effect stream is
  data — record and assert)
- Each gallery entry doubles as a **README gif** — "Skein does Mass Effect
  wheels, Disco checks, Telltale timers, Oxenfree interrupts. Bring your own
  scene." This is the Dialogic-killer feature matrix, demonstrated rather
  than claimed.

Fixtures are the content, the tests, and the marketing simultaneously. No
game required — and when a game does arrive (Isotope's PSO-shape lobby needs
terminals, shops, and the blind-recovery screen — timed + costed choices,
exactly), the styles are already on the shelf.

## Sequencing

1. Schema + engine-side evaluation (fixes review bug #5 as a side effect)
2. Choice memory + exhausted styles
3. Timed choices + silence (renderer ticks, engine default-routing)
4. `push`/`return` → hub-and-spoke
5. Skill checks + costs (two-edge routing, engine validation)
6. Non-blocking windows (Oxenfree)
7. Free-text INPUT
8. Gallery + transcripts throughout, one fixture per landed style

## Related

- [engine-review-2026-07-12.md](./engine-review-2026-07-12.md) — bugs this design subsumes
- [runtime-engine.md](../dialog/runtime-engine.md) — effect stream this extends
- [visual-editor.md](../editor/visual-editor.md) — choice node UI implications
