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
	cp build/web/* /var/www/html/magnusdei.io/diagraph

win:
	$(GODOT) --export "Windows Desktop"

itch:
	butler.exe push build/web daelon/diagraph:html5

# **************************************************************************** #
# download godot binary and export templates for linux

GDVERSION = 3.5
GDBUILD = rc6

URL = https://downloads.tuxfamily.org/godotengine/$(GDVERSION)/$(GDBUILD)/
GDBINARY = Godot_v$(GDVERSION)-$(GDBUILD)_linux_headless.64
TEMPLATES = Godot_v$(GDVERSION)-$(GDBUILD)_export_templates.tpz

download:
	wget $(URL)$(GDBINARY).zip
	unzip $(GDBINARY).zip
	mv $(GDBINARY) ~/godot
	rm $(GDBINARY).zip

	wget $(URL)$(TEMPLATES)
	unzip $(TEMPLATES)
	mv templates/ ~/.local/share/godot/templates/$(GDVERSION).$(GDBUILD)/

	rm $(TEMPLATES)

# **************************************************************************** #
# Variables

WSLENV ?= notwsl

GD = ""
ifndef WSLENV
	GD := godot.exe
else
	GD := ~/godot/$(GDBINARY)
endif

GDARGS := --no-window --quiet

GODOT = $(GD) $(GDARGS)

# **************************************************************************** #

include venv.mk
