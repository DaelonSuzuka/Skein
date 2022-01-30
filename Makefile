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

webdeploy:
	$(GODOT) --export "HTML5"
	cp build/web/* ~/www/html/diagraph*

win:
	$(GODOT) --export "Windows Desktop"

# **************************************************************************** #
# Variables

WSLENV ?= notwsl

GD = ""
ifndef WSLENV
	GD := godot.exe
else
	GD := ~/godot/Godot_v3.4.2-stable_linux_headless.64
endif

GDARGS := --no-window --quiet

GODOT = $(GD) $(GDARGS)

# **************************************************************************** #

include venv.mk