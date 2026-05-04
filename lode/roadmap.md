# Roadmap

Vetted active work items — purpose & goals only, no implementation details.

Each entry is one paragraph at most and SHOULD link to one or more plan files under [plans/](plans/).

## Extract DialogBox monolith into DialogEngine + DialogRenderer

Split the 816-line `DialogBox.gd` runtime into two layers: `DialogEngine` (stateful conversation interpreter, eval engine, side-effect-capable instruction stream) and `DialogRenderer` (UI base class implementing pull-based effect consumption, typing animation, fast-forward). This enables multiple simultaneous dialogs (main + NPC popups), makes the runtime testable without UI instantiation, and preserves the inline editorial timing marks (`_`, `|`, `\`, `{{ }}`) that define Skein's text-first authoring philosophy. Engine evals and directives happen inline during `next_effect()` so dialog can still trigger arbitrary game side effects mid-line. See [plans/dialog-engine-extraction.md](plans/dialog-engine-extraction.md).

## Runtime conversation cache and watcher cleanup

`Skein.load_conversation()` reads from disk on every call — no in-memory cache exists. The file watcher polls every second even in shipped games. Proposals: (1) add a `_cache` dict so repeated calls serve from memory, (2) disable the watcher at runtime with `Engine.is_editor_hint()`, (3) add `engine.start_with_data()` for pre-loaded conversations, (4) extract the conversation string parser (`"Name:Entry:Line"`) from 7 independent sites into one shared function. See [core/conversation-loading.md](core/conversation-loading.md).
