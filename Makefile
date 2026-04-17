#!/usr/bin/make -f

.DEFAULT_GOAL := help

ENV ?= local
APP_NAME := Ligents
RUN_SCRIPT := ./script/build_and_run.sh
SWIFT ?= swift

COLOUR_GREEN := \033[1;32m
COLOUR_BLUE := \033[1;34m
END_COLOUR := \033[0m

ifeq ($(ENV),prod)
SWIFT_BUILD_FLAGS := -c release
else
SWIFT_BUILD_FLAGS :=
endif

.PHONY: help all all-d all-v build run debug logs telemetry verify clean clean-cache nya

help: # show info by command
	@printf "workspace $(COLOUR_BLUE)$(APP_NAME)$(END_COLOUR) Makefile\n"
	@echo "Usage:\n  make $(COLOUR_GREEN)<command>$(END_COLOUR)\n"
	@echo "Environment:\n  ENV=local|prod (default: local)\n"
	@echo "Commands:"
	@grep -E '^[a-z0-9][a-z0-9-]*:.*#' $(firstword $(MAKEFILE_LIST)) | while read -r l; do printf "  \033[1;34m$$(echo $$l | cut -f 1 -d':')\033[00m:$$(echo $$l | cut -f 2- -d'#')\n"; done

all: run # build and launch the app bundle

all-d: clean # remove project build outputs

all-v: clean-cache # remove project outputs and SwiftPM cache

build: # build the Swift package
	@$(SWIFT) build $(SWIFT_BUILD_FLAGS)

run: # build the app bundle and launch it
	@$(RUN_SCRIPT) run

debug: # build the app bundle and start lldb
	@$(RUN_SCRIPT) debug

logs: # launch the app and stream process logs
	@$(RUN_SCRIPT) logs

telemetry: # launch the app and stream subsystem telemetry
	@$(RUN_SCRIPT) telemetry

verify: # build, launch, and verify the app process starts
	@$(RUN_SCRIPT) verify

clean: # remove generated project build outputs
	@rm -rf .build dist

clean-cache: clean # remove generated outputs and SwiftPM cache
	@rm -rf ~/Library/Caches/org.swift.swiftpm

nya: # print nya
	@printf '%s\n' \
'⠄⠄⠄⣶⠄⠰⠟⢃⠄⢐⠄⠄⠄⠄⠄⡎⠄⠄⠄⡄⡾⠄⢰⣿⣇⠄⠄⡆⠄⠄⠄⠄' \
'⠄⠄⢰⣿⠄⣼⣿⣿⣄⢠⢳⠄⠄⠄⠰⠄⠄⢀⣼⢿⣿⠄⣼⣿⣷⠄⣸⣿⠄⠄⠄⠄' \
'⠄⠄⣼⠛⠄⠉⠉⠹⠟⠎⣷⡦⡀⠄⠄⠄⡰⡺⣯⣾⡫⠮⠭⠽⠿⠄⠿⠿⣰⠄⠄⠄' \
'⠄⠄⠁⢠⣤⣄⢦⡐⠂⣌⢙⣿⡵⢀⡀⠘⢕⣿⣿⢋⣤⢠⡄⠄⠄⠠⣀⠄⠙⠄⠄⠄' \
'⠄⠄⢳⣴⣿⣿⣻⣿⣿⣿⣿⣽⣾⣵⣿⣷⣜⣿⣿⣿⣿⣛⣿⣿⡿⢷⢿⣡⠆⠄⠄⠄' \
'⠄⠄⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢿⡋⠄⠄⠂⠄' \
'⠄⠄⠈⢦⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠝⢀⠄⠄⠄⠄' \
'⠄⠄⠄⠁⣿⣿⣿⣿⣿⣿⣿⣏⣛⣛⣛⣛⣛⣹⣿⣿⣿⣿⣿⣿⣯⣽⠾⠁⠄⠄⠄⠄' \
'⠄⠄⠄⠄⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⡕⠄⠄⠄⠄⠄⠄' \
'⠄⠄⠄⠄⠄⠄⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⡟⠃⠄⠄⠄⠄⠄⠄⠄⠄'
