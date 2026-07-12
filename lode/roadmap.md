# Roadmap

Vetted active work items — purpose & goals only, no implementation details.

Each entry is one paragraph at most and SHOULD link to one or more plan files under [plans/](plans/).

## Extract DialogBox monolith into DialogEngine + DialogRenderer

Split the 816-line `DialogBox.gd` runtime into two layers: `DialogEngine` (stateful conversation interpreter, eval engine, side-effect-capable instruction stream) and `DialogRenderer` (UI base class implementing pull-based effect consumption, typing animation, fast-forward). This enables multiple simultaneous dialogs (main + NPC popups), makes the runtime testable without UI instantiation, and preserves the inline editorial timing marks (`_`, `|`, `\`, `{{ }}`) that define Skein's text-first authoring philosophy. Engine evals and directives happen inline during `next_effect()` so dialog can still trigger arbitrary game side effects mid-line. See [plans/dialog-engine-extraction.md](plans/dialog-engine-extraction.md).

## Engine seam repairs (post-extraction review)

A 2026-07-12 review of the DialogEngine extraction found the architecture sound but the seams leaky: unterminated blocks hard-hang `next_effect()`, `{{jump}}` corrupts the destination line, mid-line jumps emit text before their metadata, and `set_name`/`show_name`/`show_portrait`/`speed` directives never reach renderers. Also: YIELD died in the refactor (`State.YIELDING` is unreachable), line continuation is set-but-unused, and the renderers' copy-pasted recursive consume loops should become one shared iterative `drain_until_blocking()`. Highest-leverage test additions: golden effect-stream transcripts and a malformed-input fuzz test. See [plans/engine-review-2026-07-12.md](plans/engine-review-2026-07-12.md).

## Choice system overhaul

Support every choice style ever seen in a game — timed, gated, costed, skill-checked, exhausted, hub-and-spoke, interrupt windows, free text — as one engine-resolved payload schema plus renderer treatments, backed by the graph (forks, conditions, push/return subroutines). The content problem is solved sideways: a Choice Gallery of fixture conversations that are simultaneously the test suite (golden transcripts), the demo scene, and the README feature matrix. See [plans/choice-system.md](plans/choice-system.md).

## Runtime conversation cache and watcher cleanup

`Skein.load_conversation()` reads from disk on every call — no in-memory cache exists. The file watcher polls every second even in shipped games. Proposals: (1) add a `_cache` dict so repeated calls serve from memory, (2) disable the watcher at runtime with `Engine.is_editor_hint()`, (3) add `engine.start_with_data()` for pre-loaded conversations, (4) extract the conversation string parser (`"Name:Entry:Line"`) from 7 independent sites into one shared function. See [core/conversation-loading.md](core/conversation-loading.md).
