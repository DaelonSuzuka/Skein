# Diagraph


basic usage

Create a speech node:

```
Character: text text text
OtherCharacter: more text\
another line of text (in the same box)
ThirdCharacter: [color=red]colored text[/color]

Character: text with a pause _____ and then more |text|

Character: {do_something()} {{print_something}}
```

## Rules:

Empty lines are completely ignored.

Lines beginning with # are treated as comments and are completely ignored.

A line starting with a CharacterName and a ":" will cause the speaking character to be changed.

Ending with a backslash \ will continue printing the next line without clearing the text box.\

All [Godot BBCode](https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html) is available.

A _ pauses printing for 1/4 second.

Text surrounded by |pipes| is printed all at once, instead of one character at a time.

Diagraph supports arbitrary code execution using { } and {{ }}. It will attempt to parse and execute anything inside curly braces.

Anything inside double curly braces is parsed, executed, and the return value is printed to the dialog box.

Symbols available to executed code:

- `caller` - the object that triggered the dialog
- `scene` - the scene the `caller` is in
- all character names
- anything made available as a `local`


Adding locals:

```
Diagraph.sandbox.add_locals({
	'Game': Game,
	'Player': Player,
})
```