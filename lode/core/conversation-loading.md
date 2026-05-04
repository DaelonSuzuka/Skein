# Conversation Loading Design

## Current State ✅ Updated

The conversation loading path has been refactored. Key changes made:

### Shared parser: `Skein.parse_conversation_string()`

A single static function on `SkeinSingleton` that parses `"Name[:Entry[:Line]]"` into a Dictionary. All 7 call sites that previously did independent `split(":")` now use this:

| File | Old pattern | New pattern |
|------|-------------|-------------|
| `DialogEngine.gd` | `trim_prefix + split(":")` | `Skein.parse_conversation_string()` |
| `DialogBox.gd` (old) | `trim_prefix + split(":")` | `Skein.parse_conversation_string()` |
| `SkeinSingleton.gd` | `trim_prefix + split(":")` | `Skein.parse_conversation_string()` |
| `SkeinEditor.gd` (×3 sites) | `trim_prefix + split(":")` | `Skein.parse_conversation_string()` |
| `SkeinInspectorPlugin.gd` | `split(":")` | `Skein.parse_conversation_string()` |

### Runtime cache

`load_conversation()` now caches loaded node data in `_cache` keyed by resolved file path. Repeated calls return `.duplicate(true)` copies from cache — no disk hit. `refresh()` clears `_cache`.

### Editor-only watcher

`Watcher` is only added as a child and initialized when `Engine.is_editor_hint()`. At runtime, no file polling occurs.

### `start_with_data()`

`DialogEngine.start_with_data(data, options)` accepts a pre-built node dictionary, skipping `Skein.load_conversation()` entirely. Options support `entry`, `line`, and all the usual renderer options. Common entry-point logic extracted into `_find_and_enter_start_node()`.

### Remaining design notes

- The `_conversations` lookup table (4 keys per file: path, filename, basename, basefilename) is kept — the ergonomics are too good to lose
- `conversation_path` and `characters_path` are still hardcoded in `Files.gd` — intended to become project settings but not yet exposed
- No way to invalidate a single cache entry; `refresh()` clears the entire cache

## Related Lodes
- [core-architecture.md](core-architecture.md) — singleton, autoload, refresh lifecycle
- [runtime-engine.md](../dialog/runtime-engine.md) — engine start() and conversation loading
- [file-formats.md](../formats/file-formats.md) — path conventions