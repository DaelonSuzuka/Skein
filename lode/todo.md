# Todo

Raw ideas captured as single-line entries. No multi-line descriptions, no details.

- GraphEdit node not yet analyzed in depth (graph editing, connections, drag-drop, new node types)
- `really_delete_conversation()` is a TODO stub in SkeinEditor.gd
- `dialog_box/DialogBox.gd` has an unimplemented `actor_left` signal
- `preprocess_random_lines` supports `%random` lines but is relatively brittle
- Keyboard shortcuts / hotkeys for editor operations are not documented
- `Branch` node UI is only `HBoxContainer` with `Condition` and `Label`; no deeper analysis
- `SkeinInspectorPlugin.gd` not yet examined
- `ContextMenu.gd` / `MenuButton.gd` utility classes not yet examined
- `Demo.gd` and `Example.gd` might contain usage patterns worth documenting
- Tests exist (`tests/files.test.gd`, `tests/yarn.test.gd`, `tests/dialog.test.gd`, `tests/sandbox.test.gd`) but are not documented
- Character management system is incomplete (registration exists, no management)
- DialogBox is intended as a customizable template but subclassing path is not documented
- Quest system design that coevolves with dialog runtime
- MethodPicker inspector component needs completion
- Write unit tests for DialogEngine (29 tests, all passing)
