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
	git submodule update

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
# This makefile is for managing python virtual environments
# Simply add "include venv.mk" to the bottom of your regular Makefile

# Add this as a requirement to any make target that relies on the venv
.PHONY: venv
venv: $(VENV_DIR)

# **************************************************************************** #

# forward pip commands to the venv
pip: venv
	$(VENV_PYTHON) -m pip $(RUN_ARGS)

# update requirements.txt to match the state of the venv
freeze_reqs: venv
	$(VENV_PYTHON) -m pip freeze > requirements.txt

# try to update the venv - expirimental feature, don't rely on it
update_venv: venv
	$(VENV_PYTHON) -m pip install --upgrade -r requirements.txt

# deletes the venv
clean_venv:
	$(RM) $(VENV_DIR)

# deletes the venv and rebuilds it
reset_venv: clean_venv venv

# **************************************************************************** #
# python venv settings
VENV_NAME := .venv

ifeq ($(OS),Windows_NT)
	VENV_DIR := $(VENV_NAME)
	VENV := $(VENV_DIR)\Scripts
	PYTHON := python
	VENV_PYTHON := $(VENV)\$(PYTHON)
	VENV_PYINSTALLER := $(VENV)\pyinstaller
	RM := rd /s /q 
else
	VENV_DIR := $(VENV_NAME)
	VENV := $(VENV_DIR)/bin
	PYTHON := python3
	VENV_PYTHON := $(VENV)/$(PYTHON)
	VENV_PYINSTALLER := $(VENV)/pyinstaller
	RM := rm -rf 
endif

# Create the venv if it doesn't exist
$(VENV_DIR):
	$(PYTHON) -m venv $(VENV_DIR)
	$(VENV_PYTHON) -m pip install --upgrade pip
	$(VENV_PYTHON) -m pip install -r requirements.txt

# If the first argument is "pip"...
ifeq (pip,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "pip"
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(RUN_ARGS):;@:)
endif
