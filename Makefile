# **************************************************************************** #
# General Make configuration

# This suppresses make's command echoing. This suppression produces a cleaner output. 
# If you need to see the full commands being issued by make, comment this out.
MAKEFLAGS += -s

# **************************************************************************** #
# Cross-platform targets
# These targets work on any OS with Godot installed and accessible as `godot`
# (or via the GODOT variable below).

GD ?= godot
GDARGS := --no-window --quiet
GODOT = $(GD) $(GDARGS)

pull:
	git reset --hard
	git pull

win:
	$(GODOT) --export "Windows Desktop"

# **************************************************************************** #
# Linux server deploy targets
# These targets are designed to run on a Linux server only. They use
# Unix-specific commands (wget, cp, mkdir -p) and assume a specific
# filesystem layout (/var/www/html). Do not run these on Windows.

web:
	$(GODOT) --export "HTML5"

webdeploy: web
	cp build/web/* /var/www/html/magnusdei.io/diagraph

# **************************************************************************** #
# itch.io deploy (requires butler CLI)
# https://itch.io/docs/butler/

BUTLER = butler

ifeq ($(OS),Windows_NT)
	BUTLER = $(BUTLER).exe
endif

itch:
	$(BUTLER) push build/web daelon/diagraph:html5

# **************************************************************************** #
# Godot download — Linux server only
# Downloads a Godot headless binary and export templates to ~/godot/
# for CI/export use. Requires wget and unzip.

GDVERSION := 3.5
GDBUILD := stable

URL := https://downloads.tuxfamily.org/godotengine/$(GDVERSION)/

ifneq ($(GDBUILD),stable)
	URL := $(URL)$(GDBUILD)/
endif

GDBINARY := Godot_v$(GDVERSION)-$(GDBUILD)_linux_headless.64
TEMPLATES := Godot_v$(GDVERSION)-$(GDBUILD)_export_templates.tpz

download:
	wget $(URL)$(GDBINARY).zip
	unzip $(GDBINARY).zip
	mkdir -p ~/godot
	mv $(GDBINARY) ~/godot
	rm $(GDBINARY).zip

	wget $(URL)$(TEMPLATES)
	unzip $(TEMPLATES)
	mkdir -p ~/.local/share/godot/templates
	mv templates/ ~/.local/share/godot/templates/$(GDVERSION).$(GDBUILD)/

	rm $(TEMPLATES)

# **************************************************************************** #

include venv.mk