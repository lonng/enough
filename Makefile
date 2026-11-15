.DEFAULT_GOAL := help

export ENOUGH_OUTPUT_DIR ?= $(CURDIR)/dist
ENOUGH_VERSION := $(shell cat VERSION)

.PHONY: help check test build run open fixtures release verify-release clean

help:
	@printf '%s\n' \
		'Usage: make <target>' \
		'' \
		'  check           Run permission matching and policy checks' \
		'  test            Alias for check' \
		'  build           Build the Intel + Apple Silicon app' \
		'  run             Build, restart Enough, and show its panel' \
		'  open            Restart the existing build and show its panel' \
		'  fixtures        Build disposable integration fixtures' \
		'  release         Sign, notarize, and package a release (credentials required)' \
		'  verify-release  Verify the signed app and DMG for VERSION' \
		'  clean           Remove the default .build and dist directories' \
		'' \
		'Output directory: ENOUGH_OUTPUT_DIR (default: dist/)'

check:
	@Scripts/check.sh

test: check

build:
	@Scripts/build.sh

# Launch in the recipe so make -j cannot open the old binary while building.
run: build
	@Scripts/run.sh

open:
	@Scripts/run.sh

fixtures:
	@Scripts/Fixtures/build.sh "$(ENOUGH_OUTPUT_DIR)/fixtures"

release:
	@Scripts/release.sh

verify-release:
	@Scripts/verify-release.sh "$(ENOUGH_OUTPUT_DIR)/Enough.app" "$(ENOUGH_OUTPUT_DIR)/Enough-$(ENOUGH_VERSION)-universal.dmg"

clean:
	rm -rf .build dist
