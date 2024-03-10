# **************************************************************************** #
# General Make configuration

# This suppresses make's command echoing. This suppression produces a cleaner output. 
# If you need to see the full commands being issued by make, comment this out.
MAKEFLAGS += -s

# **************************************************************************** #
# Targets

pull:
	git reset --hard
	git pull

web:
	$(GODOT) --export "HTML5"

webdeploy: web
	cp build/web/* /var/www/html/magnusdei.io/skein

win:
	$(GODOT) --export "Windows Desktop"

# **************************************************************************** #

BUTLER := butler

ifeq ($(OS),Windows_NT)
	BUTLER := $(BUTLER).exe
endif

itch:
	$(BUTLER) push build/web daelon/skein:html5

# **************************************************************************** #
# download godot binary and export templates for linux

GDVERSION := 3.5.1
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
# Variables

WSLENV ?= notwsl

GD = ""
ifndef WSLENV
	GD := Godot_v3.5.1-stable_win64.exe
else
	GD := ~/godot/$(GDBINARY)
endif

GDARGS := --no-window --quiet

GODOT = $(GD) $(GDARGS)

# **************************************************************************** #

include venv.mk
