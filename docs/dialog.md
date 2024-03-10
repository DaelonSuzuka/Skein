# Skein

```
Character: text text text
OtherCharacter: more text\
another line of text (in the same box)
ThirdCharacter: [color=red]colored text[/color]

Character: text with a pause _____ and then more |text|

Character: {do_something()} {{print_something}}
```

## Basic Rules:

Empty lines are completely ignored.

Lines beginning with `#` or `//` are treated as comments and are completely ignored.

A line starting with a CharacterName and a `:` will cause the speaking character to be changed.

Ending with a backslash `\` will continue printing the next line without clearing the text box.

All [Godot BBCode](https://docs.godotengine.org/en/stable/tutorials/ui/bbcode_in_richtextlabel.html) is available.

A `_` pauses printing for 1/4 second.

Text surrounded by `|pipes|` is printed all at once, instead of one character at a time.

## Choices

In-line choices are lines that start with `-` or `->`. Selecting a choice causes dialog to continue down the indented block that follows. 

A choice ending with `=> $Target` will jump to that node when the choice is selected.
```
Alka: how much doge do you have?

- A lot
	Alka: Wait really?
	Alka: Buy me lunch, rich guy!
	- No way!
		Alka: Awww
	- Okay, let's go.
		Alka: Hell yeah!
- Not very much => UrPoor
```
If dialog reaches the end of a tree without hitting a jump command, then execution will go back up one level and indentation and continue.
```
Alka: Hi there! What do you feel like doing today?

-> I want to go swimming.
    Alka: Okay, let's go swimming.
	<<jump Swimming>>
-> I'd prefer to go hiking.
    Alka: Cool, we'll go hiking then.
    
Player: Sounds good!
```

## Randomization

`[[hello|ahoy|howdy]]` will randomly select `hello`, `ahoy`, or `howdy`

Contiguous lines starting with `%` will one of the lines randomly selected at runtime.
```
Random letter?
% A
% B
% C

Random number?
% 1
% 2
% 3
```

## Directives

`<<directive>>`

Available directives:

- `<<jump $target>>`: Jumps the dialog engine to the specified target
- `<<show>>`: show the dialog box
- `<<hide>>`: hide the dialog box
- `<<speed $speed>>`: Change the test display speed
- `<<exec $bool>>`: Whether to execute inline code blocks
- `<<assignment $bool>>`: Whether assignment statements are allowed in code execution
- `<<show_name $bool>>`: Whether to show the current speakers name
- `<<set_name $name>>`: Override the displayed character name
- `<<show_portrait $bool>>`: Whether to show the current speakers portrait


## Code execution
Skein supports arbitrary code execution using { } and {{ }}. It will attempt to parse and execute anything inside curly braces.

Anything inside double curly braces is parsed, executed, and the return value is printed to the dialog box.

Symbols available to executed code:

- `caller` - the object that triggered the dialog
- `scene` - the scene the `caller` is in
- all character names
- anything made available as a `local`


Adding locals:

```gdscript
Skein.sandbox.add_locals({
	'Game': Game,
	'Player': Player,
})
```